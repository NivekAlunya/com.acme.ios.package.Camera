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
            if (model.state == .loading) {
                ProcessingView().font(.largeTitle.bold())
            } else {
                ImagePreview(image: model.preview)
            }
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
                title: Text(CameraHelper.stringFrom("alert_error_camera", bundle: bundle)),
                message: Text(CameraHelper.stringFrom(model.error?.stringKey ?? "error_unknown", bundle: bundle))
                    ,
                dismissButton: .default(Text(CameraHelper.stringFrom("OK", bundle: bundle))) {
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
        @Environment(\.bundle) var bundle
        @ObservedObject var model: CameraModel
        @Binding var isSettingShown: Bool
        var onExit: () -> Void

        var body: some View {
            HStack(spacing: 16) {
                switch model.state {
                case .previewing:
                    CloseButton(onExit: onExit)
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
                case .accepted:
                    ProcessingView()
                case .unauthorized:
                    OpenSettingsButton()
                    .frame(maxWidth: .infinity)
                    CloseButton(onExit: onExit)
                        .frame(maxWidth: .infinity)
                case .loading:
                    CloseButton(onExit: onExit)
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

    struct CloseButton: View {
        @Environment(\.bundle) private var bundle
        var onExit: () -> Void
        var body: some View {
            Button(action: onExit) {
                Image(systemName: "xmark.circle")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_close_camera", bundle: bundle))
        }
    }

    
    
    struct OpenSettingsButton: View {
        @Environment(\.bundle) private var bundle
        @Environment(\.openURL) private var openURL
        var body: some View {
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                openURL(url)
            }
            label: {
                Image(systemName: "gear.badge.xmark")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_open_application_settings", bundle: bundle))

        }
    }

    struct SettingsButton: View {
        @Environment(\.bundle) private var bundle
        @Binding var isSettingShown: Bool
        var body: some View {
            Button {
                withAnimation {
                    isSettingShown.toggle()
                }
            } label: {
                Image(systemName: "gear.circle.fill")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_open_settings", bundle: bundle))
        }
    }

    struct SwitchPositionButton: View {
        @Environment(\.bundle) private var bundle
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_switch_front_back", bundle: bundle))
        }
    }

    struct TakePhotoButton: View {
        @Environment(\.bundle) private var bundle
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "circle.circle.fill")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_take_photo", bundle: bundle))
            .glassEffect(.regular)
        }
    }

    struct RejectButton: View {
        @Environment(\.bundle) private var bundle
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_reject_photo", bundle: bundle))
        }
    }

    struct AcceptButton: View {
        @Environment(\.bundle) private var bundle
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "checkmark.circle.fill")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_accept_photo", bundle: bundle))        }
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
                        Label(CameraHelper.stringFrom("option_title_quality", bundle: bundle), systemImage: "slider.horizontal.3")
                    }
                    .tag(1)

                DeviceSettingsView(model: model)
                    .tabItem {
                        Label(CameraHelper.stringFrom("option_title_camera", bundle: bundle), systemImage: "camera.on.rectangle")
                            .accentColor(Color.green)
                    }
                    .tag(2)

                FormatSettingsView(model: model)
                    .tabItem {
                        Label(CameraHelper.stringFrom("option_title_format", bundle: bundle), systemImage: "photo.badge.arrow.down")
                    }
                    .tag(3)
                FlashModeSettingsView(model: model)
                    .tabItem {
                        Label(CameraHelper.stringFrom("option_title_flash_mode", bundle: bundle), systemImage: "bolt.fill")
                    }
                    .tag(4)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.thinMaterial)
            .accentColor(color)
//            .tint(color)
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
                Section(header: Text(CameraHelper.stringFrom("option_title_quality", bundle: bundle)).bold()) {
                    ForEach(model.presets, id: \.self) { preset in
                        let selected = preset == model.selectedPreset
                        Button(action: { model.selectPreset(preset) }) {
                            HStack {
                                Text(CameraHelper.stringFrom(preset.stringKey, bundle: bundle))
                                    .fontWeight(selected ? .bold : .regular)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .fontWeight(selected ? .bold : .regular)

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
                Section(header: Text(CameraHelper.stringFrom("option_title_camera", bundle: bundle)).bold()) {

                    VStack {
                        Slider(value: Binding(
                            get: {
                                model.zoom
                            },
                            set: { value in
                                model.selectZoom(value)
                            }), in: model.zoomRange, step: 1.0) {
                            Text("")
                        }
                        Text("zoom \(model.zoom, specifier: "%.1f")x")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }.listRowSeparator(.hidden)

                    ForEach(model.devices, id: \.uniqueID) { device in
                        ListRow(text: Text(device.localizedName.uppercased()) , selected: device.uniqueID == model.selectedDevice?.uniqueID) {
                            model.selectDevice(device)
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
                Section(header: Text(CameraHelper.stringFrom("option_title_format", bundle: bundle)).bold()) {
                    ForEach(model.formats, id: \.self) { format in
                        ListRow(text: Text(CameraHelper.stringFrom(format.stringKey, bundle: bundle)) , selected: format == model.selectedFormat) {
                            model.selectFormat(format)
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
                Section(header: Text(CameraHelper.stringFrom("option_title_flash_mode", bundle: bundle)).bold()) {
                    ForEach(model.flashModes, id: \.self) { flashMode in
                        ListRow(text: Text(CameraHelper.stringFrom(flashMode.stringKey, bundle: bundle)) , selected: flashMode == model.selectedFlashMode) {
                                model.selectFlashMode(flashMode)
                            }
                    }
                }
            }
            .applySettingListStyle()

        }
    }
    
    struct ListRow: View {
        @Environment(\.bundle) var bundle
        var text: Text
        var selected = false
        var action: () -> ()
        var body: some View {
            Button(action: action ) {
                HStack {
                    text
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                    }
                }
                .fontWeight(selected ? .bold : .regular)
            }
            .listRowSeparator(.hidden)
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

