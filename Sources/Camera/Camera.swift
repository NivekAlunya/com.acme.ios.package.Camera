//
//  File.swift
//  camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//

import Foundation
@preconcurrency import AVFoundation
import UIKit

protocol ICamera: Sendable {
    var previewStream: AsyncStream<CIImage> { get }
    var photoStream: AsyncStream<AVCapturePhoto>  { get }
    func configure(preset: AVCaptureSession.Preset)
    func start() async
    func stop() async
    func takePhoto()
}

class Camera: NSObject, ICamera, @unchecked Sendable {
    private let session = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput!
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var orientation: UIDeviceOrientation! = .unknown
    private let queue = DispatchQueue(label: "CameraSessionQueue")
    
    private var isPreviewPaused = false
    private var isPreviewStopped = false
    private var isCaptureSessionConfigured = false
    private var device: UIDevice!
    
    private var appendPreviewStream: ((CIImage) -> Void)?
    private(set) lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            appendPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                } else if self.isPreviewStopped {
                    continuation.finish()
                }
            }
        }
    }()
    
    private var appendPhotoStream: ((AVCapturePhoto) -> Void)?
    private(set) lazy var photoStream: AsyncStream<AVCapturePhoto> = {
        AsyncStream { continuation in
            appendPhotoStream = { capture in
                if !self.isPreviewPaused {
                    continuation.yield(capture)
                } else if self.isPreviewStopped {
                    continuation.finish()
                }
            }
        }
    }()
    
    
    override init() {
        super.init()
        
        Task { @MainActor in
            device = UIDevice.current
            device.beginGeneratingDeviceOrientationNotifications()
            NotificationCenter.default.addObserver(self, selector: #selector(updateForDeviceOrientation), name: UIDevice.orientationDidChangeNotification, object: device)
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: device)
    }
    
    
    @objc
    func updateForDeviceOrientation() {
        //TODO: Figure out if we need this for anything.
    }
    
    func configure(preset: AVCaptureSession.Preset = .photo) {
        
        self.session.beginConfiguration()
        self.session.sessionPreset = preset
        
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              self.session.canAddInput(input) else {
            print("Failed to set up camera input")
            self.session.commitConfiguration()
            return
        }
        deviceInput = input
        self.session.addInput(deviceInput)
        if self.session.canAddOutput(self.photoOutput) {
            self.session.addOutput(self.photoOutput)
        } else {
            print("Failed to add photo output")
        }
        
        if self.session.canAddOutput(self.videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_preview_video_output"))
            self.session.addOutput(self.videoOutput)
        }
        
        self.session.commitConfiguration()
        
        isCaptureSessionConfigured = true
        
    }
    
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera access authorized.")
            return true
        case .notDetermined:
            print("Camera access not determined.")
            queue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            queue.resume()
            return status
        case .denied:
            print("Camera access denied.")
            return false
        case .restricted:
            print("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
    
    
    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            print("Camera access was not authorized.")
            return
        }
        guard isCaptureSessionConfigured else { return }
        
        queue.async { [session] in
            session.startRunning()
        }
    }
    
    func stop() {
        guard isCaptureSessionConfigured else { return }
        
        if session.isRunning {
            isPreviewPaused = true
            queue.async {
                self.session.stopRunning()
            }
        }
    }
    
    func takePhoto() {
        queue.async {
            var photoSettings = AVCapturePhotoSettings()
            
            if self.photoOutput.availablePhotoCodecTypes.contains(AVVideoCodecType.jpeg) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }
            
            let isFlashAvailable = self.deviceInput?.device.isFlashAvailable ?? false
            photoSettings.flashMode = isFlashAvailable ? .auto : .off
            photoSettings.photoQualityPrioritization = .balanced
            if let photoOutputVideoConnection = self.photoOutput.connection(with: .video) {
                if photoOutputVideoConnection.isVideoOrientationSupported,
                   let videoOrientation = self.videoOrientationFor(self.orientation) {
                    print("\(videoOrientation) :: \(self.orientation.rawValue)")
                    photoOutputVideoConnection.videoOrientation = videoOrientation
                }
            }
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
        
    // Optionally expose the session for preview layer usage
    func getSession() -> AVCaptureSession {
        return session
    }

    private func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait:
            print("portrait")
            return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            print("portraitUpsideDown")
            return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            print("landscapeLeft")
            return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            print("landscapeRight")
            return AVCaptureVideoOrientation.landscapeLeft
        default:
            print("landscapeRight")
            return nil
        }
    }

}

// MARK: - AVCapturePhotoCaptureDelegate
extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }
        self.stop()

        appendPhotoStream?(photo)
        
    }
}


extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task {
            await process(buffer: sampleBuffer, connection: connection)
        }
    }
    
    @MainActor
    private func process( buffer: CMSampleBuffer, connection: AVCaptureConnection) {
        guard let pixelBuffer = buffer.imageBuffer, let device = device else { return }
        orientation = device.orientation
        if connection.isVideoOrientationSupported,
           let videoOrientation = videoOrientationFor(orientation) {
            connection.videoOrientation = videoOrientation
        }
        
        appendPreviewStream?(CIImage(cvPixelBuffer: pixelBuffer))
    }
    
}
