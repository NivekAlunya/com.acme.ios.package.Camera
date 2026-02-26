//
//  CameraConfiguration.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

/// A struct that holds all the configuration settings for the camera.
public struct CameraConfiguration: Hashable, @unchecked Sendable {


    // MARK: - Stored Properties

    /// The active camera device input.
    public private(set) var deviceInput: AVCaptureDeviceInput?

    /// The rotation coordinator for handling device orientation.
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    /// The current flash mode.
    var flashMode: CameraFlashMode = .unavailable

    /// The video codec to be used for captures.
    var videoCodecType: VideoCodecType = .hevc

    /// The current zoom factor.
    var zoom: Float = 1.0

    /// The current camera position (e.g., `.back` or `.front`).
    var position: AVCaptureDevice.Position = .back

    /// The quality prioritization for photo capture.
    var quality: AVCapturePhotoOutput.QualityPrioritization = .balanced

    /// The session preset for capture quality.
    var preset: CaptureSessionPreset = .photo
    
    /// The aspect ratio for the capture session.
    public var ratio: CaptureSessionAspectRatio = .defaultAspectRatio

    /// A list of available capture devices for the current position.
    public private(set) var listCaptureDevice = [AVCaptureDevice]()

    /// A list of supported video formats for the current device.
    public private(set) var listSupportedFormat = [VideoCodecType]()

    /// A list of available flash modes for the current device.
    public private(set) var listFlashMode = [CameraFlashMode]()

    /// A list of supported session presets.
    public private(set) var listPreset = [CaptureSessionPreset]()

    /// The available zoom range for the current device.
    public private(set) var zoomRange = 1.0...1.0

    /// The output for capturing photos.
    public private(set) var photoOutput: AVCapturePhotoOutput

    /// The output for capturing video preview frames.
    private let videoOutput = AVCaptureVideoDataOutput()

    /// A flag indicating whether the outputs have been set up.
    private var isOutputSetup = false

    /// The maximum zoom factor allowed.
    private let maxZoom = 25.0
    

    // MARK: - Initialization

    public init(
        deviceInput: AVCaptureDeviceInput? = nil,
        flashMode: CameraFlashMode = .off,
        videoCodecType: VideoCodecType = .hevc,
        zoom: Float = 1.0,
        position: AVCaptureDevice.Position = .back,
        quality: AVCapturePhotoOutput.QualityPrioritization = .balanced,
        preset: CaptureSessionPreset = .photo,
        photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput(),
        aspectRatio: CaptureSessionAspectRatio = .defaultAspectRatio
    ) {
        self.deviceInput = deviceInput
        self.flashMode = flashMode
        self.videoCodecType = videoCodecType
        self.zoom = zoom
        self.position = position
        self.quality = quality
        self.preset = preset
        self.photoOutput = photoOutput
        self.ratio = aspectRatio
        refreshAvailableDevices()
    }
    
