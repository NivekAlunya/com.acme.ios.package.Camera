//
//  CameraFlashMode.swift
//  Camera
//
//  Created by Kevin LAUNAY on 22/08/2025.
//

import AVFoundation

enum CameraFlashMode {
    case on, off, auto, unavailbale
    var avFlashMode: AVCaptureDevice.FlashMode {
        return switch self {
        case .on: .on
        case .off: .off
        case .auto: .auto
        default: .off
        }
    }
}
