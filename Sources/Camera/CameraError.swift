//
//  CameraError.swift
//  Camera
//
//  Created by Kevin LAUNAY on 28/08/2024.
//

/// Represents the errors that can occur during camera operations.
enum CameraError: Error {
    /// The required camera device is not available on the current hardware.
    case cameraUnavailable
    /// The user has not granted permission to use the camera.
    case cameraUnauthorized
    /// The specified input device cannot be added to the capture session.
    case cannotAddInput
    /// The specified output cannot be added to the capture session.
    case cannotAddOutput
    /// Failed to create the capture session or a required component.
    case creationFailed
    /// Failed to update the zoom factor of the camera.
    case zoomUpdateFailed
    /// The camera session is already running and cannot be started again.
    case cannotStartCamera
    
    /// A computed property that returns a localization key for each error case.
    var stringKey: String {
        switch self {
        case .cameraUnauthorized: "camera_error_cameraUnauthorized"
        case .cameraUnavailable: "camera_error_cameraUnavailable"
        case .cannotAddInput: "camera_error_cannotAddInput"
        case .cannotAddOutput: "camera_error_cannotAddOutput"
        case .cannotStartCamera: "camera_error_cannotStartCamera"
        case .creationFailed: "camera_error_creationFailed"
        case .zoomUpdateFailed: "camera_error_zoomUpdateFailed"
        }
    }
}
