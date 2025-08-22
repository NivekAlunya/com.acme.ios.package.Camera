//
//  VideoCodecType.swift
//  Camera
//
//  Created by Kevin LAUNAY on 21/08/2025.
//

import AVFoundation

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
    
    init?(avVideoCodecType: AVVideoCodecType) {
        switch avVideoCodecType {
        case .JPEGXL : self = .JPEGXL
        case .appleProRes4444XQ : self = .appleProRes4444XQ
        case .h264 : self = .h264
        case .hevc : self = .hevc
        case .hevcWithAlpha : self = .hevcWithAlpha
        case .jpeg : self = .jpeg
        case .proRes422 : self = .proRes422
        case .proRes422HQ : self = .proRes422HQ
        case .proRes422LT : self = .proRes422LT
        case .proRes422Proxy : self = .proRes422Proxy
        case .proRes4444 : self = .proRes4444
        default:
            return nil
        }
    }
    
    var name: String {
        return switch self {
        case .JPEGXL : "JPEGXL"
        case .appleProRes4444XQ : "appleProRes4444XQ"
        case .h264 : "h264"
        case .hevc : "hevc"
        case .hevcWithAlpha : "hevcWithAlpha"
        case .jpeg : "jpeg"
        case .proRes422 : "proRes422"
        case .proRes422HQ : "proRes422HQ"
        case .proRes422LT : "proRes422LT"
        case .proRes422Proxy : "proRes422Proxy"
        case .proRes4444 : "proRes4444"
        }
    }
    
    var avVideoCodecType: AVVideoCodecType {
        return switch self {
        case .JPEGXL : AVVideoCodecType.JPEGXL
        case .appleProRes4444XQ : AVVideoCodecType.appleProRes4444XQ
        case .h264 : AVVideoCodecType.h264
        case .hevc : AVVideoCodecType.hevc
        case .hevcWithAlpha : AVVideoCodecType.hevcWithAlpha
        case .jpeg : AVVideoCodecType.jpeg
        case .proRes422 : AVVideoCodecType.proRes422
        case .proRes422HQ : AVVideoCodecType.proRes422HQ
        case .proRes422LT : AVVideoCodecType.proRes422LT
        case .proRes422Proxy : AVVideoCodecType.proRes422Proxy
        case .proRes4444 : AVVideoCodecType.proRes4444
        }
    }
}
