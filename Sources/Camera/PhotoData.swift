import AVFoundation

public protocol PhotoData: Sendable {
    func fileDataRepresentation() -> Data?
    func getMetadata() -> [String: Any]
}

extension AVCapturePhoto: PhotoData {
    public func getMetadata() -> [String: Any] {
        return self.metadata
    }
}
