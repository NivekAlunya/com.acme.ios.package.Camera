//
//  CameraModel.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import Foundation
import UIKit
import SwiftUI
@preconcurrency import AVFoundation

/// The `CameraModel` is an `ObservableObject` that acts as the primary view model for the camera UI.
/// It manages the camera's state, handles user interactions, and provides data streams for the view to consume.
/// This class is marked as `@MainActor` to ensure that all UI updates are performed on the main thread.
@MainActor
public class CameraModel: ObservableObject {
    /// A type alias for the data captured when a photo is taken.
    typealias Capture = (photo: (any PhotoData)?, config: CameraConfiguration?)

    // MARK: - State Management

    /// Represents the different states of the camera UI.
    enum State: Equatable {
        /// Compares two `State` instances for equality.
        static func == (lhs: CameraModel.State, rhs: CameraModel.State) -> Bool {
            switch (lhs, rhs) {
            case (.accepted(let a), .accepted(let b)):
                // We only compare the photo data here. The configuration contains references
                // to AVFoundation objects that are not easily comparable in a test environment.
                return a.photo?.fileDataRepresentation() == b.photo?.fileDataRepresentation()
            case (.loading, .loading),
                 (.previewing, .previewing),
                 (.processing, .processing),
                 (.validating, .validating),
                 (.unauthorized, .unauthorized):
                return true
            default:
                return false
            }
        }
        
        /// The camera is displaying the live preview.
        case previewing
        /// The camera is in the process of capturing a photo.
        case processing
        /// The captured photo is being displayed for user validation (accept or reject).
        case validating
        /// The user has not granted camera permissions.
        case unauthorized
        /// The camera is being initialized.
        case loading
        /// The user has accepted the captured photo.
        case accepted(Capture)
    }
    
    // MARK: - Published Properties

    /// The current state of the camera UI.
    @Published var state = State.loading
    /// The last error that occurred.
    @Published var error: CameraError?
    /// The current camera preview image.
    @Published var preview: Image?
    /// The captured photo and its configuration.
    @Published var capture: Capture?
    /// The current camera position (front or back).
    @Published var position = AVCaptureDevice.Position.back
    /// The list of available session presets.
    @Published var presets = [CaptureSessionPreset]()
    /// The list of available camera devices.
    @Published var devices = [AVCaptureDevice]()
    /// The list of supported video formats.
    @Published var formats = [VideoCodecType]()
    /// The list of available flash modes.
    @Published var flashModes = [CameraFlashMode]()
    /// The currently selected session preset.
    @Published var selectedPreset = CaptureSessionPreset.photo
    /// The currently selected camera device.
    @Published var selectedDevice: AVCaptureDevice?
    /// The currently selected video format.
    @Published var selectedFormat = VideoCodecType.hevc
    /// The currently selected flash mode.
    @Published var selectedFlashMode = CameraFlashMode.unavailable
    /// The available zoom range for the current device.
    @Published var zoomRange = 1.0...1.0
    /// The current zoom factor.
    @Published var zoom: Double = 1.0

    // MARK: - Private Properties

    /// The underlying camera actor that handles capture operations.
    private let camera: any CameraProtocol
    /// The task that listens for preview frames from the camera.
    private var previewTask: Task<Void, Never>?
    /// The task that listens for captured photos from the camera.
    private var photoTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initializes the camera model.
    /// - Parameter camera: The camera protocol instance to use. Defaults to the shared `Camera` actor.
    init(camera: any CameraProtocol = Camera.shared) {
        self.camera = camera
    }
    
    deinit {
        previewTask?.cancel()
        photoTask?.cancel()
    }

    // MARK: - Public Methods

    /// Starts the camera, begins listening for previews and photos, and loads initial settings.
    func start() async {
        do {
            try await camera.start()
            previewTask = Task { await listenCameraPreviews() }
            photoTask = Task { await listenPhotoCapture() }
            await loadSettings()
        } catch (let error as CameraError) {
            if error == .cameraUnauthorized {
                state = .unauthorized
            }
            self.error = error
        } catch {
            // Handle other potential errors if necessary
        }
    }

    // MARK: - User Actions

    /// Handles the user tapping the "take photo" button.
    func handleTakePhoto() {
        Task {
            state = .processing
            await camera.takePhoto()
        }
    }

    /// Handles the user exiting the camera view.
    func handleExit() {
        exit()
    }
    
