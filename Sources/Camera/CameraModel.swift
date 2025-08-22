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

/// CameraModel manages camera configuration, preview streaming, and photo capture for SwiftUI views.
/// - Usage: Call `configure()` on appear, then `startStreaming()`. Use `.preview` to display the current camera image.
@MainActor
public class CameraModel: ObservableObject {
    
    enum State {
        case previewing, processing, validating
    }
    
    /// Camera implementation conforming to ICamera (default: Camera)
    private let camera : any CameraProtocol
    /// Most recent camera preview frame as a SwiftUI Image
    @Published var preview: Image?
    /// Photo camera returned by the component
    @Published var capture: AVCapturePhoto?
    /// Indicates if a photo has been captured and is awaiting confirmation.
    @Published var state = State.previewing
    @Published var position : AVCaptureDevice.Position = .back
    @Published var presetSelected = 0
    
    var presets = CaptureSessionPreset.allCases
    @Published var devices = [AVCaptureDevice]()
    @Published var deviceSelected = 0
    @Published var formats = [VideoCodecType]()
    @Published var formatSelected = 0

    /// Photo camera returned by the component
    private var photo: AVCapturePhoto?
    /// Task for streaming preview frames asynchronously
    private var previewTask: Task<Void, Never>?
    /// Task for asynchronously handling photo capture events
    private var photoTask: Task<Void, Never>?
    /// Initialize with any ICamera implementation (default: Camera)
    init(camera: any CameraProtocol = Camera()) {
        self.camera = camera
    }
    
    func start() async {
        previewTask = Task { await handleCameraPreviews() }
        photoTask = Task { await handlePhotoCapture() }
        self.position = await camera.config.position
        do {
            //try await camera.configure(preset: presets[presetSelected].avPreset, device: nil)
            state = .previewing
            devices = await camera.config.listCaptureDevice
            deviceSelected = 0
            formats = await camera.config.listSupportedFormat
            try await camera.start()
        } catch {
            print("Failed to start camera: \(error)")
            // Handle error appropriately, e.g., show an alert to the user
        }
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
    
    func handleSelectIndexPreset(_ index: Int) {
        Task {
            presetSelected = index
            await camera.changePreset(preset: presets[presetSelected])
        }
    }

    func handleSwitchPosition() {
        Task {
            do {
                
                try await camera.swicthPosition()
                devices = await camera.config.listCaptureDevice
                deviceSelected = 0
                position = await camera.config.position
            } catch {
                print("Failed to switch camera: \(error)")
            }
        }
    }

    func handleSelectIndexDevice(_ index: Int) {
        Task {
            deviceSelected = index
            do {
                try await camera.changeCamera(device: devices[deviceSelected])
            } catch {
                print("Failed to select device camera \(devices[deviceSelected].localizedName): \(error)")
            }
        }
    }

    func handleSelectIndexFormat(_ index: Int) {
        Task {
            formatSelected = index
            await camera.changeCodec(formats[formatSelected])
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
    
    deinit {
        previewTask?.cancel()
        photoTask?.cancel()
    }
    
    /// Update the preview property with new camera image data.
    func setPreview(image: CIImage?) async {
        guard let cgImage = await image?.toCGImage() else {
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
