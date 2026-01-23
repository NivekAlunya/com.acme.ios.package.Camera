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
        let mock = MockCamera(previewImages: [ciImage, ciImage, ciImage], photoImages: [])

        let model = CameraModel(camera: mock)
        await model.start()
        // Wait a bit for Task to process preview stream
        try? await Task.sleep(nanoseconds: 100_000_000)
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
        // Wait for the photo capture loop to process and update state
        try? await Task.sleep(nanoseconds: 100_000_000)
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
        try? await Task.sleep(nanoseconds: 100_000_000)
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
        model.selectFlashMode(.auto) // Use .auto instead of .on
        try? await Task.sleep(nanoseconds: 100_000_000)
        let newFlashMode = await model.selectedFlashMode
        #expect(newFlashMode == .auto, "New flash mode should be auto")

    }

    @Test("CameraModel changes video codec")
    @MainActor
    func testChangeVideoCodec() async throws {
        let mock = MockCamera()
        let model = CameraModel(camera: mock)
        await model.start()
        model.selectFormat(.proRes422) // Use a different codec
        await Task.yield()
        let newCodec = await model.selectedFormat
        #expect(newCodec == .proRes422, "New video codec should be proRes422")
    }

    @Test("CameraModel switches aspect ratio")
    @MainActor
    func testSwitchAspectRatio() async throws {
        let mock = MockCamera()
        let model = CameraModel(camera: mock)
        await model.start()
        
        // Test cycling through aspect ratios
        let initialRatio = await model.ratio
        #expect(initialRatio == .defaultAspectRatio, "Initial ratio should be defaultAspectRatio")
        
        await model.handleSwitchRatio()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let ratio1 = await model.ratio
        #expect(ratio1 == .ratio_1_1, "After first switch, ratio should be 1:1")
        
        await model.handleSwitchRatio()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let ratio2 = await model.ratio
        #expect(ratio2 == .ratio_4_3, "After second switch, ratio should be 4:3")
        
        await model.handleSwitchRatio()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let ratio3 = await model.ratio
        #expect(ratio3 == .ratio_16_9, "After third switch, ratio should be 16:9")
        
        await model.handleSwitchRatio()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let ratio4 = await model.ratio
        #expect(ratio4 == .defaultAspectRatio, "After fourth switch, ratio should cycle back to default")
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
        await model.handleTakePhoto()

        await model.handleRejectPhoto()
        #expect(model.state == .previewing, "CameraModel should be in previewing state after rejecting a photo")

    }
}
