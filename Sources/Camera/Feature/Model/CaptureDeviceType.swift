//
//  CaptureDeviceType.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

/// A wrapper enum for `AVCaptureDevice.DeviceType` to provide a `CaseIterable` and more convenient interface.
/// The order of cases in this enum determines the priority of camera selection. 
/// Devices at the top are preferred as they offer the most features (e.g., Triple Camera for Macro support).
public enum CaptureDeviceType: CaseIterable {

    case builtInTripleCamera     // Priority 1: Supports automatic macro lens switching
    case builtInDualWideCamera   // Priority 2: Supports Wide and Ultra-Wide lens switching
    case builtInDualCamera       // Priority 3: Supports Wide and Telephoto lens switching
    case builtInUltraWideCamera
    case builtInWideAngleCamera
    case builtInTelephotoCamera
    case builtInLiDARDepthCamera
    case builtInTrueDepthCamera
    case builtInMicrophone
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
