//
//  CameraConfiguration.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

/// The mode for displaying the camera preview.
public enum CameraPreviewMode: Sendable {
    /// Use a standard SwiftUI `Image` updated from a `CIImage` stream.
    case streaming
    /// Use a native `AVCaptureVideoPreviewLayer`.
    case native
    
    public var stringKey: String {
        switch self {
        case .streaming: return "preview_mode_streaming"
        case .native: return "preview_mode_native"
        }
    }
}

/// A struct that holds all the configuration settings for the camera.
public struct CameraConfiguration: Hashable, @unchecked Sendable {


    // MARK: - Stored Properties

    /// The active camera device input.
    public private(set) var deviceInput: AVCaptureDeviceInput?
    
    /// The mode for the camera preview.
    public var previewMode: CameraPreviewMode = .streaming

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
    
    /// The target photo resolution (Megapixels).
    public var resolution: CameraResolution = .mp12

    /// A list of available capture devices for the current position.
    public private(set) var listCaptureDevice = [AVCaptureDevice]()

    /// A list of supported video formats for the current device.
    public private(set) var listSupportedFormat = [VideoCodecType]()

    /// A list of available flash modes for the current device.
    public private(set) var listFlashMode = [CameraFlashMode]()

    /// A list of supported session presets.
    public private(set) var listPreset = [CaptureSessionPreset]()
    
    /// A list of supported photo resolutions.
    public private(set) var supportedResolutions: [CameraResolution] = [.mp12]

    /// The available zoom range for the current device.
    public private(set) var zoomRange = 1.0...1.0

    /// The output for capturing photos.
    public private(set) var photoOutput: AVCapturePhotoOutput

