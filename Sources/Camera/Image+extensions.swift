import SwiftUI
import AVFoundation

extension Image.Orientation {
    init(_ cgOrientation: CGImagePropertyOrientation) {
        switch cgOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        }
    }

}

extension Image {
    public init?(avCapturePhoto: AVCapturePhoto) {
        guard let cgImage = avCapturePhoto.cgImageRepresentation(),
              let metadataOrientation = avCapturePhoto.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
              let cgImageOrientation = CGImagePropertyOrientation(rawValue: metadataOrientation)
        else {
            return nil
        }
        let imageOrientation = Image.Orientation(cgImageOrientation)
        self = Image(decorative: cgImage, scale: 1, orientation: imageOrientation)
    }
    
}
