//
//  CameraProtocol.swift
//  Camera
//
//  Created by Kevin LAUNAY on 22/08/2025.
//

import Foundation
@preconcurrency import AVFoundation
import CoreImage

/// Async camera interface defining preview and photo streams and control methods.
protocol CameraProtocol: Actor {
    var stream : any CameraStreamProtocol { get }
    var config : CameraConfiguration { get }
    func changePreset(preset: CaptureSessionPreset)
    func changeCamera(device: AVCaptureDevice?) async throws
    func start() async throws
    func resume() async
    func stop() async
    func takePhoto() async
    func switchFlash(_ value: CameraFlashMode)
    func changeCodec(_ codec: VideoCodecType)
    func swicthPosition() async throws
    func exit()
}

actor MockCamera: CameraProtocol {
    let stream: any CameraStreamProtocol
    let config = CameraConfiguration()
    private var started = false
    private var previewImages: [CIImage]
    private var photoImages: [AVCapturePhoto]
    private var previewIndex = 0
    private var photoIndex = 0

    init(previewImages: [CIImage] = [], photoImages: [AVCapturePhoto] = []) {
        self.previewImages = previewImages
        self.photoImages = photoImages
        self.stream = MockCameraStream()
    }

    func changePreset(preset: CaptureSessionPreset) {}
    func changeCamera(device: AVCaptureDevice?) async throws {}

    func start() async throws {
        started = true
        // Emit a preview frame if available.
        if !previewImages.isEmpty {
            await stream.emitPreview(previewImages[previewIndex % previewImages.count])
            previewIndex += 1
        }
    }

    func resume() async {
        started = true
    }
    func stop() async {
        started = false
    }
    func takePhoto() async {
        guard started, !photoImages.isEmpty else { return }
        await stream.emitPhoto(photoImages[photoIndex % photoImages.count])
        photoIndex += 1
    }
    
    func exit() {
    }
    
    func swicthPosition() async throws {
        
    }
    
    func changeCodec(_ codec: VideoCodecType) {
        
    }

    func switchFlash(_ value: CameraFlashMode) {
        
    }

}
