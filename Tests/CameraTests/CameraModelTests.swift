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

    @Test("CameraModel transitions to validating state after taking photo")
    func testPhotoCapture() async throws {
        let ciImage = CIImage(color: .blue).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [], photoImages: [ciImage])
        let model = await CameraModel(camera: mock)
        await model.start()
        model.handleTakePhoto()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(model.state == .validating, "CameraModel should be in validating state after taking a photo")
        #expect(model.preview != nil, "Preview should be updated after taking a photo")
    }

    @Test("CameraModel switches camera position")
    func testSwitchCameraPosition() async throws {
        let mock = MockCamera()
        let model = await CameraModel(camera: mock)
        await model.start()
        let initialPosition = await model.position
        model.handleSwitchPosition()
        try? await Task.sleep(nanoseconds: 100_000_000)
        let newPosition = await model.position
        #expect(initialPosition != newPosition, "Camera position should have changed")
    }

    @Test("CameraModel changes capture preset")
    func testChangeCapturePreset() async throws {
        let mock = MockCamera()
        let model = await CameraModel(camera: mock)
        await model.start()
        let initialPreset = await model.selectedPreset
        model.selectPreset(.hd1920x1080)
        try? await Task.sleep(nanoseconds: 100_000_000)
        let newPreset = await model.selectedPreset
        #expect(initialPreset != newPreset, "Capture preset should have changed")
        #expect(newPreset == .hd1920x1080, "New preset should be hd1920x1080")
    }

    @Test("CameraModel changes flash mode")
    func testChangeFlashMode() async throws {
        let mock = MockCamera()
        let model = await CameraModel(camera: mock)
        await model.start()
        let initialFlashMode = await model.selectedFlashMode
        model.selectFlashMode(.on)
        try? await Task.sleep(nanoseconds: 100_000_000)
        let newFlashMode = await model.selectedFlashMode
        #expect(initialFlashMode != newFlashMode, "Flash mode should have changed")
        #expect(newFlashMode == .on, "New flash mode should be on")
    }

    @Test("CameraModel changes video codec")
    func testChangeVideoCodec() async throws {
        let mock = MockCamera()
        let model = await CameraModel(camera: mock)
        await model.start()
        let initialCodec = await model.selectedFormat
        model.selectFormat(.hevc)
        try? await Task.sleep(nanoseconds: 100_000_000)
        let newCodec = await model.selectedFormat
        #expect(initialCodec != newCodec, "Video codec should have changed")
        #expect(newCodec == .hevc, "New video codec should be hevc")
    }

    @Test("CameraModel accepts photo")
    func testAcceptPhoto() async throws {
        let ciImage = CIImage(color: .green).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [], photoImages: [ciImage])
        let model = await CameraModel(camera: mock)
        await model.start()
        model.handleTakePhoto()
        try? await Task.sleep(nanoseconds: 100_000_000)
        model.handleAcceptPhoto()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(model.state == .accepted((await mock.photo, await mock.config)), "CameraModel should be in accepted state")
    }

    @Test("CameraModel rejects photo")
    func testRejectPhoto() async throws {
        let ciImage = CIImage(color: .yellow).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [], photoImages: [ciImage])
        let model = await CameraModel(camera: mock)
        await model.start()
        model.handleTakePhoto()
        try? await Task.sleep(nanoseconds: 100_000_000)
        model.handleRejectPhoto()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(model.state == .previewing, "CameraModel should be in previewing state after rejecting a photo")
    }
}
