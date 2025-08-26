//
//  CameraView.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import SwiftUI
import AVFoundation

public struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    public typealias OnComplete = (AVCapturePhoto?, CameraConfiguration?) -> ()

    @StateObject var model: CameraModel
    @State var isSettingShown = false
    @State private var showErrorAlert = false

    public let completion : OnComplete?
    
    public init(camera: Camera = Camera(), completion: OnComplete?) {
        self.completion = completion
        _model = StateObject(wrappedValue: CameraModel(camera: camera))
    }

    init(model: CameraModel) {
        self.completion = nil
        _model = StateObject(wrappedValue: model)
    }
    
    public var body: some View {
        ZStack {
            ImagePreview(image: model.preview)
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .safeAreaInset(edge: .bottom) {
            FooterView(model: model, isSettingShown: $isSettingShown) {
                model.handleExit()
                dismiss()
                completion?(nil, nil)
            }
        }
        .task {
            await model.start()
        }
        .onChange(of: model.state) {
            if case .accepted(let accepted) = model.state {
                completion?(accepted.photo, accepted.config)
                dismiss()
            }
        }
        .onChange(of: model.error) {
            if model.error != nil {
                showErrorAlert = true
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Camera Error"),
                message: Text(model.error?.localizedDescription ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK")) {
                    model.error = nil
                }
            )
        }
        .sheet(isPresented: $isSettingShown) {
            SettingsView(model: model)
        }
    }
}

extension CameraView {
    struct FooterView: View {
        @ObservedObject var model: CameraModel
        @Binding var isSettingShown: Bool
        var onExit: () -> Void

        var body: some View {
            HStack(spacing: 16) {
                switch model.state {
                case .previewing:
                    Button(action: onExit) {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Close Camera")
                    .frame(maxWidth: .infinity)
                    SettingsButton(isSettingShown: $isSettingShown)
                        .frame(maxWidth: .infinity)
                    SwitchPositionButton(action: model.handleSwitchPosition)
                        .frame(maxWidth: .infinity)
                    TakePhotoButton(action: model.handleTakePhoto)
                        .frame(maxWidth: .infinity)
                case .processing:
                    ProcessingView()
                case .validating:
                    RejectButton(action: model.handleRejectPhoto)
                        .frame(maxWidth: .infinity)
                    AcceptButton(action: model.handleAcceptPhoto)
                        .frame(maxWidth: .infinity)
                case .accepted((let photo, let config)):
                    EmptyView()
                }
            }
            .font(.largeTitle)
            .symbolRenderingMode(.multicolor)
            .padding(.horizontal)
            .padding(.top)
            .frame(maxWidth: .infinity)
            .background {
                Color.black.opacity(0.5)
                    .ignoresSafeArea(edges: [.bottom, .trailing, .leading])
            }
            
        }
    }

    struct SettingsButton: View {
        @Binding var isSettingShown: Bool
        var body: some View {
            Button {
                withAnimation {
                    isSettingShown.toggle()
                }
            } label: {
                Image(systemName: "gear.circle.fill")
            }
            .accessibilityLabel("Open settings")
        }
    }

    struct SwitchPositionButton: View {
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
            }
            .accessibilityLabel("Switch Camera")
        }
    }

    struct TakePhotoButton: View {
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Image(systemName: "circle.circle.fill")
            }
            .accessibilityLabel("Take Photo")
            .glassEffect(.regular)
        }
    }

    struct RejectButton: View {
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
            }
            .accessibilityLabel("Reject Photo")
        }
    }

    struct AcceptButton: View {
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "checkmark.circle.fill")
            }
            .accessibilityLabel("Accept Photo")
        }
    }

    struct ProcessingView: View {
        var body: some View {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(Color.orange)
                .symbolEffect(.rotate)
        }
    }

    struct SettingsView: View {
        @ObservedObject var model: CameraModel

        var body: some View {
            TabView {
                PresetSettingsView(model: model)
                    .tabItem {
                        Image(systemName: "slider.horizontal.3")
                    }

                DeviceSettingsView(model: model)
                    .tabItem {
                        Image(systemName: "camera.on.rectangle")
                    }
                
                FormatSettingsView(model: model)
                    .tabItem {
                        Image(systemName: "photo.badge.arrow.down")
                    }

            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.clear)
        }
    }

    struct PresetSettingsView: View {
        @ObservedObject var model: CameraModel

        var body: some View {
            List {
                Section(header: Text("Output Quality").bold()) {
                    ForEach(model.presets, id: \.self) { preset in
                        Button(action: { model.selectPreset(preset) }) {
                            HStack {
                                Text(preset.name.uppercased())
                                Spacer()
                                if preset == model.selectedPreset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .listRowSeparator(.hidden)
            }
        }
    }

    struct DeviceSettingsView: View {
        @ObservedObject var model: CameraModel

        var body: some View {
            List {
                Section(header: Text("Devices").bold()) {
                    ForEach(model.devices, id: \.uniqueID) { device in
                        Button(action: { model.selectDevice(device) }) {
                            HStack {
                                Text(device.localizedName.uppercased())
                                Spacer()
                                if device.uniqueID == model.selectedDevice?.uniqueID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    struct FormatSettingsView: View {
        @ObservedObject var model: CameraModel

        var body: some View {
            List {
                Section(header: Text("Formats").bold()) {
                    ForEach(model.formats, id: \.self) { format in
                        Button(action: { model.selectFormat(format) }) {
                            HStack {
                                Text(format.name.uppercased())
                                Spacer()
                                if format == model.selectedFormat {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
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
}

#Preview {
    let mockCamera = MockCamera()
    let cameraModel = CameraModel(camera: mockCamera)
    return CameraView(model: cameraModel)
}

#Preview(traits: .landscapeLeft) {
    let mockCamera = MockCamera()
    let cameraModel = CameraModel(camera: mockCamera)
    return CameraView(model: cameraModel)
}
