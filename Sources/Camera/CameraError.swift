//
//  CameraError.swift
//  Camera
//
//  Created by Kevin LAUNAY on 28/08/2025.
//


enum CameraError: Error {
    case cameraUnavailable
    case cameraUnauthorized
    case cannotAddInput
    case cannotAddOutput
    case creationFailed
    case zoomUpdateFailed
    case cannotStartCamera
    
    var stringKey: String {
        return switch self {
        case .cameraUnauthorized: "camera error cameraUnauthorized"
        case .cameraUnavailable: "camera error cameraUnavailable"
        case .cannotAddInput: "camera error cannotAddInput"
        case .cannotAddOutput: "camera error cannotAddOutput"
        case .cannotStartCamera: "camera error cannotStartCamera"
        case .creationFailed: "camera error creationFailed"
        case .zoomUpdateFailed: "camera error zoomUpdateFailed"
        }
    }
}
