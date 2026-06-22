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
import os

private let logger = Logger(subsystem: "com.acme.ios.package.Camera", category: "CameraModel")

/// The `CameraModel` is an `ObservableObject` that acts as the primary view model for the camera UI.
/// It manages the camera's state, handles user interactions, and provides data streams for the view to consume.
/// This class is marked as `@MainActor` to ensure that all UI updates are performed on the main thread.
@Observable
@MainActor
public class CameraModel {
    /// A type alias for the data captured when a photo is taken.
    typealias Capture = (photo: PhotoCapture?, config: CameraConfiguration?)

    /// Whether the currently selected device is the ultra-wide camera,
    /// which uses a 0.5× equivalent scale instead of 1×.
    var usesUltraWideEquivalentScale: Bool {
        selectedDevice?.deviceType == .builtInUltraWideCamera
    }

    /// The zoom factor expressed in user-facing equivalent scale (0.5× for ultra-wide, 1× base otherwise).
    var displayZoom: Double {
        usesUltraWideEquivalentScale ? zoom / 2.0 : zoom
    }

    /// The zoom range expressed in user-facing equivalent scale.
    var displayZoomRange: ClosedRange<Double> {
        usesUltraWideEquivalentScale
            ? (zoomRange.lowerBound / 2.0)...(zoomRange.upperBound / 2.0)
            : zoomRange
    }

    // MARK: - State Management

