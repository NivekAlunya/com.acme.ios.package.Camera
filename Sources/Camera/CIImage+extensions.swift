//
//  CIImage+extensions.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import SwiftUI
import CoreImage
import CoreGraphics
 
// Reuse the CIContext for performance.
// This should be initialized once and shared across your image processing pipeline.
private let sharedCIContext = CIContext()
extension CIImage {
    func toCGImage() async -> CGImage? {
           return await Task.detached {
                guard let cgImage = sharedCIContext.createCGImage(self, from: self.extent) else {
                    print("Failed to create CGImage from CIImage.")
                    return nil
                }
                return cgImage
        }.value // Await the result of the detached task
    }
}
