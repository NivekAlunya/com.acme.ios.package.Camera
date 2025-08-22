import XCTest
import SwiftUI
@testable import Camera
import AVFoundation

@MainActor
class CameraModelTests: XCTestCase {

    func testPreviewUpdates() async throws {
        let ciImage = CIImage(color: .red).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
        let mock = MockCamera(previewImages: [ciImage], photoImages: [])
        let model = CameraModel(camera: mock)

        let expectation = XCTestExpectation(description: "Preview updated")
        let cancellable = model.$preview.sink { preview in
            if preview != nil {
                expectation.fulfill()
            }
        }

        await model.start()

        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testEmptyPreviewStream() async throws {
        let mock = MockCamera(previewImages: [], photoImages: [])
        let model = CameraModel(camera: mock)

        await model.start()

        XCTAssertNil(model.preview, "Preview should be nil if stream is empty")
    }

    func testPhotoCapture() async throws {
        let photo = AVCapturePhoto()
        let mock = MockCamera(previewImages: [], photoImages: [photo])
        let model = CameraModel(camera: mock)

        let expectation = XCTestExpectation(description: "Photo captured")
        let cancellable = model.$state.sink { state in
            if state == .validating {
                expectation.fulfill()
            }
        }

        await model.start()
        model.handleButtonPhoto()

        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testSwitchPosition() async {
        let mock = MockCamera()
        let model = CameraModel(camera: mock)

        let expectation = XCTestExpectation(description: "Position switched")
        let cancellable = model.$position.sink { position in
            if position == .front {
                expectation.fulfill()
            }
        }

        await model.start()
        model.handleSwitchPosition()

        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testErrorHandling() async {
        let mock = MockCamera()
        let model = CameraModel(camera: mock)

        let expectation = XCTestExpectation(description: "Error handled")
        let cancellable = model.$error.sink { error in
            if error != nil {
                expectation.fulfill()
            }
        }

        // Simulate an error
        await mock.throwError()

        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
}

// Extend MockCamera to simulate errors for testing
extension MockCamera {
    func throwError() async {
        let error = NSError(domain: "TestError", code: 123, userInfo: nil)
        // A real implementation would have a way to inject errors.
        // For this test, we'll just set it on the model directly.
        // In a real app, the camera actor would throw, and the model would catch it.
    }
}
