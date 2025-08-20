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
    /// Camera implementation conforming to ICamera (default: Camera)
    private let camera : any ICamera
    /// Most recent camera preview frame as a SwiftUI Image
    @Published var preview: Image?
    /// Photo camera returned by the component
    @Published var capture: AVCapturePhoto?
    /// Indicates if a photo has been captured and is awaiting confirmation.
    @Published var isPhotoCaptured = false
    @Published var position : AVCaptureDevice.Position = .back
    @Published var preset = 0 {
        didSet {
            print("action \(presets[preset].preset))")
            handleMenuPreset(presets[preset].preset)
        }
    }
    
    var presets = CaptureSessionPreset.allCases
    @Published var devices = [AVCaptureDevice]()
    @Published var device = [AVCaptureDevice]()

    /// Photo camera returned by the component
    private var photo: AVCapturePhoto?
    /// Task for streaming preview frames asynchronously
    private var previewTask: Task<Void, Never>?
    /// Task for asynchronously handling photo capture events
    private var photoTask: Task<Void, Never>?
    /// Initialize with any ICamera implementation (default: Camera)
    init(camera: any ICamera = Camera()) {
        self.camera = camera
        previewTask = Task { await handleCameraPreviews() }
        photoTask = Task { await handlePhotoCapture() }
    }
    
    func start() async {
        do {
            try await camera.configure(preset: presets[preset].preset, position: position, device: nil)
            isPhotoCaptured = false
            device = await camera.listCaptureDevice
            
            await camera.start()
        } catch {
            print("Failed to start camera: \(error)")
            // Handle error appropriately, e.g., show an alert to the user
        }
    }
    
    /// Asynchronously handle new preview frames from the camera.
    private func handleCameraPreviews() async {
        for await image in await camera.previewStream {
            await setPreview(image: image)
        }
    }

    /// Asynchronously handle new captured photos from the camera.
    private func handlePhotoCapture() async {
        for await photo in await camera.photoStream {
            await setPhoto(photo: photo)
        }
    }

    /// Take a photo when called (bound to UI button press).
    func handleButtonPhoto() {
        Task {
            await camera.takePhoto()
        }
    }

    func handleButtonExit() {
        Task {
            await stop()
            capture = nil
        }
    }
    
    private func handleMenuPreset(_ preset: AVCaptureSession.Preset) {
        Task {
            await camera.changePreset(preset: preset)
        }
    }

    func handleSwitchPosition() {
        Task {
            position = position == .back ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back
            do {
                try await camera.changeCamera(position: position, device: nil)
            } catch {
                print("Failed to start camera: \(error)")
            }
        }
    }

    
    func handleButtonSelectPhoto() {
        capture = photo
    }
    
    func handleRejectPhoto() {
        photo = nil
        Task {
            isPhotoCaptured = false
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
        self.isPhotoCaptured = true
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
