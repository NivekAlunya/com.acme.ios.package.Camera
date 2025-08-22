//
//  File.swift
//  camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//

import Foundation
import UIKit
import SwiftUI
@preconcurrency import AVFoundation

/// CameraModel manages camera state, preview streaming, and photo capture for SwiftUI views.
@MainActor
public class CameraModel: ObservableObject {
    
    // MARK: - State

    enum State {
        case previewing, processing, validating
    }
    
    @Published var state = State.previewing
    @Published var error: Error?

    // MARK: - Published Properties

    @Published var preview: Image?
    @Published var capture: AVCapturePhoto?
    @Published var position: AVCaptureDevice.Position = .back

    // MARK: - Settings Properties

    @Published var presets = CaptureSessionPreset.allCases
    @Published var devices: [AVCaptureDevice] = []
    @Published var formats: [VideoCodecType] = []

    @Published var selectedPreset: CaptureSessionPreset = .photo
    @Published var selectedDevice: AVCaptureDevice?
    @Published var selectedFormat: VideoCodecType = .hevc

    // MARK: - Private Properties

    private let camera : any CameraProtocol
    private var photo: AVCapturePhoto?
    private var previewTask: Task<Void, Never>?
    private var photoTask: Task<Void, Never>?

    // MARK: - Initialization

    init(camera: any CameraProtocol = Camera()) {
        self.camera = camera
    }
    
    deinit {
        previewTask?.cancel()
        photoTask?.cancel()
    }

    // MARK: - Public Methods

    func start() async {
        previewTask = Task { await handleCameraPreviews() }
        photoTask = Task { await handlePhotoCapture() }

        do {
            try await camera.start()
            await loadSettings()
            self.position = await camera.config.position
            state = .previewing
        } catch {
            self.error = error
        }
    }
    
    func stop() async {
        previewTask?.cancel()
        photoTask?.cancel()
        await camera.stop()
    }

    // MARK: - User Actions

    func handleTakePhoto() {
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
    
    func handleExit() {
        Task {
            await stop()
            capture = nil
        }
    }
    
    func handleSwitchPosition() {
        Task {
            do {
                try await camera.swicthPosition()
                await loadSettings()
                self.position = await camera.config.position
            } catch {
                self.error = error
            }
        }
    }

    func handleAcceptPhoto() {
        capture = photo
    }

    func handleRejectPhoto() {
        photo = nil
        Task {
            state = .previewing
            await camera.resume()
        }
    }

    // MARK: - Settings Selection

    func selectPreset(_ preset: CaptureSessionPreset) {
        Task {
            selectedPreset = preset
            await camera.changePreset(preset: preset)
        }
    }

    func selectDevice(_ device: AVCaptureDevice) {
        Task {
            selectedDevice = device
            do {
                try await camera.changeCamera(device: device)
            } catch {
                self.error = error
            }
        }
    }

    func selectFormat(_ format: VideoCodecType) {
        Task {
            selectedFormat = format
            await camera.changeCodec(format)
        }
    }

    // MARK: - Private Methods

    private func loadSettings() async {
        devices = await camera.config.listCaptureDevice
        formats = await camera.config.listSupportedFormat

        if let currentDevice = await camera.config.deviceInput?.device {
            selectedDevice = currentDevice
        } else if let firstDevice = devices.first {
            selectedDevice = firstDevice
        }

        selectedPreset = await camera.config.preset
        selectedFormat = await camera.config.videoCodecType
    }
    
    private func handleCameraPreviews() async {
        for await image in await camera.stream.previewStream {
            await setPreview(image: image)
        }
    }

    private func handlePhotoCapture() async {
        for await photo in await camera.stream.photoStream {
            await setPhoto(photo: photo)
        }
    }

    private func setPreview(image: CIImage?) async {
        guard let image = image, let cgImage = image.toCGImage() else {
            self.preview = nil
            return
        }
        self.preview = Image(decorative: cgImage, scale: 1, orientation: .up)
    }

    private func setPhoto(photo: AVCapturePhoto) async {
        self.photo = photo
        state = .validating
        self.preview = Image(avCapturePhoto: photo)
        await camera.stop()
    }
}

extension CIImage {
    func toCGImage() -> CGImage? {
        let context = CIContext(options: nil)
        return context.createCGImage(self, from: self.extent)
    }
}

extension Image {
    init?(avCapturePhoto: AVCapturePhoto) {
        guard let cgImage = avCapturePhoto.cgImageRepresentation(),
              let imageOrientation = cgImage.orientation else {
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        self.init(uiImage: uiImage)
    }
}

extension CGImage {
    var orientation: UIImage.Orientation? {
        guard let properties = self.properties,
              let orientationValue = properties[kCGImagePropertyOrientation as String] as? UInt32 else {
            return nil
        }
        return UIImage.Orientation(rawValue: Int(orientationValue))
    }
}
