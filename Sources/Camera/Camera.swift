//
//  File.swift
//  Camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//
//
// Camera actor implementation using AVFoundation and async/await for video preview and photo capture.

import Foundation
import AVFoundation
import CoreImage

enum CameraError: Error {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case creationFailed
}

actor Camera: NSObject, CameraProtocol {

    var config = CameraConfiguration()
    var stream: any CameraStreamProtocol = CameraStream()
    private let queue = DispatchQueue(label: "CameraSessionQueue")

    override init() {
        super.init()
    }
                
    func changePreset(preset: CaptureSessionPreset = .photo) {
        config.session.beginConfiguration()
        defer { config.session.commitConfiguration() }
        config.preset = preset
        config.session.sessionPreset = config.preset.avPreset
    }
 
    private func removeDevice() {
        if config.session.isRunning {
            config.session.stopRunning()
        }
        if let deviceInput = config.deviceInput {
            config.session.removeInput(deviceInput)
        }
    }
    
    func changeCamera(device: AVCaptureDevice?) async throws {
        try await stop()
        removeDevice()
        try setup(device: device)
        try await start()
    }
    
    func swicthPosition() async throws {
        config.switchPosition()
        try await changeCamera(device: nil)
    }
    
    
    private func setupCaptureDeviceOutput() throws {
        guard !config.isCaptureSessionOutputConfigured else {
            return
        }
        
        // Add photo output if supported
        guard config.session.canAddOutput(config.photoOutput) else {
            throw CameraError.cannotAddOutput
        }
        
        config.session.addOutput(config.photoOutput)
        
        // Add video data output for preview frames
        guard config.session.canAddOutput(config.videoOutput) else {
            throw CameraError.cannotAddOutput
        }
        config.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_preview_video_output"))
        config.session.addOutput(config.videoOutput)
        config.isCaptureSessionOutputConfigured = true
    }
    
    func getDefaultCamera() -> AVCaptureDevice? {
        config.listCaptureDevice.first ?? AVCaptureDevice.default(for: .video)
    }
    
    private func setupCaptureDevice(device: AVCaptureDevice?) throws {

        guard let camera = device ?? config.getDefaultCamera() else {
            throw CameraError.cameraUnavailable
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            guard config.session.canAddInput(input) else {
                throw CameraError.cannotAddInput
            }
            config.session.addInput(input)
            
            self.config.deviceInput = input
            print("\(input.device.localizedName)")
        } catch {
            throw CameraError.creationFailed
        }
    }
    
    func start() async throws {
        let authorized = await CameraHelper.checkAuthorization()
        guard authorized else {
            print("Camera access was not authorized.")
            return
        }

        await stream.resume()
        
        if config.isSetupNeeded {
            try setup()
        }
        
        guard !self.config.session.isRunning
        else {
            return
        }
        
        self.config.session.startRunning()
    }
    
    private func setup(device: AVCaptureDevice? = nil) throws {
        config.session.beginConfiguration()
        defer { config.session.commitConfiguration() }
        config.session.sessionPreset = config.preset.avPreset
        try setupCaptureDevice(device: device)
        try setupCaptureDeviceOutput()
        config.isSetupNeeded = false
    }

    func resume() async {
        guard config.isCaptureSessionConfigured else { return }
        await stream.resume()
        if !config.session.isRunning {
            config.session.startRunning()
        }
    }
    
    /// Stops the capture session safely and pauses preview emission.
    func stop() async {
        guard config.isCaptureSessionConfigured else { return }
        
        if config.session.isRunning {
            await stream.pause()
            self.config.session.stopRunning()
        }
    }
    
    func exit() {
        Task {
            await stream.finish()
        }
    }
    
    deinit {
        Task { [stream] in
            await stream.finish()
        }
    }
    
    func takePhoto() async {
        let photoSettings = config.buildPhotoSettings()
        photoSettings.flashMode = config.flashMode.avFlashMode
        self.config.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
         
    func switchFlash(_ value: CameraFlashMode) {
        config.flashMode = value
    }
    
    func changeCodec(_ codec: VideoCodecType) {
        config.videoCodecType = codec
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("Error capturing photo: \(error.localizedDescription)")
            // Consider propagating the error to a delegate or using a different mechanism
            return
        }
        Task {
            await self.stream.emitPhoto(photo)
        }
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        Task {
            if let rotationCoordinator = await config.rotationCoordinator {
                connection.videoRotationAngle = await rotationCoordinator.videoRotationAngleForHorizonLevelCapture
            }
            
            await self.stream.emitPreview(image)
        }
    }
}
