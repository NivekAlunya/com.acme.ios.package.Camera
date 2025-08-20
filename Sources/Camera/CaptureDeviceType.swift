//
//  CaptureDeviceType.swift
//  Camera
//
//  Created by Kevin LAUNAY on 20/08/2025.
//

import AVFoundation


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
    

    var name: String {
        return switch self {
        case .builtInDualCamera: "builtInDualCamera"
        case .builtInDualWideCamera: "builtInDualWideCamera"
        case .builtInLiDARDepthCamera: "builtInLiDARDepthCamera"
        case .builtInMicrophone: "builtInMicrophone"
        case .builtInTelephotoCamera: "builtInTelephotoCamera"
        case .builtInTripleCamera: "builtInTripleCamera"
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
    
    var deviceType: AVCaptureDevice.DeviceType {
        return switch self {
        case .builtInDualCamera: AVCaptureDevice.DeviceType.builtInDualCamera
        case .builtInDualWideCamera: AVCaptureDevice.DeviceType.builtInDualWideCamera
        case .builtInLiDARDepthCamera: AVCaptureDevice.DeviceType.builtInLiDARDepthCamera
        case .builtInMicrophone: AVCaptureDevice.DeviceType.builtInMicrophone
        case .builtInTelephotoCamera: AVCaptureDevice.DeviceType.builtInTelephotoCamera
        case .builtInTripleCamera: AVCaptureDevice.DeviceType.builtInTripleCamera
        case .builtInTripleCamera: AVCaptureDevice.DeviceType.builtInTripleCamera
        case .builtInTrueDepthCamera: AVCaptureDevice.DeviceType.builtInTrueDepthCamera
        case .builtInUltraWideCamera: AVCaptureDevice.DeviceType.builtInUltraWideCamera
        case .builtInWideAngleCamera: AVCaptureDevice.DeviceType.builtInWideAngleCamera
        case .continuityCamera: AVCaptureDevice.DeviceType.continuityCamera
        case .external: AVCaptureDevice.DeviceType.external
        case .microphone: AVCaptureDevice.DeviceType.microphone
#if os(macOS)
        case .deskViewCamera: AVCaptureDevice.DeviceType.deskViewCamera
        case .externalUnknown: AVCaptureDevice.DeviceType.externalUnknown
#endif
        }
    }
}
