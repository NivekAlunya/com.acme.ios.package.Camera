//
//  CameraView.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation
import SwiftUI

extension EnvironmentValues {
    @Entry var bundle: Bundle = .module
}

public struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    public typealias OnComplete = (AVCapturePhoto?, CameraConfiguration?) -> Void
    @StateObject var model: CameraModel
    @State var isSettingShown = false
    @State private var showErrorAlert = false
    public let bundle: Bundle
    public let completion: OnComplete?

    public init(bundle: Bundle? = nil, camera: Camera = Camera(), completion: OnComplete?) {
        let resolvedBundle = bundle ?? Bundle.module
        self.completion = completion
        self.bundle = resolvedBundle
        _model = StateObject(wrappedValue: CameraModel(camera: camera))
    }

    init(model: CameraModel) {
        self.completion = nil
        _model = StateObject(wrappedValue: model)
        self.bundle = .module
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
        .environment(\.bundle, bundle)
    }
}

extension CameraView {
    struct FooterView: View {
        @Environment(\.openURL) private var openURL
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
                case .unauthorized:
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        openURL(url)
                    }
                    label: {
                        Image(systemName: "gear.badge.xmark")
                    }
                    .accessibilityLabel("Close Camera")
                    .frame(maxWidth: .infinity)
                    Button(action: onExit) {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Close Camera")
                    .frame(maxWidth: .infinity)
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
        @Environment(\.bundle) var bundle
        @ObservedObject var model: CameraModel
        @State private var tabSelection = 1
        @State private var color = Color.blue
        var body: some View {
            TabView(selection: $tabSelection) {
                PresetSettingsView(model: model)
                    .tabItem {
                        Label(CameraHelper.stringFrom("option title quality", bundle: bundle), systemImage: "slider.horizontal.3")
                    }
                    .tag(1)

                DeviceSettingsView(model: model)
                    .tabItem {
                        Label(CameraHelper.stringFrom("option title camera", bundle: bundle), systemImage: "camera.on.rectangle")
                            .accentColor(Color.green)
                    }
                    .tag(2)

                FormatSettingsView(model: model)
                    .tabItem {
                        Label(CameraHelper.stringFrom("option title format", bundle: bundle), systemImage: "photo.badge.arrow.down")
                    }
                    .tag(3)
                FlashModeSettingsView(model: model)
                    .tabItem {
                        Label(CameraHelper.stringFrom("option title flash mode", bundle: bundle), systemImage: "bolt.fill")
                    }
                    .tag(4)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.thinMaterial)
            .accentColor(color)
            .tint(color)
            .onChange(of: tabSelection) {
                color = switch tabSelection {
                case 1: .blue
                case 2: .green
                case 3: .red
                case 4: .yellow
                default:
                        .black
                }
            }
        }
    }

    struct PresetSettingsView: View {
        @Environment(\.bundle) var bundle
        @ObservedObject var model: CameraModel

        var body: some View {
            List {
                Section(header: Text(CameraHelper.stringFrom("option title quality", bundle: bundle)).bold()) {
                    ForEach(model.presets, id: \.self) { preset in
                        Button(action: { model.selectPreset(preset) }) {
                            HStack {
                                Text(CameraHelper.stringFrom(preset.stringKey, bundle: bundle))
                                Spacer()
                                if preset == model.selectedPreset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .applySettingListStyle()

        }
    }

    struct DeviceSettingsView: View {
        @Environment(\.bundle) var bundle
        @ObservedObject var model: CameraModel
        var body: some View {
            List {
                Section(header: Text(CameraHelper.stringFrom("option title camera", bundle: bundle)).bold()) {

                    VStack {
                        Slider(
                            value: Binding(
                                get: {
                                    model.zoom
                                },
                                set: { value in
                                    model.selectZoom(value)
                                }), in: model.zoomRange, step: 1
                        ) {
                            Text("")
                        }
                        
                        Text("zoom \(model.zoom, specifier: "%.1f")x")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }

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
            .applySettingListStyle()

        }
    }

    struct FormatSettingsView: View {
        @Environment(\.bundle) var bundle
        @ObservedObject var model: CameraModel

        var body: some View {
            List {
                Section(header: Text(CameraHelper.stringFrom("option title format", bundle: bundle)).bold()) {
                    ForEach(model.formats, id: \.self) { format in
                        Button(action: { model.selectFormat(format) }) {
                            HStack {
                                Text(CameraHelper.stringFrom(format.stringKey, bundle: bundle))
                                Spacer()
                                if format == model.selectedFormat {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .applySettingListStyle()
        }
    }

    struct FlashModeSettingsView: View {
        @Environment(\.bundle) var bundle
        @ObservedObject var model: CameraModel

        var body: some View {
            List {
                Section(header: Text(CameraHelper.stringFrom("option title flash mode", bundle: bundle)).bold()) {
                    ForEach(model.flashModes, id: \.self) { flashMode in
                        Button(action: { model.selectFlashMode(flashMode) }) {
                            HStack {
                                Text(CameraHelper.stringFrom(flashMode.stringKey, bundle: bundle))
                                Spacer()
                                    if flashMode == model.selectedFlashMode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .applySettingListStyle()

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

