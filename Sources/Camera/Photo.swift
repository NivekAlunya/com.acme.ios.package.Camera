import AVFoundation

public protocol Photo {
    func fileDataRepresentation() -> Data?
}

extension AVCapturePhoto: Photo {}
