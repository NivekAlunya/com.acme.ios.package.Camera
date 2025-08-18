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
class CameraModel: ObservableObject {
    /// Camera implementation conforming to ICamera (default: Camera)
    private let camera : any ICamera
    
    /// Most recent camera preview frame as a SwiftUI Image
    @Published var preview: Image?
    /// Indicates if a photo was captured (not used in this version)
    @Published var isPhotoCaptured = false
    /// Tracks configuration state to avoid redundant setup
    private var isConfigured = false
    /// Task for streaming preview frames asynchronously
    private var previewTask: Task<Void, Never>?
    /// Task for asynchronously handling photo capture events
    private var photoTask: Task<Void, Never>?

    /// Initialize with any ICamera implementation (default: Camera)
    init(camera: any ICamera = Camera()) {
        self.camera = camera
        
    }
    
    /// Prepare the camera for use. Should be called once on appear.
    func configure() async {
        guard !isConfigured else { return }
        isConfigured = true
        print("\(camera)")
        await camera.configure(preset: .photo)
    }
    
    /// Start camera session and begin streaming preview/photo events.
    func startStreaming() async {
        previewTask?.cancel()
        photoTask?.cancel()
        
        await camera.start()

        previewTask = Task { await handleCameraPreviews() }
        photoTask = Task { await handlePhotoCapture() }
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
    
    /// Update the preview property with new camera image data.
    func setPreview(image: CIImage?) async {
        guard let cgImage = await image?.toCGImage() else {
            self.preview = nil
            return
        }
        self.preview = Image(decorative: cgImage, scale: 1, orientation: .up)
    }

    /// Update preview with captured photo and stop the camera.
    func setPhoto(photo: AVCapturePhoto?) async {
        guard let cgImage = photo?.cgImageRepresentation()
            , let metadataOrientation = photo?.metadata[String(kCGImagePropertyOrientation)] as? UInt32
            , let cgImageOrientation = CGImagePropertyOrientation(rawValue: metadataOrientation) as? UInt8
            , let imageOrientation = Image.Orientation(rawValue: cgImageOrientation)
        else {
            self.preview = nil
            return
        }
        
        
        Task { @MainActor in
            await camera.stop()
            self.preview = Image(decorative: cgImage, scale: 1, orientation: imageOrientation)
        }
    }
    
    /// Cancel preview/photo tasks and stop the camera immediately.
    // Note: Cannot reliably await stop() in deinit; call stop() manually if needed before deallocation.
    func stop() {
        previewTask?.cancel()
        photoTask?.cancel()
        Task { await camera.stop() }
    }
        
}
