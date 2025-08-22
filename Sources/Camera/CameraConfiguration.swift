import AVFoundation

class CameraConfiguration {
    let session = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    var isCaptureSessionConfigured = false
    var isCaptureSessionOutputConfigured = false
    var isSetupNeeded: Bool = true

    var deviceInput: AVCaptureDeviceInput? {
        didSet {
            buildRotationCoordinator()
        }
    }
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    var flashMode: CameraFlashMode = .unavailbale
    var videoCodecType: VideoCodecType = .hevc
    var zoom: Float = 1.0
    var position: AVCaptureDevice.Position = .back {
        didSet {
            setup()
        }
    }
    var quality: AVCapturePhotoOutput.QualityPrioritization = .balanced
    var preset: CaptureSessionPreset = .photo
    private(set) var listCaptureDevice = [AVCaptureDevice]()
    private(set) var listSupportedFormat = [VideoCodecType]()
    private(set) var photoOutput = AVCapturePhotoOutput()

    init(deviceInput: AVCaptureDeviceInput? = nil, flashMode: CameraFlashMode = .off, videoCodecType: VideoCodecType = .hevc, zoom: Float = 1.0, position: AVCaptureDevice.Position = .back, quality: AVCapturePhotoOutput.QualityPrioritization = .balanced, preset: CaptureSessionPreset = .photo, photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()) {
        self.deviceInput = deviceInput
        self.flashMode = flashMode
        self.videoCodecType = videoCodecType
        self.zoom = zoom
        self.position = position
        self.quality = quality
        self.preset = preset
        self.photoOutput = photoOutput
        setup()
    }
    
    private func setup() {
        listSupportedFormat = photoOutput.availablePhotoCodecTypes.compactMap{
            VideoCodecType(avVideoCodecType: $0)
        }
        let cameras = CaptureDeviceType.allCases.map { $0.deviceType }
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: cameras, mediaType: .video, position: position)
        listCaptureDevice = discoverySession.devices.filter { $0.position == position }
        let isFlashAvailable = deviceInput?.device.isFlashAvailable ?? false
        flashMode = isFlashAvailable ? .auto : .unavailbale
    }
    
    func getDefaultCamera() -> AVCaptureDevice? {
        listCaptureDevice.first ?? AVCaptureDevice.default(for: .video)
    }
    
    func buildPhotoSettings() -> AVCapturePhotoSettings  {
        var photoSettings = AVCapturePhotoSettings()

        if photoOutput.availablePhotoCodecTypes.contains(videoCodecType.avVideoCodecType) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: videoCodecType.avVideoCodecType])
        } else {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: photoOutput.availablePhotoCodecTypes.first])
        }
        
        photoSettings.flashMode = flashMode.avFlashMode
        photoSettings.photoQualityPrioritization = quality
        return photoSettings
    }
    
    private func buildRotationCoordinator() {
        guard let deviceInput else {
            return
        }
        self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: deviceInput.device, previewLayer: nil)
    }
    
    func switchPosition() {
        position = position == .back ? .front : .back
    }
}
