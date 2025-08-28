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
        case .on: "flash mode on"
        case .off: "flash mode off"
        case .auto: "flash mode auto"
        case .unavailable: "flash mode unavailable"
        }
    }

    
    
    var modes: [CameraFlashMode] {

        return self == .unavailable
            ? [.unavailable] : CameraFlashMode.allCases.filter { $0 != .unavailable }
    }
}
