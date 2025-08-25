//  MockCameraActor.swift
//  Camera
//
//  Created for testing and previews.

import Foundation
@preconcurrency import AVFoundation
import CoreImage

// MARK: - MockCameraActor
actor MockCamera: CameraProtocol {
    func createStreams() {
        stream = CameraStream()
    }
    
    func setConfig(_ config: CameraConfiguration) throws {
        self.config = config
    }
    
    var photo: AVCapturePhoto?
    
    var stream: any CameraStreamProtocol
    var config: CameraConfiguration

    init(configuration: CameraConfiguration = CameraConfiguration()) {
        self.config = configuration
        self.stream = CameraStream()
    }

    private func samplePreviewImage() -> CIImage {
        CIImage(color: .gray).cropped(to: CGRect(x: 0, y: 0, width: 320, height: 480))
    }

    func changePreset(preset: CaptureSessionPreset) {
        config.preset = preset
    }

    func changeCamera(device: AVCaptureDevice) async throws {
        // No-op for mock
    }

    func start() async throws {
        await stream.emitPreview(samplePreviewImage())
    }

    func resume() async {
        // No-op for mock
    }

    func stop() async {
        // No-op for mock
    }

    func takePhoto() async {
        // No-op for mock
    }

    func switchFlash(_ value: CameraFlashMode) {
        config.flashMode = value
    }

    func changeCodec(_ codec: VideoCodecType) {
        config.videoCodecType = codec
    }

    func swicthPosition() async throws {
        config.switchPosition()
    }

    func end() async {
        // No-op for mock
    }
}

