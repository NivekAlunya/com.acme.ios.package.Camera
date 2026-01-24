//
//  CIImage+Crop.swift
//  Camera
//
//  Created by Kevin LAUNAY on 23/01/2026.
//

import CoreImage
import Foundation

extension CIImage {
    /// Crops the image to a centered rectangle matching the given aspect ratio.
    /// - Parameter ratio: The target aspect ratio.
    /// - Returns: A cropped `CIImage`.
    public func cropped(to ratio: CaptureSessionAspectRatio) -> CIImage {
        guard let targetSize = ratio.targetSize(for: self.extent.size) else {
            return self
        }
        
        let offsetX = (self.extent.width - targetSize.width) / 2
        let offsetY = (self.extent.height - targetSize.height) / 2
        
        return self.cropped(to: CGRect(
            origin: CGPoint(x: offsetX, y: offsetY),
            size: targetSize
        ))
    }
}
