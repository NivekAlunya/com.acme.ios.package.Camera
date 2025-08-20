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
                if model.isPhotoCaptured {
                    Spacer()
                    Button {
                        model.handleRejectPhoto()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel("Reject Photo")
                    .padding(.trailing, 16)
                    Button {
                        model.handleButtonSelectPhoto()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .accessibilityLabel("Accept Photo")
                        
                } else {
                    Picker("Select preset", selection: $model.preset) {
                        ForEach(0 ..< model.presets.count) { index in
                            Text("\(model.presets[index].name)")
                                .foregroundStyle(Color.white)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Button {
                        model.handleButtonExit()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close Camera")
                    Spacer()
                    Button {
                        model.handleSwitchPosition()
                    } label: {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera")
                    }
                    .accessibilityLabel("Switch Camera")
                    Spacer()
                    Button {
                        model.handleButtonPhoto()
                    } label: {
                        Image(systemName: "camera.circle")
                    }
                    .accessibilityLabel("Take Photo")

                }
            }
            .font(.largeTitle)
            .symbolRenderingMode(.multicolor)
            .padding(.horizontal)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background {
                Color.black.opacity(0.5)
                    .ignoresSafeArea(edges: [.bottom, .trailing, .leading])
            }
        }
        .task {
            await model.start()
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
            if let image = image {
                image
                    .resizable()
                    .scaledToFit()
                    .fitToParent()
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
    let ciImage = CIImage(color: .red).cropped(to: .init(x: 0, y: 0, width: 1, height: 1))
    let mock = MockCamera(previewImages: [ciImage], photoImages: [])
    return CameraView(model: CameraModel(camera: mock))
}