    /// Handles the user switching the camera position (front/back).
    func handleSwitchPosition() {
        Task {
            do {
                try await camera.changePosition()
                await loadSettings()
                self.position = await camera.config.position
            } catch (let error as CameraError) {
                self.error = error
            } catch {
                // Handle other potential errors
            }
        }
    }

    /// Handles the user accepting the captured photo.
    func handleAcceptPhoto() {
        acceptPhoto()
    }
    
    /// Handles the user rejecting the captured photo.
    func handleRejectPhoto() {
        rejectPhoto()
    }
    
    // MARK: - Settings Selection

    /// Selects a new session preset.
    func selectPreset(_ preset: CaptureSessionPreset) {
        Task {
            selectedPreset = preset
            await camera.changePreset(preset: preset)
        }
    }

    /// Selects a new camera device.
    func selectDevice(_ device: AVCaptureDevice) {
        Task {
            selectedDevice = device
            do {
                try await camera.changeCamera(device: device)
                await loadSettings()
            } catch (let error as CameraError) {
                self.error = error
            } catch {
                // Handle other potential errors
            }
        }
    }

    /// Selects a new video format.
    func selectFormat(_ format: VideoCodecType) {
        Task {
            selectedFormat = format
            await camera.changeCodec(format)
        }
    }

    /// Selects a new flash mode.
    func selectFlashMode(_ flashMode: CameraFlashMode) {
        Task {
            await camera.changeFlashMode(flashMode)
            selectedFlashMode = await camera.config.flashMode
        }
    }

    /// Selects a new zoom factor.
    func selectZoom(_ zoom: Double) {
        Task {
            do {
                try await camera.changeZoom(zoom)
                self.zoom = await Double(camera.config.zoom)
            } catch (let error as CameraError) {
                self.error = error
            } catch {
                // Handle other potential errors
            }
        }
    }
    
    // MARK: - Private Methods

    /// Loads the initial camera settings and updates the published properties.
    private func loadSettings() async {
        if let currentDevice = await camera.config.deviceInput?.device {
            selectedDevice = currentDevice
        } else if let firstDevice = devices.first {
            selectedDevice = firstDevice
        }
        self.position = await camera.config.position
        
        devices = await camera.config.listCaptureDevice
        formats = await camera.config.listSupportedFormat
        flashModes = await camera.config.listFlashMode
        presets = await camera.config.listPreset
        
        selectedFlashMode = await camera.config.flashMode
        selectedPreset = await camera.config.preset
        selectedFormat = await camera.config.videoCodecType
        zoom = await Double(camera.config.zoom)
        zoomRange = await camera.config.zoomRange
    }
    
    /// Listens for preview frames from the camera stream and updates the `preview` property.
    private func listenCameraPreviews() async {
        for await image in await camera.stream.previewStream {
            if state == .loading {
                state = .previewing
            }
            await setPreview(image: image)
        }
    }

    /// Listens for captured photos from the camera stream and updates the state.
    private func listenPhotoCapture() async {
        for await photo in await camera.stream.photoStream {
            await setPhoto(photo: photo)
        }
    }

    /// Sets the preview image from a `CIImage`.
    private func setPreview(image: CIImage?) async {
        guard let image = image, let cgImage = await image.toCGImage() else {
            self.preview = nil
            return
        }
        self.preview = Image(decorative: cgImage, scale: 1)
    }

    /// Sets the state to `validating` and displays the captured photo as a preview.
    private func setPhoto(photo: CIImage) async {
        guard let cgImage = await photo.toCGImage() else {
            self.preview = nil
            return
        }
        state = .validating
        self.preview = Image(decorative: cgImage, scale: 1)
        await camera.pause()
    }
    
    /// Cleans up resources and ends the camera session.
    private func exit() {
        previewTask?.cancel()
        photoTask?.cancel()
        capture = nil
        Task {
            await camera.end()
        }
    }
    
    /// Sets the state to `accepted` with the captured photo and exits.
    private func acceptPhoto() {
        Task {
            let (photo, config) = (await camera.photo, await camera.config)
            state = .accepted((photo: photo, config: config))
            exit()
        }
    }

    /// Resumes the camera preview after a photo was rejected.
    private func rejectPhoto() {
        Task {
            state = .previewing
            await camera.resume()
        }
    }
}
