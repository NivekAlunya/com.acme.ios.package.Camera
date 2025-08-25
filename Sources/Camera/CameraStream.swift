//
//  CameraStream.swift
//  Camera
//
//  Created by Kevin LAUNAY on 22/08/2025.
//

import CoreImage
@preconcurrency import AVFoundation

actor CameraStream: CameraStreamProtocol {
    private(set) var isPreviewPaused = false
    /// Continuation used to yield preview frames into the async stream.
    private var previewContinuation: AsyncStream<CIImage>.Continuation?
    
    /// Public async stream of preview CIImages.
    private(set) lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            // Store continuation to yield preview frames later.
            self.previewContinuation = continuation
        }
    }()
    /// Continuation used to yield captured photos into the async stream.
    private var photoContinuation: AsyncStream<CIImage>.Continuation?
    
    /// Public async stream of captured photos.
    private(set) lazy var photoStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            // Store continuation to yield photos later.
            self.photoContinuation = continuation
        }
    }()

    /// Emits a CIImage preview frame to the preview stream if not paused or stopped.
    func emitPreview(_ ciImage: CIImage) {
        if !isPreviewPaused {
            previewContinuation?.yield(ciImage)
        }
    }
    
    /// Emits a captured photo to the photo stream if not paused or stopped.
    func emitPhoto(_ ciImage: CIImage) {
        photoContinuation?.yield(ciImage)
    }
    
    func pause() {
        isPreviewPaused = true
    }

    func resume() {
        isPreviewPaused = false
    }
    func finish() {
        photoContinuation?.finish()
        previewContinuation?.finish()
    }
}
