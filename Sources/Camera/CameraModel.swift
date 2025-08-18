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

/// After initializing CameraModel, call `configureAndStart()` from `.task` or `.onAppear`.
@MainActor
class CameraModel: ObservableObject {
    private let camera : any ICamera
    
    @Published var preview: Image?
    @Published var isPhotoCaptured = false
    
    init(camera: any ICamera = Camera()) {
        self.camera = camera
    }
    
    /// Call this after initializing CameraModel, e.g. using .task or .onAppear in SwiftUI.
    func configureAndStart() async {
        print("\(camera)")
        await camera.configure(preset: .photo)
        await camera.start()
        Task {
            await handleCameraPreviews()
        }
        Task {
            await handlePhotoCapture()
        }
    }
    
    private func handleCameraPreviews() async {
        for await image in await camera.previewStream {
            await setPreview(image: image)
        }
    }

    private func handlePhotoCapture() async {
        for await photo in await camera.photoStream {
            await setPhoto(photo: photo)
        }
    }

    func handleButtonPhoto() {
        Task {
            await camera.takePhoto()
        }
    }
    
    func setPreview(image: CIImage?) async {
        guard let cgImage = await image?.toCGImage() else {
            self.preview = nil
            return
        }
        self.preview = Image(decorative: cgImage, scale: 1, orientation: .up)
    }

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
        
}
