//
//  MockCamera.swift
//  Camera
//
//  Created by Kevin LAUNAY on 18/08/2025.
//
import AVFoundation
import CoreImage

// Mock implementation of ICamera for testing CameraModel
actor MockCamera: ICamera {
    func resume() async {
        
    }
    
    var listCaptureDevice: [AVCaptureDevice] = []
    
    func configure(preset: AVCaptureSession.Preset, position: AVCaptureDevice.Position, device: AVCaptureDevice?) throws {
    }
    
    func changeCamera(position: AVCaptureDevice.Position, device: AVCaptureDevice?) throws {
    }
    
    
    let previewImages: [CIImage]
    let photoImages: [AVCapturePhoto]
    
    var previewStream: AsyncStream<CIImage> {
        AsyncStream { continuation in
            for img in previewImages { continuation.yield(img) }
            continuation.finish()
        }
    }
    var photoStream: AsyncStream<AVCapturePhoto> {
        AsyncStream { continuation in
            popImages(continuation: continuation)
        }
    }
    
    func popImages(continuation: AsyncStream<AVCapturePhoto>.Continuation) {        
        for photo in photoImages {
                //continuation.yield(photo)
        }
        continuation.finish()
    }
    func changePreset(preset: AVCaptureSession.Preset) {
        
    }
    func start() async {}
    func stop() async {}
    func takePhoto() async {}
    init(previewImages: [CIImage], photoImages: [AVCapturePhoto]) {
        self.previewImages = previewImages
        self.photoImages = photoImages
    }
}
