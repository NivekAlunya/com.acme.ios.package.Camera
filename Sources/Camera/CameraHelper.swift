//
//  CameraHelper.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation
import UIKit

public class CameraHelper {
    static func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera access authorized.")
            return true
        case .notDetermined:
            print("Camera access not determined.")
            // Suspend the queue while requesting access to avoid race conditions.
            let status = await AVCaptureDevice.requestAccess(for: .video)
            return status
        case .denied:
            print("Camera access denied.")
            return false
        case .restricted:
            print("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
    static func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait:
            return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            return AVCaptureVideoOrientation.landscapeLeft
        default:
            return nil
        }
    }
}
