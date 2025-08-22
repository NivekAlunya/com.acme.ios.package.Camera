//  CameraStreamProtocol.swift
//  Camera
//
//  Created for protocol and mock implementations related to CameraStream.
//

import CoreImage
import AVFoundation

/// Protocol defining the interface of CameraStream.
protocol CameraStreamProtocol: Actor {
    var isPreviewPaused: Bool { get }
    var previewStream: AsyncStream<CIImage> { get }
    var photoStream: AsyncStream<AVCapturePhoto> { get }

    func emitPreview(_ ciImage: CIImage)
    func emitPhoto(_ photo: AVCapturePhoto)
    func pause()
    func resume()
    func finish()
}

/// Mock class for CameraStreamProtocol, useful for testing.
final actor MockCameraStream: CameraStreamProtocol {
    private(set) var isPreviewPaused: Bool = false
    var previewEmittedImages: [CIImage] = []
    var photoEmittedPhotos: [AVCapturePhoto] = []

    // Provide a stream that never emits in the mock.
    let previewStream = AsyncStream<CIImage> { _ in }
    let photoStream = AsyncStream<AVCapturePhoto> { _ in }

    func emitPreview(_ ciImage: CIImage) {
        previewEmittedImages.append(ciImage)
    }

    func emitPhoto(_ photo: AVCapturePhoto) {
        photoEmittedPhotos.append(photo)
    }

    func pause() {
        isPreviewPaused = true
    }

    func resume() {
        isPreviewPaused = false
    }

    func finish() {
        // No-op for mock
    }
}

