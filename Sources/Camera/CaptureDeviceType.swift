//
//  CaptureDeviceType.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

/// A wrapper enum for `AVCaptureDevice.DeviceType` to provide a `CaseIterable` and more convenient interface.
public enum CaptureDeviceType: CaseIterable {

    case builtInDualCamera
    case builtInDualWideCamera
    case builtInLiDARDepthCamera
    case builtInMicrophone
    case builtInTelephotoCamera
    case builtInTripleCamera
    case builtInTrueDepthCamera
    case builtInUltraWideCamera
    case builtInWideAngleCamera
    case continuityCamera
    case external
    case microphone
#if os(macOS)
    case deskViewCamera
    case externalUnknown
#endif
    
    /// The string representation of the device type.
    var name: String {
        switch self {
        case .builtInDualCamera: "builtInDualCamera"
        case .builtInDualWideCamera: "builtInDualWideCamera"
        case .builtInLiDARDepthCamera: "builtInLiDARDepthCamera"
        case .builtInMicrophone: "builtInMicrophone"
        case .builtInTelephotoCamera: "builtInTelephotoCamera"
        case .builtInTripleCamera: "builtInTripleCamera"
        case .builtInTrueDepthCamera: "builtInTrueDepthCamera"
        case .builtInUltraWideCamera: "builtInUltraWideCamera"
        case .builtInWideAngleCamera: "builtInWideAngleCamera"
        case .continuityCamera: "continuityCamera"
        case .external: "external"
        case .microphone: "microphone"
#if os(macOS)
        case .deskViewCamera: "deskViewCamera"
        case .externalUnknown: "externalUnknown"
#endif
        }
    }
    
    /// The corresponding `AVCaptureDevice.DeviceType`.
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .builtInDualCamera: .builtInDualCamera
        case .builtInDualWideCamera: .builtInDualWideCamera
        case .builtInLiDARDepthCamera: .builtInLiDARDepthCamera
        case .builtInMicrophone: .builtInMicrophone
        case .builtInTelephotoCamera: .builtInTelephotoCamera
        case .builtInTripleCamera: .builtInTripleCamera
        case .builtInTrueDepthCamera: .builtInTrueDepthCamera
        case .builtInUltraWideCamera: .builtInUltraWideCamera
        case .builtInWideAngleCamera: .builtInWideAngleCamera
        case .continuityCamera: .continuityCamera
        case .external: .external
        case .microphone: .microphone
#if os(macOS)
        case .deskViewCamera: .deskViewCamera
        case .externalUnknown: .externalUnknown
#endif
        }
    }
}
