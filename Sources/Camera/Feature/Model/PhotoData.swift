import AVFoundation
import CoreImage

/// A protocol representing photo data captured from the camera.
public protocol PhotoData: Sendable {
    func fileDataRepresentation() -> Data?
    func getMetadata() -> [String: Any]
    func buildImageForRatio(_ ratio: CaptureSessionAspectRatio) -> CIImage?
}

extension AVCapturePhoto: PhotoData {
    public func getMetadata() -> [String: Any] {
        return self.metadata
    }
    
    public func buildImageForRatio(_ ratio: CaptureSessionAspectRatio) -> CIImage? {
        guard let data = fileDataRepresentation(),
              let ciImage = CIImage(data: data, options: [.applyOrientationProperty: true])
        else {
            return nil
        }
    
        return ciImage.cropped(to: ratio)
    }

}