    /// The output for capturing video preview frames.
    let videoOutput = AVCaptureVideoDataOutput()

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
        resolution: CameraResolution = .mp12,
        photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput(),
        aspectRatio: CaptureSessionAspectRatio = .defaultAspectRatio,
        previewMode: CameraPreviewMode = .streaming
    ) {
        self.deviceInput = deviceInput
        self.flashMode = flashMode
        self.videoCodecType = videoCodecType
        self.zoom = zoom
        self.position = position
        self.quality = quality
        self.preset = preset
        self.resolution = resolution
        self.photoOutput = photoOutput
        self.ratio = aspectRatio
        self.previewMode = previewMode
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
        let cameras = CaptureDeviceType.allCases.map { $0.avDeviceType }
        
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
        supportedResolutions = [.mp12] // Baseline
        
        if let device = deviceInput?.device {
            let mx = min(maxZoom, device.maxAvailableVideoZoomFactor)
            zoomRange = Double(device.minAvailableVideoZoomFactor)...(Double(mx))
            self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: device, previewLayer: nil)
            
            if #available(iOS 16.0, *) {
                var availableMPs: Set<CameraResolution> = [.mp12]
                for format in device.formats {
                    for dimensions in format.supportedMaxPhotoDimensions {
                        let pixels = dimensions.width * dimensions.height
                        let mp = pixels / 1_000_000
                        if mp >= 40 { availableMPs.insert(.mp48) }
                        else if mp >= 20 { availableMPs.insert(.mp24) }
                    }
                }
                
                // If the active device is a multi-lens virtual device (e.g. builtInTripleCamera),
                // AVFoundation virtual device formats are capped at lower resolutions.
                // Check if any physical wide-angle camera on the current position supports 24MP or 48MP.
                if !availableMPs.contains(.mp48) || !availableMPs.contains(.mp24) {
                    for dev in listCaptureDevice where dev.deviceType == .builtInWideAngleCamera {
                        for format in dev.formats {
                            for dimensions in format.supportedMaxPhotoDimensions {
                                let mp = (dimensions.width * dimensions.height) / 1_000_000
                                if mp >= 40 { availableMPs.insert(.mp48) }
                                else if mp >= 20 { availableMPs.insert(.mp24) }
                            }
                        }
                    }
                }
                
                supportedResolutions = Array(availableMPs).sorted()
            }
        } else {
            zoomRange = 1...1
        }
    }

    /// Sets up the list of supported formats from the photo output.
    mutating func setupOutput() {
        listSupportedFormat = photoOutput.availablePhotoCodecTypes.compactMap {
            VideoCodecType(avVideoCodecType: $0)
        }
        if #available(iOS 17.0, *) {
            if photoOutput.isAutoDeferredPhotoDeliverySupported {
                photoOutput.isAutoDeferredPhotoDeliveryEnabled = true
            }
        }
        updatePhotoOutputMaxDimensions()
    }

    /// Updates `photoOutput.maxPhotoDimensions` to the largest dimensions supported by the current active format.
    func updatePhotoOutputMaxDimensions() {
        if #available(iOS 16.0, *), let device = deviceInput?.device {
            let supported = device.activeFormat.supportedMaxPhotoDimensions
            if let maxDimensions = supported.max(by: { ($0.width * $0.height) < ($1.width * $1.height) }) {
                photoOutput.maxPhotoDimensions = maxDimensions
            }
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
        } else if let fallbackCodec = photoOutput.availablePhotoCodecTypes.first {
            // Fallback to the first available codec if the preferred one is not available.
            photoSettings = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: fallbackCodec
            ])
        } else {
            // No codec available at all — use default settings.
            photoSettings = AVCapturePhotoSettings()
        }

        if #available(iOS 16.0, *), let device = deviceInput?.device {
            // Find dimensions matching the requested resolution from the active format
            let activeFormat = device.activeFormat
            var targetDimensions: CMVideoDimensions? = nil
            
            for dimensions in activeFormat.supportedMaxPhotoDimensions {
                let mp = (dimensions.width * dimensions.height) / 1_000_000
                if resolution == .mp48 && mp >= 40 {
                    if let existing = targetDimensions {
                        if (dimensions.width * dimensions.height) > (existing.width * existing.height) {
                            targetDimensions = dimensions
                        }
                    } else {
                        targetDimensions = dimensions
                    }
                } else if resolution == .mp24 && mp >= 20 && mp < 40 {
                    if let existing = targetDimensions {
                        if (dimensions.width * dimensions.height) > (existing.width * existing.height) {
                            targetDimensions = dimensions
                        }
                    } else {
                        targetDimensions = dimensions
                    }
                } else if resolution == .mp12 && mp < 20 {
                    if let existing = targetDimensions {
                        if (dimensions.width * dimensions.height) > (existing.width * existing.height) {
                            targetDimensions = dimensions
                        }
                    } else {
                        targetDimensions = dimensions
                    }
                }
            }
            
            if let targetDimensions {
                let targetPixels = targetDimensions.width * targetDimensions.height
                let currentMax = photoOutput.maxPhotoDimensions.width * photoOutput.maxPhotoDimensions.height
                if targetPixels > currentMax {
                    photoOutput.maxPhotoDimensions = targetDimensions
                }
                let safeMaxPixels = photoOutput.maxPhotoDimensions.width * photoOutput.maxPhotoDimensions.height
                if targetPixels <= safeMaxPixels {
                    photoSettings.maxPhotoDimensions = targetDimensions
                } else {
                    photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
                }
            }
        }

        photoSettings.flashMode = flashMode.avFlashMode
        if resolution == .mp48 || resolution == .mp24 {
            photoSettings.photoQualityPrioritization = .quality
        } else {
            photoSettings.photoQualityPrioritization = quality
        }
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
        listPreset = CaptureSessionPreset.allCases.filter({ session.canSetSessionPreset($0.avPreset) })
        // Find the actual preset in the list, or fallback to the first available one.
        preset = listPreset.first(where: { $0 == preset }) ?? listPreset.first ?? .inputPriority
        session.sessionPreset = preset.avPreset
        session.commitConfiguration()
        
        updatePhotoOutputMaxDimensions()
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
        photoOutput.maxPhotoQualityPrioritization = .quality
        if #available(iOS 17.0, *) {
            if photoOutput.isAutoDeferredPhotoDeliverySupported {
                photoOutput.isAutoDeferredPhotoDeliveryEnabled = true
            }
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
