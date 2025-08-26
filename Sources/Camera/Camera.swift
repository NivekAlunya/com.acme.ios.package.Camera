//
//  File.swift
//  Camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//
//
// Camera actor implementation using AVFoundation and async/await for video preview and photo capture.

import Foundation
@preconcurrency import AVFoundation
import UIKit

enum CameraError: Error {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case creationFailed
}

public actor Camera: NSObject, CameraProtocol {
    func createStreams() {
        stream = CameraStream()
    }
        
    var config: CameraConfiguration
    var stream: any CameraStreamProtocol = CameraStream()
    private(set)  var photo: AVCapturePhoto?
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "CameraSessionQueue")
    private var isSetupNeeded: Bool = true

    public override init() {
        
        self.config = CameraConfiguration()
        super.init()
        Task { @MainActor in
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
    }
                
    func changePreset(preset: CaptureSessionPreset = .photo) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        config.preset = preset
        session.sessionPreset = config.preset.avPreset
    }
 
    private func removeDevice() {
        if session.isRunning {
            session.stopRunning()
        }
        if let deviceInput = config.deviceInput {
            session.removeInput(deviceInput)
        }
    }
    
    func changeCamera(device: AVCaptureDevice) async throws {
        try await changeDevice(device: device)
    }
    
    private func changeDevice(device: AVCaptureDevice) async throws {
        try await stop()
        removeDevice()
        try setup(device: device)
        try await start()
    }
    
    func swicthPosition() async throws {
        config.switchPosition()
        guard let device = config.getDefaultCamera() else {
            throw CameraError.cameraUnavailable
        }
        try await changeDevice(device: device)
    }
    
    func getDefaultCamera() -> AVCaptureDevice? {
        config.listCaptureDevice.first ?? AVCaptureDevice.default(for: .video)
    }
    
    func start() async throws {
        queue.suspend()
        let authorized = await CameraHelper.checkAuthorization()
        guard authorized else {
            print("Camera access was not authorized.")
            return
        }
        queue.resume()
        await stream.resume()
        
        if isSetupNeeded {
            guard let device = config.getDefaultCamera() else {
                throw CameraError.cameraUnavailable
            }
            try setup(device: device)
        }
        
        guard !self.session.isRunning
        else {
            return
        }
        
        queue.async {
            self.session.startRunning()
        }
    }
    
    private func setup(device: AVCaptureDevice) throws {
        
        if self.session.isRunning {
            self.session.stopRunning()
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = config.preset.avPreset
        try config.setupCaptureDevice(device: device, forSession: session)
        try config.setupCaptureDeviceOutput(forSession: session, delegate: self)

        isSetupNeeded = false
    }

    func resume() async {
        await stream.resume()
        queue.async {
            self.session.startRunning()
        }
    }
    
    /// Stops the capture session safely and pauses preview emission.
    func stop() async {
        
        if session.isRunning {
            await stream.pause()
            queue.async {
                self.session.stopRunning()
            }
        }
    }
    
    func end() async {
        await stream.finish()
    }
    
    deinit {
        Task { @MainActor in
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }
    
    func takePhoto() async {
        let videoOrientation = await getAVCaptureVideoOrientation()
        if let photoOutputVideoConnection = self.config.photoOutput.connection(with: .video) {
            // Set video orientation for the photo output connection if supported.
            if photoOutputVideoConnection.isVideoRotationAngleSupported(90.0)
                , let videoOrientation = videoOrientation {
                photoOutputVideoConnection.videoOrientation = videoOrientation
            }
        }
        await stream.pause()
        let photoSettings = await config.buildPhotoSettings()
        photoSettings.flashMode = config.flashMode.avFlashMode
        self.config.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
         
    func switchFlash(_ value: CameraFlashMode) {
        config.flashMode = value
    }
    
    func changeCodec(_ codec: VideoCodecType) {
        config.videoCodecType = codec
    }

    func getAVCaptureVideoOrientation() async -> AVCaptureVideoOrientation?  {
        await Task { @MainActor in
            CameraHelper.videoOrientationFor(UIDevice.current.orientation)
        }.value
    }
    
    func processPhoto(_ photo: AVCapturePhoto) async {
        guard let cgImage = photo.cgImageRepresentation() else {
            return
        }
        self.photo = photo

        await self.stream.emitPhoto(CIImage(cgImage: cgImage))
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    
    nonisolated public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        Task {
            await processPhoto(photo)
        }
    }
}
extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        Task {
            guard let rotationCoordinator = await config.rotationCoordinator else {
                return
            }
            connection.videoRotationAngle = await rotationCoordinator.videoRotationAngleForHorizonLevelCapture
            
            await self.stream.emitPreview(image)
        }
    }
}
