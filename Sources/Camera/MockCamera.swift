//
//  MockCamera.swift
//  Camera
//
//  Created by Kevin LAUNAY.

@preconcurrency import AVFoundation
import CoreImage
import Foundation

// MARK: - MockCameraActor
actor MockCamera: CameraProtocol {
    var previewImages: [CIImage]
    var photoImages: [CIImage]

    func changeZoom(_ factor: Float) {

    }

    func createStreams() {
        stream = CameraStream()
    }

    func setConfig(_ config: CameraConfiguration) throws {
        self.config = config
    }

    var photo: AVCapturePhoto?

    var stream: any CameraStreamProtocol
    var config: CameraConfiguration

    init(
        configuration: CameraConfiguration = CameraConfiguration(), previewImages: [CIImage] = [],
        photoImages: [CIImage] = []
    ) {
        self.config = configuration
        self.stream = CameraStream()
        self.previewImages = previewImages
        self.photoImages = photoImages
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
        for image in previewImages {
            await stream.emitPreview(image)
        }
    }

    func resume() async {
        // No-op for mock
    }

    func pause() async {
        // No-op for mock
    }

    func takePhoto() async {
        for image in photoImages {
            await stream.emitPhoto(image)
        }
    }

    func changeFlashMode(_ value: CameraFlashMode) {
        config.flashMode = value
    }

    func changeCodec(_ codec: VideoCodecType) {
        config.videoCodecType = codec
    }

    func changePosition() async throws {
        config.switchPosition()
    }

    func end() async {
        // No-op for mock
    }
}
