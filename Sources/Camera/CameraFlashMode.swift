//
//  CameraFlashMode.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

enum CameraFlashMode {
    case on, off, auto, unavailable
    var avFlashMode: AVCaptureDevice.FlashMode {
        return switch self {
        case .on: .on
        case .off: .off
        case .auto: .auto
        default: .off
        }
    }
}
