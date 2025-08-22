//
//  AVCaptureSessionPreset.swift
//  Camera
//
//  Created by Kevin LAUNAY on 20/08/2025.
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
