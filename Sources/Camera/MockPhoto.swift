import Foundation

// A mock implementation of the Photo protocol for testing purposes.
final class MockPhoto: PhotoData, Equatable {
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
