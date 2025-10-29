//
//  CameraStream.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import CoreImage
@preconcurrency import AVFoundation

/// An actor that manages the asynchronous streams of preview frames and captured photos from the camera.
actor CameraStream: CameraStreamProtocol {

    /// A flag indicating whether the preview stream is paused.
    private(set) var isPreviewPaused = false

    /// The continuation for the preview stream, used to yield new frames.
    private var previewContinuation: AsyncStream<CIImage>.Continuation?

    /// A counter to skip the first few frames, which sometimes have orientation issues.
    private var skipFirstFrame = 2

    /// A lazy-initialized asynchronous stream of `CIImage` for camera previews.
    private(set) lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            self.previewContinuation = continuation
        }
    }()

    /// The continuation for the photo stream, used to yield captured photos.
    private var photoContinuation: AsyncStream<CIImage>.Continuation?
    
    /// A lazy-initialized asynchronous stream of `CIImage` for captured photos.
    private(set) lazy var photoStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            self.photoContinuation = continuation
        }
    }()

    /// Emits a new preview frame to the `previewStream`.
    /// This method skips the first couple of frames to avoid potential orientation bugs.
    /// - Parameter ciImage: The `CIImage` to emit.
    func emitPreview(_ ciImage: CIImage) {
        guard skipFirstFrame == 0 else {
            skipFirstFrame -= 1
            return
        }
        if !isPreviewPaused {
            previewContinuation?.yield(ciImage)
        }
    }
    
    /// Emits a new captured photo to the `photoStream`.
    /// - Parameter ciImage: The `CIImage` to emit.
    func emitPhoto(_ ciImage: CIImage) {
        photoContinuation?.yield(ciImage)
    }
    
    /// Pauses the preview stream.
    func pause() {
        isPreviewPaused = true
    }

    /// Resumes the preview stream.
    func resume() {
        isPreviewPaused = false
    }

    /// Finishes both the photo and preview streams, terminating them.
    func finish() {
        photoContinuation?.finish()
        previewContinuation?.finish()
    }
}
