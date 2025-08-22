import Foundation
import AVFoundation
import SwiftUI

@MainActor
class CameraSettingsModel: ObservableObject {
    @Published var selectedPreset: CaptureSessionPreset
    @Published var selectedDevice: AVCaptureDevice?
    @Published var selectedFormat: VideoCodecType

    @Published var presets: [CaptureSessionPreset] = []
    @Published var devices: [AVCaptureDevice] = []
    @Published var formats: [VideoCodecType] = []

    private let camera: any CameraProtocol

    init(camera: any CameraProtocol) {
        self.camera = camera

        // Initialize with current camera settings
        self.selectedPreset = .photo
        self.selectedDevice = nil
        self.selectedFormat = .hevc

        Task {
            await self.loadSettings()
        }
    }

    func loadSettings() async {
        self.presets = await camera.config.preset.allCases
        self.devices = await camera.config.listCaptureDevice
        self.formats = await camera.config.listSupportedFormat

        self.selectedPreset = await camera.config.preset
        self.selectedDevice = await camera.config.deviceInput?.device
        self.selectedFormat = await camera.config.videoCodecType
    }

    func selectPreset(_ preset: CaptureSessionPreset) {
        Task {
            selectedPreset = preset
            await camera.changePreset(preset: preset)
        }
    }

    func selectDevice(_ device: AVCaptureDevice) {
        Task {
            selectedDevice = device
            do {
                try await camera.changeCamera(device: device)
            } catch {
                print("Failed to select device camera \(device.localizedName): \(error)")
            }
        }
    }

    func selectFormat(_ format: VideoCodecType) {
        Task {
            selectedFormat = format
            await camera.changeCodec(format)
        }
    }
}
