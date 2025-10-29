//
//  CameraProtocol.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

@preconcurrency import AVFoundation
import CoreImage
import Foundation

/// Defines the asynchronous interface for a camera object.
/// This protocol allows for mocking and dependency injection, enabling testable camera features.
public protocol CameraProtocol: Actor {
    /// The stream that provides preview frames and captured photos.
    var stream: any CameraStreamProtocol { get }

    /// The current configuration of the camera.
    var config: CameraConfiguration { get }

    /// The most recently captured photo.
    var photo: (any PhotoData)? { get }

    /// Changes the capture session preset.
    /// - Parameter preset: The `CaptureSessionPreset` to apply.
    func changePreset(preset: CaptureSessionPreset)
    
    /// Changes the active camera device.
    /// - Parameter device: The `AVCaptureDevice` to switch to.
    func changeCamera(device: AVCaptureDevice) async throws

    /// Starts the camera capture session.
    func start() async throws

    /// Resumes a paused capture session.
    func resume() async

    /// Pauses the capture session.
    func pause() async

    /// Ends the capture session and releases resources.
    func end() async

    /// Initiates a photo capture.
    func takePhoto() async

    /// Changes the video codec for photo capture.
    /// - Parameter codec: The `VideoCodecType` to use.
    func changeCodec(_ codec: VideoCodecType)

    /// Changes the flash mode.
    /// - Parameter flashMode: The `CameraFlashMode` to use.
    func changeFlashMode(_ flashMode: CameraFlashMode)

    /// Changes the zoom factor of the camera.
    /// - Parameter factor: The desired zoom factor.
    func changeZoom(_ factor: CGFloat) throws

    /// Switches between the front and back cameras.
    func changePosition() async throws
}
