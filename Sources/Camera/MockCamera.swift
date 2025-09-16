//
//  MockCamera.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

@preconcurrency import AVFoundation
import CoreImage
import Foundation

/// A mock implementation of the `CameraProtocol` for testing and SwiftUI previews.
/// This actor simulates the behavior of the real camera, allowing for UI development and testing without a physical device.
actor MockCamera: CameraProtocol {

    /// An array of `CIImage`s to be used for the preview stream.
    var previewImages: [CIImage]

    /// An array of `CIImage`s to be used for the photo stream.
    var photoImages: [CIImage]

    /// The mock's current configuration.
    var config: CameraConfiguration

    /// The mock's stream object.
    var stream: any CameraStreamProtocol

    /// A placeholder for a captured photo.
    var photo: (any PhotoData)?

    /// Initializes a `MockCamera`.
    /// - Parameters:
    ///   - configuration: The initial camera configuration.
    ///   - previewImages: A sequence of images to emit as the preview stream.
    ///   - photoImages: A sequence of images to emit as the photo stream when `takePhoto()` is called.
    init(
        configuration: CameraConfiguration = CameraConfiguration(),
        previewImages: [CIImage] = [],
        photoImages: [CIImage] = [],
        photo: (any PhotoData)? = nil
    ) {
        self.config = configuration
        self.stream = CameraStream()
        self.previewImages = previewImages
        self.photoImages = photoImages
        self.photo = photo
    }

    // MARK: - CameraProtocol Conformance

    func changeZoom(_ factor: CGFloat) {
        // No-op for mock
    }

    func changePreset(preset: CaptureSessionPreset) {
        config.preset = preset
    }

    func changeCamera(device: AVCaptureDevice) async throws {
        // No-op for mock
    }

    /// Simulates starting the camera by emitting the `previewImages`.
    func start() async throws {
        for image in previewImages {
            await stream.emitPreview(image)
        }
    }

    func resume() async {
        // No-op for mock
    }

    func pause() async {
        await stream.pause()
    }

    /// Simulates taking a photo by emitting the `photoImages`.
    func takePhoto() async {
        await stream.pause()
        if let image = photoImages.first {
            photoImages.removeFirst()
            let context = CIContext()
            if let data = context.pngRepresentation(of: image, format: .RGBA8, colorSpace: image.colorSpace ?? CGColorSpaceCreateDeviceRGB()) {
                self.photo = MockPhoto(data: data)
            }
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
