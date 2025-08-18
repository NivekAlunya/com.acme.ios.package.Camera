//
//  CameraView.swift
//  Camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//

import SwiftUI
import AVFoundation

public struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    public typealias OnComplete = (AVCapturePhoto?) -> ()
    @StateObject var model = CameraModel()
    public let completion : OnComplete?

    public init(completion: OnComplete?) {
        self.completion = completion
    }

    init(model: CameraModel) {
        _model = StateObject(wrappedValue: model)
        completion = nil
    }

    
    public var body: some View {
        ZStack {
            ImagePreview(image: model.preview)
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Spacer()
                if model.isPhotoCaptured {
                    Button {
                        model.handleRejectPhoto()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }.padding(.trailing, 16)
                    Button {
                        model.handleButtonSelectPhoto()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                        
                } else {
                    Button {
                        model.handleButtonExit()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    Spacer()
                    Button {
                        model.handleButtonPhoto()
                    } label: {
                        Image(systemName: "camera.circle")
                    }

                }
            }
            .font(.largeTitle)
            .symbolRenderingMode(.multicolor)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(maxWidth: .infinity)
            .background {
                Color.black.opacity(0.25)
                    .ignoresSafeArea(edges: [.bottom, .trailing, .leading])
            }
        }
        .task {
            await model.configure()
            await model.startStreaming()
        }
        .onChange(of: model.capture) {
            completion?(model.capture)
            dismiss()
        }
        
    }
}

struct ImagePreview: View {
    var image: Image?
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

#Preview {
    // Example of using CameraView with a custom model
    let ciImage = CIImage(color: .red).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
    let mock = MockCamera(previewImages: [ciImage], photoImages: [])
    return CameraView(model: CameraModel(camera: mock))
}

#Preview(traits: .landscapeLeft) {
    CameraView {_ in 
        
    }
}
