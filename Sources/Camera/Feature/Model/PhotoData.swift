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
        var baseImage: CIImage?
        
        if let data = fileDataRepresentation(),
           let ciImage = CIImage(data: data, options: [.applyOrientationProperty: true]) {
            baseImage = ciImage
        } else if let cgImage = cgImageRepresentation() {
            baseImage = CIImage(cgImage: cgImage)
        } else if let pixelBuffer = pixelBuffer {
            baseImage = CIImage(cvPixelBuffer: pixelBuffer)
        } else if let previewPixelBuffer = previewPixelBuffer {
            baseImage = CIImage(cvPixelBuffer: previewPixelBuffer)
        }
        
        guard let baseImage else { return nil }
        return baseImage.cropped(to: ratio)
    }

}
