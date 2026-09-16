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
    private let previewContinuation: AsyncStream<CIImage>.Continuation

    /// The asynchronous stream of `CIImage` for camera previews.
    let previewStream: AsyncStream<CIImage>

    /// The continuation for the photo stream, used to yield captured photos.
    private let photoContinuation: AsyncStream<CIImage>.Continuation
    
    /// The asynchronous stream of `CIImage` for captured photos.
    let photoStream: AsyncStream<CIImage>
    
    /// The continuation for the error stream.
    private let errorContinuation: AsyncStream<CameraError>.Continuation
    
    /// The asynchronous stream of `CameraError` objects.
    let errorStream: AsyncStream<CameraError>

    /// A counter to skip initial frames if configured.
    private var skipFirstFrame: Int

    /// Initializes a `CameraStream` with eager continuation creation.
    /// - Parameter skipFirstFrame: Number of initial preview frames to skip (default: 0).
    init(skipFirstFrame: Int = 0) {
        self.skipFirstFrame = skipFirstFrame

        let (pStream, pCont) = AsyncStream.makeStream(of: CIImage.self, bufferingPolicy: .bufferingNewest(1))
        self.previewStream = pStream
        self.previewContinuation = pCont

        let (phStream, phCont) = AsyncStream.makeStream(of: CIImage.self, bufferingPolicy: .unbounded)
        self.photoStream = phStream
        self.photoContinuation = phCont

        let (eStream, eCont) = AsyncStream.makeStream(of: CameraError.self, bufferingPolicy: .bufferingNewest(1))
        self.errorStream = eStream
        self.errorContinuation = eCont
    }

    /// Emits a new preview frame to the `previewStream`.
    /// - Parameter ciImage: The `CIImage` to emit.
    func emitPreview(_ ciImage: CIImage) {
        guard skipFirstFrame == 0 else {
            skipFirstFrame -= 1
            return
        }
        if !isPreviewPaused {
            previewContinuation.yield(ciImage)
        }
    }
    
    /// Emits a new captured photo to the `photoStream`.
    /// - Parameter ciImage: The `CIImage` to emit.
    func emitPhoto(_ ciImage: CIImage) {
        photoContinuation.yield(ciImage)
    }
    
    /// Emits an error to the `errorStream`.
    /// - Parameter error: The `CameraError` to emit.
    func emitError(_ error: CameraError) {
        errorContinuation.yield(error)
    }
    
    /// Pauses the preview stream.
    func pause() {
        isPreviewPaused = true
    }

    /// Resumes the preview stream.
    func resume() {
        isPreviewPaused = false
    }

    /// Finishes all streams, terminating them.
    func finish() {
        photoContinuation.finish()
        previewContinuation.finish()
        errorContinuation.finish()
    }
}
