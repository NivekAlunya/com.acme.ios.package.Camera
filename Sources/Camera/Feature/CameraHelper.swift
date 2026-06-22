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
    public static func checkAuthorization() async -> Bool {
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
    public static func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
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
    public static func videoOrientationFor(deviceOrientation: CGFloat) -> AVCaptureVideoOrientation? {
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
    
    /// A helper function to create a localized string from a string key.
    ///
    /// This method prioritizes the provided bundle (usually the host application) and falls back
    /// to the package's internal module bundle if the translation is missing.
    ///
    /// - Parameters:
    ///   - string: The key for the localized string.
    ///   - bundle: The primary bundle to search for the translation.
    /// - Returns: The localized string if found, otherwise the key itself.
    public static func stringFrom(_ string: String, bundle: Bundle) -> String {
        let requestedStr = String(localized: String.LocalizationValue(string), table: "Camera", bundle: bundle)
        
        // If the translation matches the key and we are not already looking at the module bundle,
        // it might mean the translation is missing in the host's bundle. Try the module bundle.
        if requestedStr == string && bundle != .module {
            return String(localized: String.LocalizationValue(string), table: "Camera", bundle: .module)
        }
        
        return requestedStr
    }
}

extension String {
    /// Localizes the string using the Camera table with bundle fallback logic.
    ///
    /// The method first checks the provided `bundle` (typically the app's main bundle) to allow
    /// the host application to override package-default strings. If not found, it falls back
    /// to the internal `Bundle.module`.
    ///
    /// - Parameters:
    ///   - bundle: The primary bundle to check for overrides.
    ///   - defaultValue: An optional string to return if no localization is found for the key.
    /// - Returns: The localized string. Defaults to the key itself if no translation or `defaultValue` is found.
    public func cameraLocalized(bundle: Bundle, defaultValue: String? = nil) -> String {
        let result = CameraHelper.stringFrom(self, bundle: bundle)
        if result == self, let defaultValue {
            return defaultValue
        }
        return result
    }
}
