//
//  CameraProtocol.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import Foundation
@preconcurrency import AVFoundation
import CoreImage

/// Async camera interface defining preview and photo streams and control methods.
protocol CameraProtocol: Actor {
    var stream : any CameraStreamProtocol { get }
    var config : CameraConfiguration { get }
    var photo : AVCapturePhoto? { get }
    func changePreset(preset: CaptureSessionPreset)
    func changeCamera(device: AVCaptureDevice) async throws
    func start() async throws
    func resume() async
    func stop() async
    func takePhoto() async
    func switchFlash(_ value: CameraFlashMode)
    func changeCodec(_ codec: VideoCodecType)
    func switchPosition() async throws
    func end() async
    func createStreams()
}
