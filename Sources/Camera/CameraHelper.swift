//
//  CameraHelper.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation
import UIKit

/// A utility class providing helper methods for camera-related tasks.
public class CameraHelper {

    /// Checks the current authorization status for video capture.
    /// If the status is not determined, it requests access from the user.
    /// - Returns: A boolean indicating whether the app is authorized to use the camera.
    static func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            // Suspend the execution to await the user's decision.
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Converts a `UIDeviceOrientation` to the corresponding `AVCaptureVideoOrientation`.
    /// Note that the mappings might seem counter-intuitive due to the different coordinate systems.
    /// - Parameter deviceOrientation: The orientation of the device.
    /// - Returns: The corresponding video orientation, or `nil` if there's no direct mapping.
    static func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return nil
        }
    }

    /// Converts a rotation angle in degrees to the corresponding `AVCaptureVideoOrientation`.
    /// This is useful for setting the orientation based on sensor data.
    /// - Parameter deviceOrientation: The rotation angle of the device.
    /// - Returns: The corresponding video orientation, or `nil` if the angle is not standard.
    static func videoOrientationFor(deviceOrientation: CGFloat) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case 90.0:
            return .portrait
        case 270.0:
            return .portraitUpsideDown
        case 0.0:
            return .landscapeRight
        case 180.0:
            return .landscapeLeft
        default:
            return nil
        }
    }
    
    /// A helper function to create a `LocalizedStringResource` from a string key.
    /// This simplifies the process of localizing strings from the package's `.xcstrings` file.
    /// - Parameters:
    ///   - string: The key for the localized string.
    ///   - bundle: The bundle where the `Camera.xcstrings` file is located.
    /// - Returns: A `LocalizedStringResource` ready to be used in SwiftUI views.
    static func stringFrom(_ string: String, bundle: Bundle) -> LocalizedStringResource {
        return LocalizedStringResource(String.LocalizationValue(string), table: "Camera", bundle: .atURL(bundle.bundleURL))
    }
}
