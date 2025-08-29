//
//  CaptureSessionPreset.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation

/// A wrapper enum for `AVCaptureSession.Preset` to provide a `CaseIterable` and more convenient interface.
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

    /// A computed property that returns a localization key for each preset.
    var stringKey: String {
        switch self {
        case .photo: "preset_photo"
        case .low: "preset_low"
        case .medium: "preset_medium"
        case .high: "preset_high"
        case .hd1280x720: "preset_hd1280x720"
        case .hd1920x1080: "preset_hd1920x1080"
        case .hd4K3840x2160: "preset_hd4K3840x2160"
        case .cif352x288: "preset_cif352x288"
        case .iFrame1280x720: "preset_iFrame1280x720"
        case .iFrame960x540: "preset_iFrame960x540"
        case .inputPriority: "preset_inputPriority"
        case .vga640x480: "preset_vga640x480"
        }
    }
    
    /// The corresponding `AVCaptureSession.Preset`.
    var avPreset: AVCaptureSession.Preset {
        switch self {
        case .photo: .photo
        case .low: .low
        case .medium: .medium
        case .high: .high
        case .hd1280x720: .hd1280x720
        case .hd1920x1080: .hd1920x1080
        case .hd4K3840x2160: .hd4K3840x2160
        case .cif352x288: .cif352x288
        case .iFrame1280x720: .iFrame1280x720
        case .iFrame960x540: .iFrame960x540
        case .inputPriority: .inputPriority
        case .vga640x480: .vga640x480
        }
    }
}
