//
//  VideoCodecType.swift
//  Camera
//
//  Created by Kevin LAUNAY on 21/08/2024.
//

import AVFoundation

/// A wrapper enum for `AVVideoCodecType` to provide a `CaseIterable` and more convenient interface.
public enum VideoCodecType: CaseIterable, Sendable {
    case JPEGXL
    case appleProRes4444XQ
    case h264
    case hevc
    case hevcWithAlpha
    case jpeg
    case proRes422
    case proRes422HQ
    case proRes422LT
    case proRes422Proxy
    case proRes4444
    
    /// Failable initializer that creates a `VideoCodecType` from an `AVVideoCodecType`.
    /// - Parameter avVideoCodecType: The `AVVideoCodecType` to convert.
    init?(avVideoCodecType: AVVideoCodecType) {
        switch avVideoCodecType {
        case .JPEGXL: self = .JPEGXL
        case .appleProRes4444XQ: self = .appleProRes4444XQ
        case .h264: self = .h264
        case .hevc: self = .hevc
        case .hevcWithAlpha: self = .hevcWithAlpha
        case .jpeg: self = .jpeg
        case .proRes422: self = .proRes422
        case .proRes422HQ: self = .proRes422HQ
        case .proRes422LT: self = .proRes422LT
        case .proRes422Proxy: self = .proRes422Proxy
        case .proRes4444: self = .proRes4444
        default:
            return nil
        }
    }
    
    /// A computed property that returns a localization key for each codec type.
    var stringKey: String {
        switch self {
        case .JPEGXL: "codec_JPEGXL"
        case .appleProRes4444XQ: "codec_appleProRes4444XQ"
        case .h264: "codec_h264"
        case .hevc: "codec_hevc"
        case .hevcWithAlpha: "codec_hevcWithAlpha"
        case .jpeg: "codec_jpeg"
        case .proRes422: "codec_proRes422"
        case .proRes422HQ: "codec_proRes422HQ"
        case .proRes422LT: "codec_proRes422LT"
        case .proRes422Proxy: "codec_proRes422Proxy"
        case .proRes4444: "codec_proRes4444"
        }
    }
    
    /// The corresponding `AVVideoCodecType`.
    var avVideoCodecType: AVVideoCodecType {
        switch self {
        case .JPEGXL: .JPEGXL
        case .appleProRes4444XQ: .appleProRes4444XQ
        case .h264: .h264
        case .hevc: .hevc
        case .hevcWithAlpha: .hevcWithAlpha
        case .jpeg: .jpeg
        case .proRes422: .proRes422
        case .proRes422HQ: .proRes422HQ
        case .proRes422LT: .proRes422LT
        case .proRes422Proxy: .proRes422Proxy
        case .proRes4444: .proRes4444
        }
    }
}
