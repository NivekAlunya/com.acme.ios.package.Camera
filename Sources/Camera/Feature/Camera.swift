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
    /// The camera session is currently transitioning to running.
    case starting
    /// The camera is running and capturing video.
    case started
    /// The camera session is paused.
    case paused
    /// The camera session has been terminated.
    case ended
}

/// The `Camera` actor manages all capture-related operations using AVFoundation.
/// It handles the capture session, device configuration, and data output for video and photos.
/// It can be instantiated with a custom `CameraConfiguration` to allow flexible camera setup.
public actor Camera: NSObject {

    /// The current camera configuration.
    public var config: CameraConfiguration

    /// The stream that broadcasts camera previews and captured photos.
    public var stream: any CameraStreamProtocol = CameraStream()

    /// The most recently captured photo.
    private(set) public var photo: PhotoCapture?

    /// The underlying `AVCaptureSession` that manages the capture pipeline.
    public let session = AVCaptureSession()

    /// A dedicated serial queue for AVCaptureSession operations.
    /// `startRunning` and `stopRunning` are blocking calls and must not be called
    /// on the main thread or on the actor's cooperative executor.
    private let sessionQueue = DispatchQueue(label: "com.acme.camera.sessionQueue", qos: .userInitiated)

    /// The current state of the camera.
    private var state = CameraState.needSetup

    /// Observation for device rotation changes.
    private var rotationObservation: NSKeyValueObservation?

    public init(config: CameraConfiguration = CameraConfiguration()) {

        self.config = config
    }

    /// Removes the current capture device input from the session.
    /// Must be called after `pause()` — session is guaranteed idle at this point.
    private func removeDevice() {
        if let deviceInput = config.deviceInput {
            session.removeInput(deviceInput)
        }
    }

    /// Changes the active camera device.
    /// - Parameter device: The `AVCaptureDevice` to switch to.
    private func changeDevice(device: AVCaptureDevice) async throws {
        await pause()
        removeDevice()
        try await start()
    }

    /// Retrieves the default camera device based on the current configuration.
    /// - Returns: An `AVCaptureDevice` instance, or `nil` if no suitable device is found.
    private func getDefaultCamera() -> AVCaptureDevice? {
        config.listCaptureDevice.first ?? AVCaptureDevice.default(for: .video)
    }

    /// Sets up the capture session with a specific device.
    /// Must be called after `pause()` — session is guaranteed idle at this point.
    private func setup(device: AVCaptureDevice) throws {
        try config.setup(device: device, session: session, delegate: self)
    }

    /// Processes a captured photo, converts it to a `CIImage`, and emits it through the stream.
    /// - Parameter photo: The `AVCapturePhoto` to process.
    func processPhoto(_ photo: AVCapturePhoto) async {
        // 1. Build the cropped CIImage for the preview/validation stream and final storage.
        guard let ciImage = photo.buildImageForRatio(config.ratio) else {
            return
        }

        // 2. Convert the cropped CIImage back to Data to preserve the crop in the final output.
        let croppedData = await ciImage.toJPEGData()
        
        // 3. Preserve the cropped data and original metadata.
        self.photo = PhotoCapture(data: croppedData, metadata: photo.metadata)

        // 4. Emit the cropped image for the validation UI.
        await self.stream.emitPhoto(ciImage)
    }
}

// MARK: - CameraProtocol Conformance
extension Camera: CameraProtocol {

    public func focus(on: CGPoint) async throws {
        guard let device = config.deviceInput?.device else { return }
        let focusPoint = CGPoint(x: on.x, y: 1.0 - on.y) // Convert to device coordinates
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
        } catch {
            throw CameraError.focusFailed
        }
    }

    public func changeRatio(_ ratio: CaptureSessionAspectRatio) async {
        self.config.ratio = ratio
    }

    public func changePreviewMode(_ mode: CameraPreviewMode) async {
        self.config.previewMode = mode
    }

    /// Changes the zoom factor of the camera.
    /// - Parameter factor: The desired zoom factor.
    public func changeZoom(_ factor: CGFloat) throws {
        guard let device = config.deviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let clampedFactor = max(device.minAvailableVideoZoomFactor,
                                    min(factor, device.maxAvailableVideoZoomFactor))
            device.videoZoomFactor = clampedFactor

            // Re-engage autofocus after zoom change, mirroring initial focus configuration
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }

            config.zoom = Float(device.videoZoomFactor)
        } catch {
            throw CameraError.zoomUpdateFailed
        }
    }

    /// Updates the rotation angle for both preview and photo outputs.
    private func updateRotationAngle() {
        let angle = config.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90.0
        
        if let connection = config.videoOutput.connection(with: .video) {
            connection.videoRotationAngle = angle
        }
        
        if let photoConnection = config.photoOutput.connection(with: .video) {
            photoConnection.videoRotationAngle = angle
        }
    }

    /// Sets up observation for rotation changes.
    private func setupRotationObservation() {
        rotationObservation = config.rotationCoordinator?.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] _, _ in
            Task { [weak self] in
                await self?.updateRotationAngle()
            }
        }
    }

    /// Starts the camera session.
    /// This method checks for authorization, sets up the camera if needed, and starts the session.
    public func start() async throws {
        guard state != .started, state != .starting else {
            throw CameraError.cannotStartCamera
        }

        let previousState = state
        state = .starting
        do {
            let authorized = await CameraHelper.checkAuthorization()
            guard authorized else {
                state = .unauthorized
                throw CameraError.cameraUnauthorized
            }

            switch previousState {
            case .needSetup:
                guard let device = config.getDefaultCamera() else {
                    throw CameraError.cameraUnavailable
                }
                try setup(device: device)
                createStreams()
            case .ended:
                createStreams()
            default:
                break
            }

            updateRotationAngle()
            setupRotationObservation()
            
            let session = self.session
            await stream.resume()
            await withCheckedContinuation { continuation in
                sessionQueue.async {
                    if !session.isRunning {
                        session.startRunning()
                    }
                    continuation.resume()
                }
            }
            state = .started
        } catch {
            if state == .starting {
                state = previousState
            }
            throw error
        }
    }

    /// Resumes a paused camera session.
    public func resume() async {
        await stream.resume()
        updateRotationAngle()
        setupRotationObservation()
        let session = self.session
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
        state = .started
    }

    /// Pauses the camera session and stops the preview stream.
    /// Suspends the actor (non-blocking) until `stopRunning` has fully completed on the
    /// session queue, guaranteeing the session is idle before callers like `changeDevice`
    /// or `end` proceed.
    public func pause() async {
        rotationObservation?.invalidate()
        rotationObservation = nil
        let session = self.session
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if session.isRunning {
                    session.stopRunning()
                }
                continuation.resume()
            }
        }
        await stream.pause()
        state = .paused
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
        updateRotationAngle()
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
        let image = CIImage(
            cvPixelBuffer: pixelBuffer,
            options: [.applyOrientationProperty: true]
        )
        
        Task {
            guard await self.config.previewMode == .streaming else { return }
            await self.stream.emitPreview(image)
        }
    }
}
