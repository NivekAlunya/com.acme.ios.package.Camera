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

actor Camera: NSObject, CameraProtocol {

    var config = CameraConfiguration()
    var stream: any CameraStreamProtocol = CameraStream()
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "CameraSessionQueue")
    private var isCaptureSessionConfigured = false
    private var isCaptureSessionOutputConfigured = false
    private var isSetupNeeded: Bool = true

    override init() {
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
        guard !isCaptureSessionOutputConfigured else {
            return
        }
        
        // Add photo output if supported
        guard session.canAddOutput(config.photoOutput) else {
            throw CameraError.cannotAddOutput
        }
        
        session.addOutput(config.photoOutput)
        
        // Add video data output for preview frames
        guard session.canAddOutput(videoOutput) else {
            throw CameraError.cannotAddOutput
        }
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_preview_video_output"))
        session.addOutput(videoOutput)
        isCaptureSessionOutputConfigured = true
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
            
            guard session.canAddInput(input) else {
                throw CameraError.cannotAddInput
            }
            session.addInput(input)
            
            self.config.deviceInput = input
            print("\(input.device.localizedName)")
        } catch {
            throw CameraError.creationFailed
        }
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
            try setup()
        }
        
        guard !self.session.isRunning
        else {
            return
        }
        
        queue.async {
            self.session.startRunning()
        }
    }
    
    private func setup(device: AVCaptureDevice? = nil) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = config.preset.avPreset
        try setupCaptureDevice(device: device)
        try setupCaptureDeviceOutput()
        isSetupNeeded = false
    }

    func resume() async {
        guard isCaptureSessionConfigured else { return }
        await stream.resume()
        queue.async {
            self.session.startRunning()
        }
    }
    
    /// Stops the capture session safely and pauses preview emission.
    func stop() async {
        guard isCaptureSessionConfigured else { return }
        
        if session.isRunning {
            await stream.pause()
            queue.async {
                self.session.stopRunning()
            }
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
}

extension Camera: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("Error capturing photo: \(error.localizedDescription)")
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
            guard let rotationCoordinator = await config.rotationCoordinator else {
                return
            }
            connection.videoRotationAngle = await rotationCoordinator.videoRotationAngleForHorizonLevelCapture
            
            await self.stream.emitPreview(image)
        }
    }
}
