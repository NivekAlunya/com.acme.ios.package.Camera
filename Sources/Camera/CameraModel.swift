//
//  File.swift
//  camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//

import Foundation
import SwiftUI
import AVFoundation

/// CameraModel manages camera configuration, preview streaming, and photo capture for SwiftUI views.
/// - Usage: Call `start()` on appear. Use `.preview` to display the current camera image.
@MainActor
public class CameraModel: ObservableObject {
    
    enum State {
        case previewing, processing, validating
    }
    
    /// Camera implementation conforming to ICamera (default: Camera)
    let camera : any CameraProtocol
    /// Most recent camera preview frame as a SwiftUI Image
    @Published var preview: Image?
    /// Photo camera returned by the component
    @Published var capture: AVCapturePhoto?
    /// Indicates if a photo has been captured and is awaiting confirmation.
    @Published var state = State.previewing
    @Published var position : AVCaptureDevice.Position = .back
    @Published var error: Error?

    @Published var presetSelected: CaptureSessionPreset
    @Published var deviceSelected: AVCaptureDevice?
    @Published var formatSelected: VideoCodecType

    @Published var presets: [CaptureSessionPreset] = []
    @Published var devices: [AVCaptureDevice] = []
    @Published var formats: [VideoCodecType] = []

    /// Photo camera returned by the component
    private var photo: AVCapturePhoto?
    /// Task for streaming preview frames asynchronously
    private var previewTask: Task<Void, Never>?
    /// Task for asynchronously handling photo capture events
    private var photoTask: Task<Void, Never>?

    /// Initialize with any ICamera implementation (default: Camera)
    init(camera: any CameraProtocol = Camera()) {
        self.camera = camera
        self.presetSelected = .photo
        self.deviceSelected = nil
        self.formatSelected = .hevc
    }
    
    func start() async {
        previewTask = Task { await handleCameraPreviews() }
        photoTask = Task { await handlePhotoCapture() }

        do {
            try await camera.start()
            self.position = await camera.config.position
            state = .previewing
            await loadSettings()
        } catch {
            self.error = error
        }
    }
    
    func loadSettings() async {
        self.presets = await camera.config.preset.allCases
        self.devices = await camera.config.listCaptureDevice
        self.formats = await camera.config.listSupportedFormat

        self.presetSelected = await camera.config.preset
        self.deviceSelected = await camera.config.deviceInput?.device
        self.formatSelected = await camera.config.videoCodecType
    }

    /// Asynchronously handle new preview frames from the camera.
    private func handleCameraPreviews() async {
        for await image in await camera.stream.previewStream {
            await setPreview(image: image)
        }
    }

    /// Asynchronously handle new captured photos from the camera.
    private func handlePhotoCapture() async {
        for await photo in await camera.stream.photoStream {
            await setPhoto(photo: photo)
        }
    }

    /// Take a photo when called (bound to UI button press).
    func handleButtonPhoto() {
        Task {
            state = .processing
            await camera.takePhoto()
        }
    }

    func handleSwitchFlash() {
        Task {
            await camera.switchFlash(.auto)
        }
    }

    
    func handleButtonExit() {
        Task {
            await stop()
            capture = nil
        }
    }
    
    func handleSwitchPosition() {
        Task {
            do {
                try await camera.swicthPosition()
                self.position = await camera.config.position
                await loadSettings()
            } catch {
                self.error = error
            }
        }
    }

    func handleButtonSelectPhoto() {
        capture = photo
    }
    
    func handleRejectPhoto() {
        photo = nil
        Task {
            state = .previewing
            await camera.resume()
        }
    }
    
    func selectPreset(_ preset: CaptureSessionPreset) {
        Task {
            presetSelected = preset
            await camera.changePreset(preset: preset)
        }
    }

    func selectDevice(_ device: AVCaptureDevice) {
        Task {
            deviceSelected = device
            do {
                try await camera.changeCamera(device: device)
            } catch {
                self.error = error
            }
        }
    }

    func selectFormat(_ format: VideoCodecType) {
        Task {
            formatSelected = format
            await camera.changeCodec(format)
        }
    }

    deinit {
        previewTask?.cancel()
        photoTask?.cancel()
    }
    
    /// Update the preview property with new camera image data.
    func setPreview(image: CIImage?) async {
        guard let image = image, let cgImage = image.toCGImage() else {
            self.preview = nil
            return
        }
        self.preview = Image(decorative: cgImage, scale: 1, orientation: .up)
    }

    /// Update preview with captured photo and stop the camera.
    func setPhoto(photo: AVCapturePhoto) async {
        self.photo = photo
        state = .validating
        self.preview = Image(avCapturePhoto: photo)
        await camera.stop()
    }
    
    /// Cancel preview/photo tasks and stop the camera immediately.
    // Note: Cannot reliably await stop() in deinit; call stop() manually if needed before deallocation.
    func stop() async {
        previewTask?.cancel()
        photoTask?.cancel()
        await camera.stop()
    }
        
}
