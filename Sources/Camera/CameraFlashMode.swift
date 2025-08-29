//
//  CameraFlashMode.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

enum CameraFlashMode: CaseIterable {
    case on, off, auto, unavailable

    var avFlashMode: AVCaptureDevice.FlashMode {
        return switch self {
        case .on: .on
        case .off: .off
        case .auto: .auto
        default: .off
        }
    }

    var stringKey: String {
        return switch self {
        case .on: "flash_mode_on"
        case .off: "flash_mode_off"
        case .auto: "flash_mode_auto"
        case .unavailable: "flash_mode_unavailable"
        }
    }

    
    
    var modes: [CameraFlashMode] {

        return self == .unavailable
            ? [.unavailable] : CameraFlashMode.allCases.filter { $0 != .unavailable }
    }
}
