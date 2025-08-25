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
    typealias Capture = (photo: AVCapturePhoto?, config: CameraConfiguration?)
    // MARK: - State

    enum State: Equatable {
        static func == (lhs: CameraModel.State, rhs: CameraModel.State) -> Bool {
            switch (lhs, rhs) {
            case (.accepted(let a), .accepted(let b)) where a.photo == b.photo: return true
               case (.previewing, .previewing)
                , (.processing, .processing)
                , (.validating, .validating): return true
               default: return false
            }
        }
        
        case previewing, processing, validating
        case accepted(Capture)
    }
    
    @Published var state = State.previewing
    @Published var error: CameraError?

    // MARK: - Published Properties

    @Published var preview: Image?
    @Published var capture: Capture?
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
        print("start")
        await self.camera.createStreams()

        previewTask = Task { await handleCameraPreviews() }
        photoTask = Task { await handlePhotoCapture() }
        do {
            try await camera.start()
            self.position = await camera.config.position
            await loadSettings()
            state = .previewing
        } catch (let error as CameraError) {
            self.error = error
        } catch {
            
        }
    }
    
    func stop() async {
        previewTask?.cancel()
        photoTask?.cancel()
        await camera.stop()
    }

    func end() async {
        await stop()
        await camera.end()
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
            } catch (let error as CameraError) {
                self.error = error
            } catch {
                
            }
        }
    }

    func handleAcceptPhoto() {
        Task {
            await stop()
            await camera.end()
            state = .accepted((photo: await camera.photo, config: await camera.config))
        }
    }

    func handleRejectPhoto() {
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
            } catch (let error as CameraError) {
                self.error = error
            } catch {
                
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

        if let currentDevice = await camera.config.deviceInput?.device {
            selectedDevice = currentDevice
        } else if let firstDevice = devices.first {
            selectedDevice = firstDevice
        }

        devices = await camera.config.listCaptureDevice
        formats = await camera.config.listSupportedFormat

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
        guard let image = image, let cgImage = await image.toCGImage() else {
            self.preview = nil
            return
        }
        self.preview = Image(decorative: cgImage, scale: 1, orientation: .up)
    }

    private func setPhoto(photo: CIImage) async {
        state = .validating
//        self.preview = Image(avCapturePhoto: photo)
        await camera.stop()
    }
}
