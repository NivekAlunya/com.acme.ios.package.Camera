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

    /// The width-to-height ratio, or `nil` when no cropping should be applied.
    public var aspectRatio: CGFloat? {
        guard self != .defaultAspectRatio else { return nil }
        return getRatio()
    }

    /// Calculates the target size for cropping based on the aspect ratio and input size.
    /// - Parameter inputSize: The size of the original image/preview.
    /// - Returns: The target `CGSize` for the crop, or `nil` if no cropping is needed.
    func targetSize(for inputSize: CGSize) -> CGSize? {
        guard self != .defaultAspectRatio else { return nil }

        let isPortrait = inputSize.height >= inputSize.width
        // getRatio() is always landscape (w/h); invert for portrait images.
        let ratio = isPortrait ? 1.0 / getRatio() : getRatio()

        // Anchor width, derive height.
        let derivedHeight = inputSize.width / ratio
        if derivedHeight <= inputSize.height {
            return CGSize(width: inputSize.width, height: derivedHeight)
        }

        // Derived height exceeds image bounds — anchor height, derive width instead.
        return CGSize(width: inputSize.height * ratio, height: inputSize.height)
    }
}
