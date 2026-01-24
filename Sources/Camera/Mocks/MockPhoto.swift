import Foundation
import CoreImage

// A mock implementation of the Photo protocol for testing purposes.
final class MockPhoto: PhotoData, Equatable {
    func buildImageForRatio(_ ratio: CaptureSessionAspectRatio) -> CIImage? {
        return nil
    }
    
    func getMetadata() -> [String : Any] {
        return [:]
    }
    
    static func == (lhs: MockPhoto, rhs: MockPhoto) -> Bool {
        return lhs.data == rhs.data
    }

    let data: Data?

    init(data: Data?) {
        self.data = data
    }

    func fileDataRepresentation() -> Data? {
        return data
    }
}
