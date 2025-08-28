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

/// CameraModel manages camera state, preview streaming, and photo capture for SwiftUI views.
@MainActor
public class CameraModel: ObservableObject {
    typealias Capture = (photo: AVCapturePhoto?, config: CameraConfiguration?)
    // MARK: - State

    enum State: Equatable {
        static func == (lhs: CameraModel.State, rhs: CameraModel.State) -> Bool {
            switch (lhs, rhs) {
            case (.accepted(let a), .accepted(let b)):
                return a.photo == b.photo && a.config == b.config
            case (.previewing, .previewing),
                 (.processing, .processing),
                 (.validating, .validating),
                 (.unauthorized, .unauthorized):
                return true
            default:
                return false
            }
        }
        
        case previewing, processing, validating, unauthorized
        case accepted(Capture)
    }
    
    // MARK: - Published Properties
    @Published var state = State.previewing
    @Published var error: CameraError?
    @Published var preview: Image?
    @Published var capture: Capture?
    @Published var position = AVCaptureDevice.Position.back
    @Published var presets = [CaptureSessionPreset]()
    @Published var devices = [AVCaptureDevice]()
    @Published var formats = [VideoCodecType]()
    @Published var flashModes = [CameraFlashMode]()
    @Published var selectedPreset = CaptureSessionPreset.photo
    @Published var selectedDevice: AVCaptureDevice?
    @Published var selectedFormat = VideoCodecType.hevc
    @Published var selectedFlashMode = CameraFlashMode.unavailable
    @Published var zoomRange = 1.0...1.0
    @Published var zoom: Double = 1.0

    // MARK: - Private Properties
    private let camera : any CameraProtocol
    private var previewTask: Task<Void, Never>?
    private var photoTask: Task<Void, Never>?

    // MARK: - Initialization

    init(camera: any CameraProtocol = Camera.shared) {
        self.camera = camera
    }
    
    deinit {
        previewTask?.cancel()
        photoTask?.cancel()
    }

    // MARK: - Public Methods
    func start() async {
        do {
            try await camera.start()
            previewTask = Task { await listenCameraPreviews() }
            photoTask = Task { await listenPhotoCapture() }
            await loadSettings()
            state = .previewing
        } catch (let error as CameraError) {
            if error == .cameraUnauthorized {
                state = .unauthorized
            }
            self.error = error
            
        } catch {
            
        }
    }

    // MARK: - User Actions

    func handleTakePhoto() {
        Task {
            state = .processing
            await camera.takePhoto()
        }
    }

    func handleExit() {
        exit()
    }
    
    
    func handleSwitchPosition() {
        Task {
            do {
                try await camera.changePosition()
                await loadSettings()
                self.position = await camera.config.position
            } catch (let error as CameraError) {
                self.error = error
            } catch {
                
            }
        }
    }

    func handleAcceptPhoto() {
        acceptPhoto()
    }
    

    func handleRejectPhoto() {
        rejectPhoto()
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
                await loadSettings()
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

    func selectFlashMode(_ flashMode: CameraFlashMode) {
        Task {
            await camera.changeFlashMode(flashMode)
            selectedFlashMode = await camera.config.flashMode
        }
    }

    func selectZoom(_ zoom: Double) {
        Task {
            do {
                try await camera.changeZoom(zoom)
                self.zoom = await Double(camera.config.zoom)
            } catch (let error as CameraError) {
                self.error = error
            } catch {
                
            }
        }
    }

    
    // MARK: - Private Methods

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
    
    private func listenCameraPreviews() async {
        for await image in await camera.stream.previewStream {
            await setPreview(image: image)
        }
    }

    private func listenPhotoCapture() async {
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
        guard let cgImage = await photo.toCGImage() else {
            self.preview = nil
            return
        }
        state = .validating
        self.preview = Image(decorative: cgImage, scale: 1, orientation: .up)
        await camera.pause()
    }
    
    private func exit() {
        previewTask?.cancel()
        photoTask?.cancel()
        capture = nil
        Task {
            await camera.end()
        }
    }
    
    private func acceptPhoto() {
        Task {
            let (photo, config) = (await camera.photo, await camera.config)
            state = .accepted((photo: photo, config: config))
            exit()
        }
    }

    private func rejectPhoto() {
        Task {
            state = .previewing
            await camera.resume()
        }
    }

}
