//
//  NativePreviewView.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation
import SwiftUI
import UIKit

/// A custom UIView that manages the AVCaptureVideoPreviewLayer frame.
private class PreviewLayerView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

/// A SwiftUI wrapper for `AVCaptureVideoPreviewLayer`.
public struct NativePreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeUIView(context: Context) -> UIView {
        let view = PreviewLayerView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PreviewLayerView else { return }
        view.previewLayer?.session = session
    }
    
    public static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        guard let view = uiView as? PreviewLayerView else { return }
        view.previewLayer?.session = nil
    }
}
