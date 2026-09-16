//
//  CIImage+extensions.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import SwiftUI
import CoreImage
import CoreGraphics
import ImageIO
 
/// A shared `CIContext` for performance. Creating a `CIContext` is expensive,
/// so it should be initialized once and reused.
internal let sharedCIContext = CIContext()

extension CIImage {
    /// Asynchronously converts a `CIImage` to a `CGImage`.
    ///
    /// This operation is performed in a detached task to avoid blocking the main thread,
    /// as rendering a `CIImage` can be computationally intensive.
    ///
    /// - Returns: A `CGImage` instance, or `nil` if the conversion fails.
    public func toCGImage() async -> CGImage? {
        return await Task.detached {
            guard !self.extent.isInfinite && !self.extent.isEmpty,
                  let cgImage = sharedCIContext.createCGImage(self, from: self.extent) else {
                return nil
            }
            return cgImage
        }.value
    }

    /// Asynchronously converts a `CIImage` to JPEG data.
    /// - Parameter quality: Lossy compression quality between 0.0 and 1.0 (default 0.95).
    public func toJPEGData(quality: Double = 0.95) async -> Data? {
        return await Task.detached {
            guard !self.extent.isInfinite && !self.extent.isEmpty else { return nil }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let options: [CIImageRepresentationOption: Any] = [
                kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality
            ]
            return sharedCIContext.jpegRepresentation(of: self, colorSpace: colorSpace, options: options)
        }.value
    }
}
