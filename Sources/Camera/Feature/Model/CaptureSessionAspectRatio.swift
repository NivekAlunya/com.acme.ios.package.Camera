//
//  CaptureSessionAspectRatio.swift
//  Camera
//
//  Created by Kevin Launay on 22/01/2026.
//

import Foundation


public enum CaptureSessionAspectRatio: Sendable, CaseIterable {
    case ratio_4_3
    case ratio_16_9
    case ratio_1_1
    case defaultAspectRatio
    
    /// Returns the localization key for the aspect ratio.
    public var stringKey: String {
        switch self {
        case .ratio_4_3:
            return "aspect_ratio_4_3"
        case .ratio_16_9:
            return "aspect_ratio_16_9"
        case .ratio_1_1:
            return "aspect_ratio_1_1"
        case .defaultAspectRatio:
            return "aspect_ratio_default"
        }
    }
    
    func getSfSymbol() -> String {
        
        switch self {
        case .ratio_4_3:
            return "rectangle.ratio.3.to.4"
        case .ratio_16_9:
            return "rectangle.ratio.9.to.16"
        case .ratio_1_1:
            return "square"
        case .defaultAspectRatio:
            return "rectangle.portrait"
        }
        
    }
    
    func getRatio() -> CGFloat {
        switch self {
        case .ratio_4_3:
            return 4.0 / 3.0
        case .ratio_16_9:
            return 16.0 / 9.0
        case .ratio_1_1:
            return 1.0
        case .defaultAspectRatio:
            return 0.0
        }
    }

    /// Calculates the target size for cropping based on the aspect ratio and input size.
    /// - Parameter inputSize: The size of the original image/preview.
    /// - Returns: The target `CGSize` for the crop, or `nil` if no cropping is needed.
    func targetSize(for inputSize: CGSize) -> CGSize? {
        guard self != .defaultAspectRatio else { return nil }
        
        let width = inputSize.width
        let height = inputSize.height
        let isPortrait = height >= width
        let targetRatio = getRatio()
        
        if isPortrait {
            // Target ratio is W/H. For portrait, we use 1/targetRatio (e.g., 3/4 for 4:3).
            let portraitRatio = 1 / targetRatio
            let imageRatio = width / height
            
            if imageRatio >= portraitRatio {
                // Image is wider than target: fit to height
                return CGSize(width: height * portraitRatio, height: height)
            } else {
                // Image is taller than target: fit to width
                return CGSize(width: width, height: width / portraitRatio)
            }
        } else {
            // Landscape: targetRatio is W/H (e.g., 4/3 for 4:3).
            let imageRatio = width / height
            
            if imageRatio < targetRatio {
                // Target is wider than the image (e.g. 16:9 on a 4:3 sensor).
                // Cannot fill that ratio without exceeding bounds — keep the full image.
                return nil
            } else {
                // Image is wider than or equal to the target: fit to height, crop width sides.
                return CGSize(width: height * targetRatio, height: height)
            }
        }
    }
}

