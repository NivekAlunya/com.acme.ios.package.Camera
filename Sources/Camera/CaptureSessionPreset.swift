//
//  CaptureSessionPreset.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

public enum CaptureSessionPreset: CaseIterable {
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

    var stringKey: String {
        return switch self {
        case .photo : "preset_photo"
        case .low : "preset_low"
        case .medium : "preset_medium"
        case .high : "preset_high"
        case .hd1280x720 : "preset_hd1280x720"
        case .hd1920x1080 : "preset_hd1920x1080"
        case .hd4K3840x2160 : "preset_hd4K3840x2160"
        case .cif352x288 : "preset_cif352x288"
        case .iFrame1280x720 : "preset_iFrame1280x720"
        case .iFrame960x540 : "preset_iFrame960x540"
        case .inputPriority : "preset_inputPriority"
        case .vga640x480 : "preset_vga640x480"
        }
    }
    
    var avPreset: AVCaptureSession.Preset {
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
