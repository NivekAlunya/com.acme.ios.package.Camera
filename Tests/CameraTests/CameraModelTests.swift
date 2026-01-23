import Testing
import SwiftUI
import Foundation
@testable import Camera

@Suite("CameraModel tests with mock camera")
struct CameraModelTests {
    @Test("CameraModel updates preview when receiving preview stream")
    @MainActor
    func testPreviewUpdates() async throws {
        let ciImage = CIImage(color: .red).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [ciImage], photoImages: [])
        let model = CameraModel(camera: mock)
        await model.start()
        // Wait a bit for Task to process preview stream
        await Task.yield()
        #expect(model.preview != nil, "Preview should be updated after preview stream")
    }

    @Test("CameraModel handles empty preview stream")
    @MainActor
    func testEmptyPreviewStream() async throws {
        let mock = MockCamera(previewImages: [], photoImages: [])
        let model = CameraModel(camera: mock)
        await model.start()
        await Task.yield()
        #expect(model.preview == nil, "Preview should be nil if stream is empty")
    }

    @Test("CameraModel transitions to validating state after taking photo")
    @MainActor
    func testPhotoCapture() async throws {
        let ciImage = CIImage(color: .blue).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [], photoImages: [ciImage])
        let model = CameraModel(camera: mock)
        await model.start()
        await model.handleTakePhoto()
        #expect(model.state == .validating, "CameraModel should be in validating state after taking a photo")

        #expect(model.preview != nil, "Preview should be updated after taking a photo")
    }

    @Test("CameraModel switches camera position")
    @MainActor
    func testSwitchCameraPosition() async throws {
        let mock = MockCamera()
        let model = CameraModel(camera: mock)
        await model.start()
        let initialPosition = await model.position
        await model.handleSwitchPosition()
        let newPosition = await model.position

        #expect(initialPosition != newPosition, "Camera position should have changed")
    }

    @Test("CameraModel changes capture preset")
    @MainActor
    func testChangeCapturePreset() async throws {
        let mock = MockCamera()
        let model = CameraModel(camera: mock)
        await model.start()
        let initialPreset = await model.selectedPreset
        model.selectPreset(.hd1920x1080)
        await Task.yield()
        let newPreset = await model.selectedPreset
        #expect(initialPreset != newPreset, "Capture preset should have changed")
        #expect(newPreset == .hd1920x1080, "New preset should be hd1920x1080")
    }

    @Test("CameraModel changes flash mode")
    @MainActor
    func testChangeFlashMode() async throws {
        let mock = MockCamera()
        let model = CameraModel(camera: mock)
        await model.start()
        let initialFlashMode = await model.selectedFlashMode
        model.selectFlashMode(.on)
        await Task.yield()
        let newFlashMode = await model.selectedFlashMode
        #expect(initialFlashMode != newFlashMode, "Flash mode should have changed")
        #expect(newFlashMode == .on, "New flash mode should be on")
    }

    @Test("CameraModel changes video codec")
    @MainActor
    func testChangeVideoCodec() async throws {
        let mock = MockCamera()
        let model = CameraModel(camera: mock)
        await model.start()
        let initialCodec = await model.selectedFormat
        model.selectFormat(.hevc)
        await Task.yield()
        let newCodec = await model.selectedFormat
        #expect(initialCodec != newCodec, "Video codec should have changed")
        #expect(newCodec == .hevc, "New video codec should be hevc")
    }

    @Test("CameraModel accepts photo")
    @MainActor
    func testAcceptPhoto() async throws {
        let ciImage = CIImage(color: .green).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [], photoImages: [ciImage])
        let model = CameraModel(camera: mock)
        await model.start()
        await model.handleTakePhoto()

        let photo = await mock.photo
        #expect(photo != nil, "Photo should have been taken")

        await model.handleAcceptPhoto()

        #expect(model.state == .accepted((photo, await mock.config)), "CameraModel should be in accepted state")

    }

    @Test("CameraModel rejects photo")
    @MainActor
    func testRejectPhoto() async throws {
        let ciImage = CIImage(color: .yellow).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [], photoImages: [ciImage])
        let model = CameraModel(camera: mock)
        await model.start()
        model.handleTakePhoto()
        await Task.yield()
        await model.handleRejectPhoto()
        #expect(model.state == .previewing, "CameraModel should be in previewing state after rejecting a photo")

    }
}
