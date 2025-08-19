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
    /// Indicates if a photo was captured (not used in this version)
    @Published var isPhotoCaptured = false
    @Published var position : AVCaptureDevice.Position = .back
    @Published var preset = 0 {
        didSet {
            print("action")
            handleMenuPreset(presets[preset].preset)
        }
    }
    
    var presets = AVCaptureSessionPreset.allCases

    /// Photo camera returned by the component
    private var photo: AVCapturePhoto?
    /// Tracks configuration state to avoid redundant setup
    private var isConfigured = false
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
    
    /// Prepare the camera for use. Should be called once on appear.
    func configure(preset: AVCaptureSession.Preset = .photo, position : AVCaptureDevice.Position = .back) async {
        guard !isConfigured else { return }
        await camera.configure(preset: preset, position: position)
        isConfigured = true
    }
    
    func start() async {
        await configure(preset: presets[preset].preset, position: position)
        guard isConfigured else {
            return
        }
        await startStreaming()
    }
    /// Start camera session and begin streaming preview/photo events.
    private func startStreaming() async {
        isPhotoCaptured = false
        await camera.start()

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
            stop()
            capture = nil
        }
    }
    
    private func handleMenuPreset(_ preset: AVCaptureSession.Preset) {
        isConfigured = false
        Task {
            await start()
        }
    }

    func handleSwitchPosition() {
        isConfigured = false
        Task {
            position = position == .back ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back
            await start()
        }
    }

    
    func handleButtonSelectPhoto() {
        capture = photo
    }
    
    func handleRejectPhoto() {
        photo = nil
        Task {
            await startStreaming()
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
    func stop() {
        previewTask?.cancel()
        photoTask?.cancel()
        Task { await camera.stop() }
    }
        
}

extension Image.Orientation {
    init(_ cgOrientation: CGImagePropertyOrientation) {
        switch cgOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        }
    }

}

extension Image {
    public init?(avCapturePhoto: AVCapturePhoto) {
        guard let cgImage = avCapturePhoto.cgImageRepresentation()
            , let metadataOrientation = avCapturePhoto.metadata[String(kCGImagePropertyOrientation)]
                , let cgImageOrientation = CGImagePropertyOrientation(rawValue: metadataOrientation as! UInt32)
        else {
            return nil
        }
        let imageOrientation = Image.Orientation(cgImageOrientation)
        self = Image(decorative: cgImage, scale: 1, orientation: imageOrientation)
    }
}
