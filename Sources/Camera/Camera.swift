//
//  File.swift
//  camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//  

import Foundation
@preconcurrency import AVFoundation
import UIKit

protocol ICamera: Actor {
    var previewStream: AsyncStream<CIImage> { get }
    var photoStream: AsyncStream<AVCapturePhoto>  { get }
    func configure(preset: AVCaptureSession.Preset)
    func start() async
    func stop() async
    func takePhoto() async
}

actor Camera: NSObject, ICamera {
    
    private let session = AVCaptureSession()
    
    private var deviceInput: AVCaptureDeviceInput!
    
    private let photoOutput = AVCapturePhotoOutput()
    
    private let videoOutput = AVCaptureVideoDataOutput()
    
    private let queue = DispatchQueue(label: "CameraSessionQueue")
    
    private var isPreviewPaused = false
    
    private var isPreviewStopped = false
    
    private var isCaptureSessionConfigured = false

    private var previewContinuation: AsyncStream<CIImage>.Continuation?
    
    private(set) lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            self.previewContinuation = continuation
        }
    }()
    
    private var photoContinuation: AsyncStream<AVCapturePhoto>.Continuation?
    
    private(set) lazy var photoStream: AsyncStream<AVCapturePhoto> = {
        AsyncStream { continuation in
            self.photoContinuation = continuation
        }
    }()

    private func emitPreview(_ ciImage: CIImage) {
        if !isPreviewPaused {
            previewContinuation?.yield(ciImage)
        } else if isPreviewStopped {
            previewContinuation?.finish()
        }
    }
    
    private func emitPhoto(_ photo: AVCapturePhoto) {
        if !isPreviewPaused {
            photoContinuation?.yield(photo)
        } else if isPreviewStopped {
            photoContinuation?.finish()
        }
    }
    
    override init() {
        super.init()
        Task { [weak self] in
            await self?.setupDeviceOrientationChanges()
        }
    }
    
    private func setupDeviceOrientationChanges() {
        Task { @MainActor in
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
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
    
    
    //MARK: - ICamera Implementation
    
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
    
    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            print("Camera access was not authorized.")
            return
        }
        guard isCaptureSessionConfigured else { return }
        
        Task.detached {
            self.session.startRunning()
        }
        
    }
    
    func stop() async {
        guard isCaptureSessionConfigured else { return }
        
        if session.isRunning {
            isPreviewPaused = true
            queue.async {
                self.session.stopRunning()
            }
        }
    }
    
    func takePhoto() async {
        let videoOrientation = await getAVCaptureVideoOrientation()
        Task.detached {
            var photoSettings = AVCapturePhotoSettings()

            if self.photoOutput.availablePhotoCodecTypes.contains(AVVideoCodecType.jpeg) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }

//            let isFlashAvailable = self.deviceInput?.device.isFlashAvailable ?? false
//            photoSettings.flashMode = isFlashAvailable ? .auto : .off
            photoSettings.photoQualityPrioritization = .balanced
            
            if let photoOutputVideoConnection = self.photoOutput.connection(with: .video) {
                if photoOutputVideoConnection.isVideoOrientationSupported, let videoOrientation = videoOrientation {
                    print("videoOrientation \(videoOrientation)")
                    photoOutputVideoConnection.videoOrientation = videoOrientation
                }
            }
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    func getAVCaptureVideoOrientation() async -> AVCaptureVideoOrientation?  {
        await Task { @MainActor in
            switch UIDevice.current.orientation {
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
        }.value
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

extension Camera: @preconcurrency AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }
        Task {
            await self.stop()
            await self.emitPhoto(photo)
        }
        
    }
}


extension Camera: @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let buffer = sampleBuffer
        let conn = connection
        Task { [weak self] in
            guard let self else { return }
            await self.process(buffer: buffer, connection: conn)
        }
    }
    
    private func process( buffer: CMSampleBuffer, connection: AVCaptureConnection) async {
        guard let pixelBuffer = buffer.imageBuffer else { return }

        if connection.isVideoOrientationSupported
            , let videoOrientation = await getAVCaptureVideoOrientation() {
            connection.videoOrientation = videoOrientation
        }
        
        await emitPreview(CIImage(cvPixelBuffer: pixelBuffer))
    }
    
}

