//
//  File.swift
//  Camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//  
//
// Camera actor implementation using AVFoundation and async/await for video preview and photo capture.

import Foundation
@preconcurrency import AVFoundation
import UIKit

enum CameraError: Error {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case creationFailed
}

/// Async camera interface defining preview and photo streams and control methods.
protocol ICamera: Actor {
    var previewStream: AsyncStream<CIImage> { get }
    var photoStream: AsyncStream<AVCapturePhoto>  { get }
    func configure(preset: AVCaptureSession.Preset, position: AVCaptureDevice.Position, deviceType: AVCaptureDevice.DeviceType?) throws
    func start() async
    func stop() async
    func takePhoto() async
}

/// Camera actor managing AVCaptureSession, providing async streams for preview and photos, and controlling capture lifecycle.
actor Camera: NSObject, ICamera {
    
    /// AVCapture session managing capture inputs and outputs.
    private let session = AVCaptureSession()
    
    /// Input device for video capture.
    private var deviceInput: AVCaptureDeviceInput?
    
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    /// Output for capturing photos.
    private let photoOutput = AVCapturePhotoOutput()
    
    /// Output for capturing video frames for preview.
    private let videoOutput = AVCaptureVideoDataOutput()
    
    /// Serial queue for session-related operations to ensure thread safety.
    private let queue = DispatchQueue(label: "CameraSessionQueue")
    
    /// Flag indicating if preview frame emission is currently paused.
    private var isPreviewPaused = false
        
    /// Flag indicating if the capture session has been configured.
    private var isCaptureSessionConfigured = false

    /// Continuation used to yield preview frames into the async stream.
    private var previewContinuation: AsyncStream<CIImage>.Continuation?
    
    /// Public async stream of preview CIImages.
    private(set) lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            // Store continuation to yield preview frames later.
            self.previewContinuation = continuation
        }
    }()
    
    /// Continuation used to yield captured photos into the async stream.
    private var photoContinuation: AsyncStream<AVCapturePhoto>.Continuation?
    
    /// Public async stream of captured photos.
    private(set) lazy var photoStream: AsyncStream<AVCapturePhoto> = {
        AsyncStream { continuation in
            // Store continuation to yield photos later.
            self.photoContinuation = continuation
        }
    }()

    /// Emits a CIImage preview frame to the preview stream if not paused or stopped.
    private func emitPreview(_ ciImage: CIImage) {
        if !isPreviewPaused {
            previewContinuation?.yield(ciImage)
        }
    }
    
    /// Emits a captured photo to the photo stream if not paused or stopped.
    private func emitPhoto(_ photo: AVCapturePhoto) {
        photoContinuation?.yield(photo)
    }
    
    override init() {
        super.init()
        // Setup device orientation notifications asynchronously.
        Task { [weak self] in
            await self?.setupDeviceOrientationChanges()
        }
    }
    
    /// Starts generating device orientation notifications on the main actor.
    private func setupDeviceOrientationChanges() {
        Task { @MainActor in
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
    }
    
    deinit {
        Task { @MainActor in
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    /// Checks and requests camera authorization asynchronously.
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera access authorized.")
            return true
        case .notDetermined:
            print("Camera access not determined.")
            // Suspend the queue while requesting access to avoid race conditions.
            queue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            queue.resume()
            return status
        case .denied:
            print("Camera access denied.")
            return false
        case .restricted:
            print("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
        
    //MARK: - ICamera Implementation
    
    /// Configures the capture session with input device and outputs.
    /// - Parameters:
    ///   - preset: The session preset defining capture quality.
    ///   - position: The camera position (front or back).
    ///   - deviceType: Optional specific device type to select.
    func configure(preset: AVCaptureSession.Preset = .photo, position: AVCaptureDevice.Position = .back, deviceType: AVCaptureDevice.DeviceType?) throws {

        if session.isRunning {
            session.stopRunning()
            if let deviceInput {
                session.removeInput(deviceInput)
            }
        }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        session.sessionPreset = preset

        // Setup video input device
        let cameras = [
            .builtInDualCamera, .builtInTripleCamera, .builtInDualWideCamera,
            .builtInTrueDepthCamera, .builtInUltraWideCamera, .builtInWideAngleCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: cameras, mediaType: .video, position: position)

        let discoveredDevice: AVCaptureDevice?
        if let deviceType {
            discoveredDevice = discoverySession.devices.first { $0.deviceType == deviceType }
        } else {
            discoveredDevice = discoverySession.devices.first
        }
        
        guard let camera = discoveredDevice ?? AVCaptureDevice.default(for: .video) else {
            throw CameraError.cameraUnavailable
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                throw CameraError.cannotAddInput
            }
            session.addInput(input)
            self.deviceInput = input
            self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: nil)
        } catch {
            throw CameraError.creationFailed
        }
        
        // Add photo output if supported
        guard session.canAddOutput(photoOutput) else {
            throw CameraError.cannotAddOutput
        }
        session.addOutput(photoOutput)
        
        // Add video data output for preview frames
        guard session.canAddOutput(videoOutput) else {
            throw CameraError.cannotAddOutput
        }
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_preview_video_output"))
        session.addOutput(videoOutput)
        
        isCaptureSessionConfigured = true
    }
    
    /// Starts the capture session if authorized and configured.
    /// Ensures the session is not already running before starting.
    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            print("Camera access was not authorized.")
            return
        }
        guard isCaptureSessionConfigured
            , !self.session.isRunning
        else {
            return
        }
        isPreviewPaused = false
        queue.async {
            self.session.startRunning()
        }
        
    }
    
    /// Stops the capture session safely and pauses preview emission.
    func stop() async {
        guard isCaptureSessionConfigured else { return }
        
        if session.isRunning {
            isPreviewPaused = true
            queue.async {
                self.session.stopRunning()
            }
        }
    }
    
    deinit {
        photoContinuation?.finish()
        previewContinuation?.finish()
        Task { @MainActor in
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }
    
    /// Initiates a photo capture asynchronously with appropriate settings.
    /// Sets photo codec, flash mode, and video orientation if supported.
    func takePhoto() async {
        let videoOrientation = await getAVCaptureVideoOrientation()
            var photoSettings = AVCapturePhotoSettings()

            // Prefer JPEG codec if available.
            print(self.photoOutput.availablePhotoCodecTypes)
            if self.photoOutput.availablePhotoCodecTypes.contains(AVVideoCodecType.jpeg) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }
            
            // Flash mode commented out; can be enabled if needed.
            photoSettings.flashMode = await self.isFlashAvailable() ? .auto : .off
            photoSettings.photoQualityPrioritization = .balanced
            
            if let photoOutputVideoConnection = self.photoOutput.connection(with: .video) {
                // Set video orientation for the photo output connection if supported.
                if photoOutputVideoConnection.isVideoRotationAngleSupported(90.0)
                    , let videoOrientation = videoOrientation {
                    print("videoOrientation \(videoOrientation)")
                    photoOutputVideoConnection.videoOrientation = videoOrientation
                }
            }
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    /// Retrieves the current AVCaptureVideoOrientation based on device orientation asynchronously.
    /// - Returns: Optional AVCaptureVideoOrientation corresponding to device orientation.
    func getAVCaptureVideoOrientation() async -> AVCaptureVideoOrientation?  {
        await Task { @MainActor in
            Camera.videoOrientationFor(UIDevice.current.orientation)
        }.value
    }

    /// Helper method converting UIDeviceOrientation to AVCaptureVideoOrientation.
    private static func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch deviceOrientation {
        case .portrait:
            return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            return AVCaptureVideoOrientation.landscapeLeft
        default:
            return nil
        }
    }
    
    /// Checks asynchronously if the current device input supports flash.
    /// - Returns: Boolean indicating flash availability.
    @MainActor
    private func isFlashAvailable() async -> Bool {
        guard let deviceInput else {
            return false
        }
        return await deviceInput.device.isFlashAvailable
    }
    
}

