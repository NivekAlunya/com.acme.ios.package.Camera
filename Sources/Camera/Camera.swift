//
//  Camera.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//
//
// Camera actor implementation using AVFoundation and async/await for video preview and photo capture.

@preconcurrency import AVFoundation
import Foundation
import UIKit

enum CameraState: Error {
    case needSetup
    case unauthorized
    case started
    case paused
    case ended
}

public actor Camera: NSObject {

    static let shared = Camera()
    var config: CameraConfiguration
    var stream: any CameraStreamProtocol = CameraStream()
    private(set) var photo: AVCapturePhoto?
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var state = CameraState.needSetup

    public override init() {
        self.config = CameraConfiguration()
        super.init()
    }

    deinit {

    }

    private func removeDevice() {
        if session.isRunning {
            session.stopRunning()
        }
        if let deviceInput = config.deviceInput {
            session.removeInput(deviceInput)
        }
    }
    private func changeDevice(device: AVCaptureDevice) async throws {
        try await pause()
        removeDevice()
        try setup(device: device)
        try await start()
    }

    private func getDefaultCamera() -> AVCaptureDevice? {
        config.listCaptureDevice.first ?? AVCaptureDevice.default(for: .video)
    }

    private func setup(device: AVCaptureDevice) throws {

        if self.session.isRunning {
            self.session.stopRunning()
        }
        try config.setup(device: device, session: session, delegate: self)
    }

    func processPhoto(_ photo: AVCapturePhoto) async {

        guard let data = photo.fileDataRepresentation(),
            let ciImage = CIImage(data: data, options: [.applyOrientationProperty: true])
        else {
            return
        }
        self.photo = photo
        await self.stream.emitPhoto(ciImage)
    }
}

extension Camera: CameraProtocol {
    func changeZoom(_ factor: CGFloat) throws {
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

    // MARK - CameraProtocol
    func start() async throws {

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

    func resume() async {
        await stream.resume()
        state = .started
        self.session.startRunning()
    }

    /// Stops the capture session safely and pauses preview emission.
    func pause() async {
        if session.isRunning {
            await stream.pause()
            state = .paused
            self.session.stopRunning()
        }
    }

    func end() async {
        await pause()
        await stream.finish()
        state = .ended
    }
    
    func takePhoto() async {
        if let photoOutputVideoConnection = self.config.photoOutput.connection(with: .video)
            , let videoOrientation = CameraHelper.videoOrientationFor(deviceOrientation: config.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture ?? 90.0)  {
            photoOutputVideoConnection.videoOrientation = videoOrientation
        }
        await stream.pause()
        let photoSettings = await config.buildPhotoSettings()
        photoSettings.flashMode = config.flashMode.avFlashMode
        self.config.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    func changePreset(preset: CaptureSessionPreset = .photo) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        config.preset = preset
        session.sessionPreset = config.preset.avPreset
    }

    func changeCamera(device: AVCaptureDevice) async throws {
        try await changeDevice(device: device)
    }

    func changePosition() async throws {
        config.switchPosition()
        guard let device = config.getDefaultCamera() else {
            throw CameraError.cameraUnavailable
        }
        try await changeDevice(device: device)
    }

    func changeCodec(_ codec: VideoCodecType) {
        config.videoCodecType = codec
    }

    func changeFlashMode(_ flashMode: CameraFlashMode) {
        config.flashMode = flashMode
    }

    private func createStreams() {
        stream = CameraStream()
    }
}

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
