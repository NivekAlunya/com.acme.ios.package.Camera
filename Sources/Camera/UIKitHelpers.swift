import UIKit
import SwiftUI
import AVFoundation

extension Image {
    init?(avCapturePhoto: AVCapturePhoto) {
        guard let cgImage = avCapturePhoto.cgImageRepresentation() else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        self.init(uiImage: image)
    }
}

class UIKitCameraHelper {
    static func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}
