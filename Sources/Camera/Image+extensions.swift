import SwiftUI
import AVFoundation
import Camera

extension Image.Orientation {
    /// Initializes an `Image.Orientation` from a `CGImagePropertyOrientation`.
    /// This is useful for converting orientation metadata from an image file into a SwiftUI `Image.Orientation`.
    /// - Parameter cgOrientation: The `CGImagePropertyOrientation` from the image metadata.
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
        @unknown default:
            self = .up
        }
    }
}

extension Image {
    
    public init?(photo: any PhotoData) {
        guard let data = photo.fileDataRepresentation()
        , let uiImage = UIImage(data: data) else {
            return nil
        }
        
        self.init(uiImage: uiImage)
    }
    /// Failable initializer that creates a SwiftUI `Image` from an `AVCapturePhoto`.
    /// This initializer correctly handles the image orientation based on the photo's metadata.
    /// - Parameter avCapturePhoto: The `AVCapturePhoto` to create the image from.
    public init?(avCapturePhoto: AVCapturePhoto) {
        guard let cgImage = avCapturePhoto.cgImageRepresentation(),
              let metadataOrientation = avCapturePhoto.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
              let cgImageOrientation = CGImagePropertyOrientation(rawValue: metadataOrientation)
        else {
            return nil
        }
        let imageOrientation = Image.Orientation(cgImageOrientation)
        self.init(decorative: cgImage, scale: 1, orientation: imageOrientation)
    }
}