    /// Represents the different states of the camera UI.
    enum State: Equatable {
        /// Compares two `State` instances for equality.
        static func == (lhs: CameraModel.State, rhs: CameraModel.State) -> Bool {
            switch (lhs, rhs) {
            case (.accepted(let a), .accepted(let b)):
                // We only compare the photo data here. The configuration contains references
                // to AVFoundation objects that are not easily comparable in a test environment.
                return String(describing: a.photo?.metadata) == String(describing: b.photo?.metadata)
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
    var state = State.loading
    /// The last error that occurred.
    var error: CameraError?
    /// The current camera preview image.
    var preview: Image?
    /// The current preview mode.
    var previewMode: CameraPreviewMode = .streaming
    /// The underlying `AVCaptureSession`.
    var session: AVCaptureSession?
    /// The captured photo and its configuration.
    var capture: Capture?
    /// The current camera position (front or back).
    var position = AVCaptureDevice.Position.back
    /// The list of available session presets.
    var presets = [CaptureSessionPreset]()
    /// The list of available camera devices.
    var devices = [AVCaptureDevice]()
    /// The list of supported video formats.
    var formats = [VideoCodecType]()
    /// The list of available flash modes.
    var flashModes = [CameraFlashMode]()
    /// The currently selected session preset.
    var selectedPreset = CaptureSessionPreset.photo
    /// The currently selected camera device.
    var selectedDevice: AVCaptureDevice?
    /// The currently selected video format.
    var selectedFormat = VideoCodecType.hevc
    /// The currently selected flash mode.
    var selectedFlashMode = CameraFlashMode.unavailable
    /// The available zoom range for the current device.
    var zoomRange = 1.0...1.0
    /// The current zoom factor.
    var zoom: Double = 1.0
    /// The zoom value captured at the start of the current pinch gesture.
    var pinchStartZoom: Double?
    /// The aspect ratio of the camera preview.
    var ratio: CaptureSessionAspectRatio = .defaultAspectRatio

    // MARK: - Private Properties
    /// The underlying camera actor that handles capture operations.
    private let camera: any CameraProtocol
    /// The task that listens for preview frames from the camera.
    private var previewTask: Task<Void, Never>?
    /// The task that listens for captured photos from the camera.
    private var photoTask: Task<Void, Never>?
    /// The task for the most recent in-flight settings selection (preset, device, format, flash, zoom).
    /// Cancelled before starting a new one to avoid out-of-order execution.
    private var selectionTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initializes the camera model.
    /// - Parameter camera: The camera protocol instance to use. Defaults to a new `Camera` actor instance.
    init(camera: any CameraProtocol = Camera()) {
        self.camera = camera
    }

    // MARK: - Public Methods

    
    /// Starts the camera, begins listening for previews and photos, and loads initial settings.
    func start() async {
        state = .loading
        do {
            let initialConfig = await camera.config
            self.ratio = initialConfig.ratio
            self.previewMode = initialConfig.previewMode
            self.session = await camera.session

            // Start the camera first — if it throws (e.g. unauthorized) we must not
            // have already launched tasks that wait on streams which will never finish.
            try await camera.start()

            // Camera is running: now it's safe to launch the stream listeners.
            selectPreviewMode(self.previewMode)
            photoTask = Task { await listenPhotoCapture() }
            await loadSettings()
        } catch let error as CameraError {
            if error == .cameraUnauthorized {
                state = .unauthorized
            }
            self.error = error
        } catch {
            // Handle other potential errors if necessary
        }
    }

    func selectFocusPoint(_ point: CGPoint) {
        Task {
            do {
                try await camera.focus(on: point)
            } catch (let error as CameraError) {
                self.error = error
            } catch {
                // Handle other potential errors
            }
        }
    }

    func stop() async {
        await camera.end()
    }

    // MARK: - User Actions

    /// Handles the user tapping the "take photo" button.
    func handleTakePhoto() async {
        state = .processing
        await camera.takePhoto()
    }

    func handleSwitchRatio() async {
        let newRatio: CaptureSessionAspectRatio
        switch ratio {
        case .ratio_1_1:
            newRatio = .ratio_4_3
        case .ratio_4_3:
            newRatio = .ratio_16_9
        case .ratio_16_9:
            newRatio = .defaultAspectRatio
        default:
            newRatio = .ratio_1_1
        }
        ratio = newRatio
        await camera.changeRatio(newRatio)
    }

    
    /// Handles the user exiting the camera view.
    func handleExit() async {
        await exit()
    }

    
    /// Handles the user switching the camera position (front/back).
    func handleSwitchPosition() async {
        do {
            try await camera.changePosition()
            // loadSettings() reads position from a single config snapshot — no extra hop needed.
            await loadSettings()
        } catch let error as CameraError {
            self.error = error
        } catch {
            // Handle other potential errors
        }
    }


    /// Handles the user accepting the captured photo.
    func handleAcceptPhoto() async {
        await acceptPhoto()
    }
    
    /// Handles the user rejecting the captured photo.
    func handleRejectPhoto() async {
        await resetPhoto()
    }

    
    // MARK: - Settings Selection

    /// Selects a new preview mode.
    func selectPreviewMode(_ previewMode: CameraPreviewMode) {
        logger.debug("Selecting preview mode \(previewMode)")
        self.previewMode = previewMode
        previewTask?.cancel()

        if previewMode == .streaming {
            previewTask = Task {
                await camera.stream.resume()
                await listenCameraPreviews()
            }
        }

        state = .previewing

        Task {
            await camera.changePreviewMode(previewMode)
        }
    }

    /// Selects a new session preset.
    /// Cancels any in-flight selection task before dispatching the new one.
    func selectPreset(_ preset: CaptureSessionPreset) {
        selectionTask?.cancel()
        selectionTask = Task {
            selectedPreset = preset
            await camera.changePreset(preset: preset)
        }
    }

    /// Selects a new camera device.
    /// Cancels any in-flight selection task before dispatching the new one.
    func selectDevice(_ device: AVCaptureDevice) {
        selectionTask?.cancel()
        selectionTask = Task {
            selectedDevice = device
            do {
                try await camera.changeCamera(device: device)
                await loadSettings()
            } catch let error as CameraError {
                self.error = error
            } catch {
                // Handle other potential errors
            }
        }
    }

    /// Selects a new video format.
    /// Cancels any in-flight selection task before dispatching the new one.
    func selectFormat(_ format: VideoCodecType) {
        selectionTask?.cancel()
        selectionTask = Task {
            selectedFormat = format
            await camera.changeCodec(format)
        }
    }

    /// Selects a new flash mode.
    /// Cancels any in-flight selection task before dispatching the new one.
    func selectFlashMode(_ flashMode: CameraFlashMode) {
        selectionTask?.cancel()
        selectionTask = Task {
            await camera.changeFlashMode(flashMode)
            // Read back from a single config snapshot, not a second actor hop.
            selectedFlashMode = await camera.config.flashMode
        }
    }

    /// Selects a new zoom factor.
    /// Cancels any in-flight selection task before dispatching the new one.
    func selectZoom(_ zoom: Double) {
        selectionTask?.cancel()
        selectionTask = Task {
            do {
                try await camera.changeZoom(zoom)
                // Read back the clamped value actually applied by the actor.
                self.zoom = Double(await camera.config.zoom)
            } catch let error as CameraError {
                self.error = error
            } catch {
                // Handle other potential errors
            }
        }
    }

    /// Updates zoom from a pinch gesture scale.
    func selectZoom(pinchScale: Double) {
        if pinchStartZoom == nil {
            pinchStartZoom = zoom
        }

        guard let startZoom = pinchStartZoom else {
            return
        }

        let targetZoom = startZoom * pinchScale
        let clampedZoom = min(max(targetZoom, zoomRange.lowerBound), zoomRange.upperBound)
        selectZoom(clampedZoom)
    }

    /// Ends the current pinch zoom interaction.
    func endPinchZoom() {
        pinchStartZoom = nil
    }
    
    // MARK: - Private Methods

    /// Loads the initial camera settings and updates the published properties.
    private func loadSettings() async {
        // Grab the entire configuration in one actor hop to avoid reading
        // from a mixed state when concurrent camera changes are in flight.
        let config = await camera.config

        if let currentDevice = config.deviceInput?.device {
            selectedDevice = currentDevice
        } else if let firstDevice = devices.first {
            selectedDevice = firstDevice
        }
        self.position = config.position

        devices = config.listCaptureDevice
        formats = config.listSupportedFormat
        flashModes = config.listFlashMode
        presets = config.listPreset

        selectedFlashMode = config.flashMode
        selectedPreset = config.preset
        selectedFormat = config.videoCodecType
        zoom = Double(config.zoom)
        zoomRange = config.zoomRange
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
    private func exit() async {
        selectionTask?.cancel()
        previewTask?.cancel()
        photoTask?.cancel()
        capture = nil
        await camera.end()
    }

    
    /// Sets the state to `accepted` with the captured photo and exits.
    private func acceptPhoto() async {
        let (photo, config) = (await camera.photo, await camera.config)
        state = .accepted((photo: photo, config: config))
        await exit()
    }

    
    /// Resumes the camera preview after a photo was rejected.
    public func resetPhoto() async {
        state = .previewing
        await camera.resume()
    }

}
