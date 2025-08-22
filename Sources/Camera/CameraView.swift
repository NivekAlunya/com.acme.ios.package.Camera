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

    @StateObject var model: CameraModel

    @State var isSettingShown = false
    @State private var showErrorAlert = false

    public let completion : OnComplete?
    
    public init(completion: OnComplete?) {
        self.completion = completion
        _model = StateObject(wrappedValue: CameraModel())
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
        .safeAreaInset(edge: .top) {
            HeaderView(onExit: {
                model.handleExit()
                dismiss()
                completion?(nil)
            })
        }
        .safeAreaInset(edge: .bottom) {
            FooterView(model: model, isSettingShown: $isSettingShown)
        }
        .task {
            await model.start()
        }
        .onChange(of: model.capture) {
            completion?(model.capture)
            dismiss()
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

struct HeaderView: View {
    var onExit: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            Button(action: onExit) {
                Image(systemName: "xmark.circle")
            }
            .accessibilityLabel("Close Camera")
        }
        .font(.largeTitle)
        .symbolRenderingMode(.multicolor)
        .padding(.horizontal)
        .padding(.top)
        .frame(maxWidth: .infinity)
        .background {
            Color.black.opacity(0.5)
                .ignoresSafeArea(edges: [.top, .trailing, .leading])
        }
    }
}

struct FooterView: View {
    @ObservedObject var model: CameraModel
    @Binding var isSettingShown: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            switch model.state {
            case .previewing:
                Spacer()
                SettingsButton(isSettingShown: $isSettingShown)
                Spacer()
                SwitchPositionButton(action: model.handleSwitchPosition)
                Spacer()
                TakePhotoButton(action: model.handleTakePhoto)
            case .processing:
                ProcessingView()
            case .validating:
                Spacer()
                RejectButton(action: model.handleRejectPhoto)
                AcceptButton(action: model.handleAcceptPhoto)
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
            DeviceSettingsView(model: model)
            FormatSettingsView(model: model)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.clear)
    }
}

struct PresetSettingsView: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        List {
            Section(header: Text("Output Quality").font(.largeTitle).bold()) {
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
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .tabItem {
            Image(systemName: "slider.horizontal.3")
        }
    }
}

struct DeviceSettingsView: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        List {
            Section(header: Text("Devices").font(.largeTitle).bold()) {
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
        .background(Color.clear)
        .scrollContentBackground(.hidden)
        .tabItem {
            Image(systemName: "camera.on.rectangle")
        }
    }
}

struct FormatSettingsView: View {
    @ObservedObject var model: CameraModel

    var body: some View {
        List {
            Section(header: Text("Formats").font(.largeTitle).bold()) {
                ForEach(model.formats, id: \.self) { format in
                    Button(action: { model.selectFormat(format) }) {
                        HStack {
                            Text(format.rawValue.uppercased())
                            Spacer()
                            if format == model.selectedFormat {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .scrollContentBackground(.hidden)
        .tabItem {
            Image(systemName: "photo.badge.arrow.down")
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
    let mockCamera = MockCamera()
    let cameraModel = CameraModel(camera: mockCamera)
    return CameraView(model: cameraModel)
}

#Preview(traits: .landscapeLeft) {
    let mockCamera = MockCamera()
    let cameraModel = CameraModel(camera: mockCamera)
    return CameraView(model: cameraModel)
}
