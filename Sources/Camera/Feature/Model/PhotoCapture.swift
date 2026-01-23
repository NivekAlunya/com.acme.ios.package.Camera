//
//  PhotoCapture.swift
//  Camera
//
//  Created by Kevin Launay on 22/01/2026.
//

import Foundation

public struct PhotoCapture:  @unchecked Sendable {
    public let data: Data?
    public let metadata: [String: Any]?
}