    /// Configures the camera device's auto settings including focus, exposure, and white balance.
    /// Each setting is applied independently so that unsupported focus modes do not prevent
    /// exposure or white balance from being configured.
    func configureAutoSettings() {
        guard let device = deviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            // Focus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }

            // Allow full focus range including close-up/macro
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .none
            }

            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }

            // Continuous exposure (prevents blur from exposure lag)
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
            }

            // Continuous white balance
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }

        } catch {
            #if DEBUG
            print("CameraConfiguration.configureAutoSettings: \(error)")
            #endif
        }
    }
    // MARK: - Private Methods

    /// Refreshes the list of available capture devices based on the current position.
    /// The resulting list is explicitly sorted according to the priority order defined in `CaptureDeviceType`.
    private mutating func refreshAvailableDevices() {
        let cameras = CaptureDeviceType.allCases.map { $0.deviceType }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: cameras, mediaType: .video, position: position)
        
        listCaptureDevice = discoverySession.devices.filter { $0.position == position }

    }

    /// Sets up the properties related to the current device (flash, zoom, etc.).
    private mutating func setupDevice() {
        let isFlashAvailable = deviceInput?.device.isFlashAvailable ?? false
        flashMode = isFlashAvailable ? .auto : .unavailable
        listFlashMode = flashMode.modes
        zoom = 1.0
        if let device = deviceInput?.device {
            let mx = min(maxZoom, device.maxAvailableVideoZoomFactor)
            zoomRange = Double(device.minAvailableVideoZoomFactor)...(Double(mx))
            self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: device, previewLayer: nil)
        } else {
            zoomRange = 1...1
        }
    }

    /// Sets up the list of supported formats from the photo output.
    mutating func setupOutput() {
        listSupportedFormat = photoOutput.availablePhotoCodecTypes.compactMap {
            VideoCodecType(avVideoCodecType: $0)
        }
    }

    /// Builds the `AVCapturePhotoSettings` for a photo capture request.
    /// - Returns: A configured `AVCapturePhotoSettings` object.
    func buildPhotoSettings() async -> AVCapturePhotoSettings {
        var photoSettings: AVCapturePhotoSettings

        if photoOutput.availablePhotoCodecTypes.contains(videoCodecType.avVideoCodecType) {
            photoSettings = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: videoCodecType.avVideoCodecType
            ])
        } else {
            // Fallback to the first available codec if the preferred one is not available.
            photoSettings = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: photoOutput.availablePhotoCodecTypes.first
            ])
        }

        photoSettings.flashMode = flashMode.avFlashMode
        photoSettings.photoQualityPrioritization = quality
        return photoSettings
    }

    /// Switches the camera position between front and back.
    mutating func switchPosition() {
        position = position == .back ? .front : .back
        refreshAvailableDevices()
    }
    
    /// Sets up the entire capture session with a given device and delegate.
    /// - Parameters:
    ///   - device: The `AVCaptureDevice` to use.
    ///   - session: The `AVCaptureSession` to configure.
    ///   - delegate: The delegate for the video data output.
    mutating func setup(device: AVCaptureDevice, session: AVCaptureSession, delegate: AVCaptureVideoDataOutputSampleBufferDelegate) throws {
        try self.setupCaptureDevice(device: device, forSession: session)
        try self.setupCaptureDeviceOutput(forSession: session, delegate: delegate)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        listPreset = CaptureSessionPreset.allCases.filter({ session.canSetSessionPreset($0.avPreset) })
        // Find the actual preset in the list, or fallback to the first available one.
        preset = listPreset.first(where: { $0 == preset }) ?? listPreset.first ?? .inputPriority
        session.sessionPreset = preset.avPreset
        
    }

    /// Sets up the photo and video outputs for the capture session.
    private mutating func setupCaptureDeviceOutput(
        forSession session: AVCaptureSession, delegate: AVCaptureVideoDataOutputSampleBufferDelegate
    ) throws {
        guard !isOutputSetup else {
            return
        }

        guard session.canAddOutput(photoOutput) else {
            throw CameraError.cannotAddOutput
        }
        session.addOutput(photoOutput)

        guard session.canAddOutput(videoOutput) else {
            throw CameraError.cannotAddOutput
        }
        videoOutput.setSampleBufferDelegate(
            delegate, queue: DispatchQueue(label: "camera_preview_video_output"))
        session.addOutput(videoOutput)

        setupOutput()
        isOutputSetup = true
    }

    /// Sets up the capture device input for the given session.
    /// - Parameters:
    ///   - device: The capture device to configure.
    ///   - session: The capture session to which the device input will be added.
    /// - Throws: `CameraError.creationFailed` if the input cannot be created,
    ///           or `CameraError.cannotAddInput` if the input cannot be added to the session.
    private mutating func setupCaptureDevice(device: AVCaptureDevice, forSession session: AVCaptureSession) throws {
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraError.creationFailed
        }
        
        guard session.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
        deviceInput = input
        setupDevice()
        configureAutoSettings()
    }
    
    /// Gets the default camera device based on the current configuration.
    /// - Returns: An `AVCaptureDevice` instance.
    func getDefaultCamera() -> AVCaptureDevice? {
        listCaptureDevice.first ?? AVCaptureDevice.default(for: .video)
    }
}
