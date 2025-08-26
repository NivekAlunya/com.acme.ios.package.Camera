//
//  CameraConfiguration.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation


public struct CameraConfiguration {
    private(set)var deviceInput: AVCaptureDeviceInput?
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    var flashMode: CameraFlashMode = .unavailable
    var videoCodecType: VideoCodecType = .hevc
    var zoom: Float = 1.0
    var position: AVCaptureDevice.Position = .back
    var quality: AVCapturePhotoOutput.QualityPrioritization = .balanced
    var preset: CaptureSessionPreset = .photo
    private(set) var listCaptureDevice = [AVCaptureDevice]()
    private(set) var listSupportedFormat = [VideoCodecType]()
    private(set) var photoOutput: AVCapturePhotoOutput
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isOutputSetup = false
    
    init(deviceInput: AVCaptureDeviceInput? = nil, flashMode: CameraFlashMode = .off, videoCodecType: VideoCodecType = .hevc, zoom: Float = 1.0, position: AVCaptureDevice.Position = .back, quality: AVCapturePhotoOutput.QualityPrioritization = .balanced, preset: CaptureSessionPreset = .photo, photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()) {
        self.deviceInput = deviceInput
        self.flashMode = flashMode
        self.videoCodecType = videoCodecType
        self.zoom = zoom
        self.position = position
        self.quality = quality
        self.preset = preset
        self.photoOutput = photoOutput
        refreshAvailableDevices()
    }
    
    private mutating func refreshAvailableDevices() {
        let cameras = CaptureDeviceType.allCases.map { $0.deviceType }
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: cameras, mediaType: .video, position: position)
        listCaptureDevice = discoverySession.devices.filter { $0.position == position }
    }
    
    private mutating func setupDevice() {
        let isFlashAvailable = deviceInput?.device.isFlashAvailable ?? false
        flashMode = isFlashAvailable ? .auto : .unavailable
        buildRotationCoordinator()
    }

    mutating func setupOutput() {
        listSupportedFormat = photoOutput.availablePhotoCodecTypes.compactMap{
            VideoCodecType(avVideoCodecType: $0)
        }
    }
    
    func buildPhotoSettings() async -> AVCapturePhotoSettings  {
        var photoSettings = AVCapturePhotoSettings()

        if photoOutput.availablePhotoCodecTypes.contains(videoCodecType.avVideoCodecType) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: videoCodecType.avVideoCodecType])
        } else {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: photoOutput.availablePhotoCodecTypes.first])
        }
        
        // Flash mode commented out; can be enabled if needed.
        photoSettings.flashMode = flashMode.avFlashMode
        photoSettings.photoQualityPrioritization = quality
        return photoSettings
    }
    
    private mutating func buildRotationCoordinator() {
        guard let deviceInput else {
            return
        }
        self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: deviceInput.device, previewLayer: nil)
    }
    
    mutating func switchPosition() {
        position = position == .back ? .front : .back
        refreshAvailableDevices()
    }

    mutating func setupCaptureDeviceOutput(forSession session: AVCaptureSession, delegate: AVCaptureVideoDataOutputSampleBufferDelegate) throws {
        guard !isOutputSetup else {
            return
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
        videoOutput.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "camera_preview_video_output"))
        session.addOutput(videoOutput)

        setupOutput()
        isOutputSetup = true
    }

    mutating func setupCaptureDevice(device: AVCaptureDevice, forSession session: AVCaptureSession) throws {

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw CameraError.cannotAddInput
            }
            session.addInput(input)
            deviceInput = input
            setupDevice()
            print("\(input.device.localizedName)")
        } catch {
            throw CameraError.creationFailed
        }
    }
    
    func getDefaultCamera() -> AVCaptureDevice? {
        listCaptureDevice.first ?? AVCaptureDevice.default(for: .video)
    }

}
