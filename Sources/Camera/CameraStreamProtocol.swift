//  CameraStreamProtocol.swift
//  Camera
//
//  Created for protocol and mock implementations related to CameraStream.
//

import CoreImage
@preconcurrency import AVFoundation

/// Protocol defining the interface of CameraStream.
protocol CameraStreamProtocol: Actor {
    var isPreviewPaused: Bool { get }
    var previewStream: AsyncStream<CIImage> { get }
    var photoStream: AsyncStream<CIImage> { get }

    func emitPreview(_ ciImage: CIImage)
    func emitPhoto(_ ciImage: CIImage)
    func pause()
    func resume()
    func finish()
}
