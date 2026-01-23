//
//  CameraFlashMode.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

/// Represents the flash modes available for the camera.
public enum CameraFlashMode: CaseIterable {
    /// The flash will always be used.
    case on
    /// The flash will never be used.
    case off
    /// The camera will decide automatically whether to use the flash.
    case auto
    /// The flash is not available on the current device.
    case unavailable

    /// Converts the `CameraFlashMode` to the corresponding `AVCaptureDevice.FlashMode`.
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .on: .on
        case .off: .off
        case .auto: .auto
        default: .off // Default to off if unavailable or for any other case.
        }
    }

    /// A computed property that returns a localization key for each flash mode.
    var stringKey: String {
        switch self {
        case .on: "flash_mode_on"
        case .off: "flash_mode_off"
        case .auto: "flash_mode_auto"
        case .unavailable: "flash_mode_unavailable"
        }
    }
    
    /// Returns a list of available flash modes.
    /// If the flash is unavailable, it returns only the `.unavailable` case.
    /// Otherwise, it returns all modes except `.unavailable`.
    var modes: [CameraFlashMode] {
        return self == .unavailable
            ? [.unavailable]
            : CameraFlashMode.allCases.filter { $0 != .unavailable }
    }
}
