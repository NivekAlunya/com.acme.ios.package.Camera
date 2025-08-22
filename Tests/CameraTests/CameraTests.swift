import XCTest
@testable import Camera
import AVFoundation

class CameraTests: XCTestCase {

    func testCameraInitialization() {
        let camera = Camera()
        XCTAssertNotNil(camera, "Camera should be initialized")
    }

    func testStartCamera() async throws {
        let camera = Camera()
        try await camera.start()
        XCTAssertTrue(camera.config.session.isRunning, "Camera session should be running after start")
        await camera.stop()
    }

    func testStopCamera() async throws {
        let camera = Camera()
        try await camera.start()
        await camera.stop()
        XCTAssertFalse(camera.config.session.isRunning, "Camera session should not be running after stop")
    }

    func testSwitchCamera() async throws {
        let camera = Camera()
        try await camera.start()

        let initialPosition = camera.config.position
        try await camera.swicthPosition()
        let newPosition = camera.config.position

        XCTAssertNotEqual(initialPosition, newPosition, "Camera position should change after switching")

        await camera.stop()
    }

    func testTakePhoto() async throws {
        let camera = Camera()
        try await camera.start()

        let expectation = XCTestExpectation(description: "Photo captured")

        let photoStreamTask = Task {
            for await _ in await camera.stream.photoStream {
                expectation.fulfill()
                break
            }
        }

        await camera.takePhoto()

        await fulfillment(of: [expectation], timeout: 5.0)

        photoStreamTask.cancel()
        await camera.stop()
    }
}
