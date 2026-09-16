//
//  CameraResolution.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation
import CoreMedia

/// Represents the target photo resolution (Megapixels).
/// Note: Capturing at 24 MP or 48 MP requires a supported device (e.g., iPhone 14 Pro or later)
/// and a corresponding compatible `AVCaptureDevice.Format`.
public enum CameraResolution: CaseIterable, Sendable, Comparable {
    case mp12
    case mp24
    case mp48

    /// A computed property that returns a localization key for each resolution.
    var stringKey: String {
        switch self {
        case .mp12: return "resolution_12mp"
        case .mp24: return "resolution_24mp"
        case .mp48: return "resolution_48mp"
        }
    }
    
    /// Returns the approximate Megapixel count for comparison.
    var approximateMegapixels: Int {
        switch self {
        case .mp12: return 12
        case .mp24: return 24
        case .mp48: return 48
        }
    }

    public static func < (lhs: CameraResolution, rhs: CameraResolution) -> Bool {
        return lhs.approximateMegapixels < rhs.approximateMegapixels
    }
}
