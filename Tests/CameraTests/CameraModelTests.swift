import Testing
import SwiftUI
import Foundation
@testable import Camera

@Suite("CameraModel tests with mock camera")
struct CameraModelTests {
    @Test("CameraModel updates preview when receiving preview stream")
    func testPreviewUpdates() async throws {
        let ciImage = CIImage(color: .red).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [ciImage], photoImages: [])
        let model = await CameraModel(camera: mock)
        await model.start()
        // Wait a bit for Task to process preview stream
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(model.preview != nil, "Preview should be updated after preview stream")
    }

    @Test("CameraModel handles empty preview stream")
    func testEmptyPreviewStream() async throws {
        let mock = MockCamera(previewImages: [], photoImages: [])
        let model = await CameraModel(camera: mock)
        await model.start()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(model.preview == nil, "Preview should be nil if stream is empty")
    }
}
