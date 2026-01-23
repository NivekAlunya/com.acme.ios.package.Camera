//
//  Camera.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

@preconcurrency import AVFoundation
import Foundation
import UIKit

/// Represents the possible states of the `Camera` actor.
private enum CameraState {
    /// The camera has not been set up yet.
    case needSetup
    /// The user has not granted camera permissions.
    case unauthorized
    /// The camera is running and capturing video.
    case started
    /// The camera session is paused.
    case paused
    /// The camera session has been terminated.
    case ended
}

/// The `Camera` actor manages all capture-related operations using AVFoundation.
/// It handles the capture session, device configuration, and data output for video and photos.
/// This actor is a singleton to ensure that only one instance manages the camera hardware at a time.
public actor Camera: NSObject {
    
    private let context = CIContext(options: nil)
    
    /// The shared singleton instance of the `Camera`.
    public static let shared = Camera()

    /// The current camera configuration.
    public var config: CameraConfiguration

    /// The stream that broadcasts camera previews and captured photos.
    public var stream: any CameraStreamProtocol = CameraStream()

    /// The most recently captured photo.
    private(set) public var photo: PhotoCapture?

    /// The underlying `AVCaptureSession` that manages the capture pipeline.
    private let session = AVCaptureSession()

    /// The video data output for capturing preview frames.
    private let videoOutput = AVCaptureVideoDataOutput()

    /// The current state of the camera.
    private var state = CameraState.needSetup

    public override init() {
        self.config = CameraConfiguration()
        super.init()
    }

    /// Removes the current capture device input from the session.
    private func removeDevice() {
        if session.isRunning {
            session.stopRunning()
        }
        if let deviceInput = config.deviceInput {
            session.removeInput(deviceInput)
        }
    }

    /// Changes the active camera device.
    /// - Parameter device: The `AVCaptureDevice` to switch to.
    private func changeDevice(device: AVCaptureDevice) async throws {
        try await pause()
        removeDevice()
        try setup(device: device)
        try await start()
    }

    /// Retrieves the default camera device based on the current configuration.
    /// - Returns: An `AVCaptureDevice` instance, or `nil` if no suitable device is found.
    private func getDefaultCamera() -> AVCaptureDevice? {
        config.listCaptureDevice.first ?? AVCaptureDevice.default(for: .video)
    }

    /// Sets up the capture session with a specific device.
    /// - Parameter device: The `AVCaptureDevice` to be used for the session.
    private func setup(device: AVCaptureDevice) throws {
        if self.session.isRunning {
            self.session.stopRunning()
        }
        try config.setup(device: device, session: session, delegate: self)
    }

    /// Processes a captured photo, converts it to a `CIImage`, and emits it through the stream.
    /// - Parameter photo: The `AVCapturePhoto` to process.
    func processPhoto(_ photo: AVCapturePhoto) async {
        
        guard let ciImage = photo.buildImageForRatio(config.ratio) else {
            return
        }
        
        let data = context.jpegRepresentation(of: ciImage, colorSpace: ciImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!, options: [:])
        
        self.photo = PhotoCapture(data: data, metadata: photo.metadata)
        
        await self.stream.emitPhoto(ciImage)
    }
}

// MARK: - CameraProtocol Conformance
extension Camera: CameraProtocol {
    
    public func changeRatio(_ ratio: CaptureSessionAspectRatio) {
        self.config.ratio = ratio
    }

    /// Changes the zoom factor of the camera.
    /// - Parameter factor: The desired zoom factor.
    public func changeZoom(_ factor: CGFloat) throws {
        guard let device = config.deviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(
                1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
            config.zoom = Float(device.videoZoomFactor)
        } catch {
            throw CameraError.zoomUpdateFailed
        }
    }

    /// Starts the camera session.
    /// This method checks for authorization, sets up the camera if needed, and starts the session.
    public func start() async throws {
        guard !self.session.isRunning else {
            throw CameraError.cannotStartCamera
        }
        
        let authorized = await CameraHelper.checkAuthorization()
        guard authorized else {
            state = .unauthorized
            throw CameraError.cameraUnauthorized
        }
        
        switch state {
        case .needSetup:
            guard let device = config.getDefaultCamera() else {
                throw CameraError.cameraUnavailable
            }
            try setup(device: device)
            await createStreams()
        case .ended:
            await createStreams()
        default:
            break
        }

        await stream.resume()
        state = .started
        self.session.startRunning()
    }

    /// Resumes a paused camera session.
    public func resume() async {
        await stream.resume()
        state = .started
        self.session.startRunning()
    }

    /// Pauses the camera session and stops the preview stream.
    public func pause() async {
        if session.isRunning {
            await stream.pause()
            state = .paused
            self.session.stopRunning()
        }
    }

    /// Ends the camera session and cleans up resources.
    public func end() async {
        await pause()
        await stream.finish()
        state = .ended
    }
    
    /// Captures a photo.
    /// This method configures photo settings, including orientation and flash, and initiates the capture.
    public func takePhoto() async {
        if let photoOutputVideoConnection = self.config.photoOutput.connection(with: .video),
           let videoOrientation = CameraHelper.videoOrientationFor(deviceOrientation: config.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90.0) {
            photoOutputVideoConnection.videoOrientation = videoOrientation
        }
        await stream.pause()
        let photoSettings = await config.buildPhotoSettings()
        photoSettings.flashMode = config.flashMode.avFlashMode
        self.config.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    /// Changes the session preset for the camera.
    /// - Parameter preset: The `CaptureSessionPreset` to apply.
    public func changePreset(preset: CaptureSessionPreset = .photo) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        config.preset = preset
        session.sessionPreset = config.preset.avPreset
    }

    /// Changes the active camera device.
    /// - Parameter device: The `AVCaptureDevice` to switch to.
    public func changeCamera(device: AVCaptureDevice) async throws {
        try await changeDevice(device: device)
    }

    /// Switches between front and back cameras.
    public func changePosition() async throws {
        config.switchPosition()
        guard let device = config.getDefaultCamera() else {
            throw CameraError.cameraUnavailable
        }
        try await changeDevice(device: device)
    }

    /// Changes the video codec for photo capture.
    /// - Parameter codec: The `VideoCodecType` to use.
    public func changeCodec(_ codec: VideoCodecType) {
        config.videoCodecType = codec
    }

    /// Changes the flash mode for photo capture.
    /// - Parameter flashMode: The `CameraFlashMode` to use.
    public func changeFlashMode(_ flashMode: CameraFlashMode) {
        config.flashMode = flashMode
    }

    /// Creates a new `CameraStream` for broadcasting data.
    private func createStreams() {
        stream = CameraStream()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate Conformance
extension Camera: AVCapturePhotoCaptureDelegate {
    nonisolated public func photoOutput(
        _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        Task {
            await processPhoto(photo)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate Conformance
extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer, options: [.applyOrientationProperty: true])
        Task {
            guard let rotationCoordinator = await config.rotationCoordinator else {
                return
            }
            connection.videoRotationAngle =
                await rotationCoordinator.videoRotationAngleForHorizonLevelCapture
            
            await self.stream.emitPreview(image)
        }
    }
}