// MARK: - AVCapturePhotoCaptureDelegate Implementation

/// Delegate handling photo capture events and forwarding photos to async stream.
extension Camera: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        Task {
            // Stop session and emit the captured photo asynchronously.
            await self.emitPhoto(photo)
        }
        
    }
}
// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate Implementation

/// Delegate handling video data output sample buffers and forwarding frames to preview stream.
extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = sampleBuffer.imageBuffer, let rotationCoordinator else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        // Update connection video orientation based on current device orientation if supported.
        Task { @MainActor in
            connection.videoRotationAngle = await rotationCoordinator.videoRotationAngleForHorizonLevelCapture
            
            // Emit the preview CIImage frame to the preview stream.
            await emitPreview(image)
        }
    }
}

enum AVCaptureSessionPreset: CaseIterable {
    case photo
    case low
    case medium
    case high
    case hd1280x720
    case hd1920x1080
    case hd4K3840x2160
    case cif352x288
    case iFrame1280x720
    case iFrame960x540
    case inputPriority
    case vga640x480

    var name: String {
        return switch self {
        case .photo : "photo"
        case .low : "low"
        case .medium : "medium"
        case .high : "high"
        case .hd1280x720 : "hd1280x720"
        case .hd1920x1080 : "hd1920x1080"
        case .hd4K3840x2160 : "hd4K3840x2160"
        case .cif352x288 : "cif352x288"
        case .iFrame1280x720 : "iFrame1280x720"
        case .iFrame960x540 : "iFrame960x540"
        case .inputPriority : "inputPriority"
        case .vga640x480 : "vga640x480"
        }
    }
    
    var preset: AVCaptureSession.Preset {
        return switch self {
        case .photo : AVCaptureSession.Preset.photo
        case .low : AVCaptureSession.Preset.low
        case .medium : AVCaptureSession.Preset.medium
        case .high : AVCaptureSession.Preset.high
        case .hd1280x720 : AVCaptureSession.Preset.hd1280x720
        case .hd1920x1080 : AVCaptureSession.Preset.hd1920x1080
        case .hd4K3840x2160 : AVCaptureSession.Preset.hd4K3840x2160
        case .cif352x288 : AVCaptureSession.Preset.cif352x288
        case .iFrame1280x720 : AVCaptureSession.Preset.iFrame1280x720
        case .iFrame960x540 : AVCaptureSession.Preset.iFrame960x540
        case .inputPriority : AVCaptureSession.Preset.inputPriority
        case .vga640x480 : AVCaptureSession.Preset.vga640x480

        }
    }
    
}

