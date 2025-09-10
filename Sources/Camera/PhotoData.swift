import AVFoundation

public protocol PhotoData: Sendable {
    func fileDataRepresentation() -> Data?
}

extension AVCapturePhoto: PhotoData {}
