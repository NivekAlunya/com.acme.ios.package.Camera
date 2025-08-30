//
//  CIImage+extensions.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import SwiftUI
import CoreImage
import CoreGraphics
 
/// A shared `CIContext` for performance. Creating a `CIContext` is expensive,
/// so it should be initialized once and reused.
private let sharedCIContext = CIContext()

extension CIImage {
    /// Asynchronously converts a `CIImage` to a `CGImage`.
    ///
    /// This operation is performed in a detached task to avoid blocking the main thread,
    /// as rendering a `CIImage` can be computationally intensive.
    ///
    /// - Returns: A `CGImage` instance, or `nil` if the conversion fails.
    func toCGImage() async -> CGImage? {
        return await Task.detached {
            guard let cgImage = sharedCIContext.createCGImage(self, from: self.extent) else {
                return nil
            }
            return cgImage
        }.value
    }
}
