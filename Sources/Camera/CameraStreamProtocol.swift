//
//  CameraStreamProtocol.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import CoreImage
@preconcurrency import AVFoundation

/// Defines the interface for a camera stream, which provides asynchronous streams of preview frames and captured photos.
protocol CameraStreamProtocol: Actor {
    /// A boolean indicating whether the preview stream is currently paused.
    var isPreviewPaused: Bool { get }

    /// An asynchronous stream of `CIImage` objects representing the camera preview.
    var previewStream: AsyncStream<CIImage> { get }

    /// An asynchronous stream of `CIImage` objects representing captured photos.
    var photoStream: AsyncStream<CIImage> { get }

    /// Emits a new preview image to the `previewStream`.
    /// - Parameter ciImage: The `CIImage` to emit.
    func emitPreview(_ ciImage: CIImage)

    /// Emits a new captured photo to the `photoStream`.
    /// - Parameter ciImage: The `CIImage` to emit.
    func emitPhoto(_ ciImage: CIImage)

    /// Pauses the emission of preview frames.
    func pause()

    /// Resumes the emission of preview frames.
    func resume()

    /// Finishes the streams and releases resources.
    func finish()
}
