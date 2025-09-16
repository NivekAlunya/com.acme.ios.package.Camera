//
//  CameraView.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import AVFoundation
import SwiftUI

/// A helper to make the app's bundle available in the environment.
extension EnvironmentValues {
    @Entry var bundle: Bundle = .module
}

/// The main SwiftUI view for the camera interface.
/// It provides a full-screen camera preview, controls for taking photos, and a settings sheet.
public struct CameraView: View {

    /// A closure that is called when the user finishes the capture flow.
    /// - Parameters:
    ///   - photo: The captured `Photo`, or `nil` if the user cancels.
    ///   - config: The `CameraConfiguration` at the time of capture.
    public typealias OnComplete = ((any PhotoData)?, CameraConfiguration?) -> Void

    /// The view model that manages the camera state.
    private var model: CameraModel

    /// A state variable to control the visibility of the settings sheet.
    @State private var isSettingShown = false

    /// A state variable to control the visibility of the error alert.
    @State private var showErrorAlert = false

    /// The bundle to use for localizing strings.
    public let bundle: Bundle

    public let dismissOnComplete: Bool
    
    /// The completion handler to call when the flow is finished.
    public let completion: OnComplete?

    /// Initializes a new `CameraView`.
    /// - Parameters:
    ///   - bundle: The bundle for string localization. Defaults to `.module`.
    ///   - completion: The closure to call upon completion.
    public init(bundle: Bundle? = nil, dismissOnComplete: Bool = true, completion: OnComplete?) {
        let resolvedBundle = bundle ?? Bundle.module
        self.completion = completion
        self.bundle = resolvedBundle
        self.dismissOnComplete = dismissOnComplete
        self.model = CameraModel()
    }

    /// Internal initializer for previews and testing.
    init(model: CameraModel, dismissOnComplete: Bool = true) {
        self.completion = nil
        self.bundle = .module
        self.dismissOnComplete = dismissOnComplete
        self.model = model
    }

    public var body: some View {
        ZStack {
            if model.state == .loading {
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
                completion?(nil, nil)
            }
        }
        .task {
            print("CameraView appeared for the first time, starting camera...")
            await model.start()
        }
        .onDisappear {
            print("CameraView disappeared, stopping camera...")
            Task {
                await model.stop()
            }
        }
        .onChange(of: model.state) {
            if case .accepted(let accepted) = model.state {
                completion?(accepted.photo, accepted.config)
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
                message: Text(CameraHelper.stringFrom(model.error?.stringKey ?? "error_unknown", bundle: bundle)),
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

// MARK: - Subviews
extension CameraView {

    /// The footer view that contains the main camera controls.
    /// The controls shown depend on the current state of the `CameraModel`.
    struct FooterView: View {
        @Environment(\.bundle) var bundle
        let model: CameraModel
        @Binding var isSettingShown: Bool
        var onCancel: (() -> Void)

        var body: some View {
            HStack(spacing: 16) {
                switch model.state {
                case .previewing:
                    CancelButton(onCancel: onCancel)
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
                    CancelButton(onCancel: onCancel)
                        .frame(maxWidth: .infinity)
                case .loading:
                    CancelButton(onCancel: onCancel)
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

    /// A button to close the camera view.
    struct CancelButton: View {
        @Environment(\.bundle) private var bundle
        var onCancel: () -> Void
        var body: some View {
            Button(action: onCancel) {
                Image(systemName: "xmark.circle")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_close_camera", bundle: bundle))
        }
    }
    
    /// A button to open the application's settings in case of authorization issues.
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

    /// A button to show the settings sheet.
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

    /// A button to switch between the front and back cameras.
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

    /// The main button to capture a photo.
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

    /// A button to reject a captured photo.
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

    /// A button to accept a captured photo.
    struct AcceptButton: View {
        @Environment(\.bundle) private var bundle
        var action: () -> Void
        var body: some View {
            Button(action: action) {
                Image(systemName: "checkmark.circle.fill")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_accept_photo", bundle: bundle))
        }
    }

    /// A view that shows a rotating activity indicator.
    struct ProcessingView: View {
        var body: some View {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(Color.orange)
                .symbolEffect(.rotate)
        }
    }

    /// The settings view, presented as a sheet, containing various camera options in a tab view.
    struct SettingsView: View {
        @Environment(\.bundle) var bundle
        let model: CameraModel
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

    /// A settings view for selecting the capture session preset (quality).
    struct PresetSettingsView: View {
        @Environment(\.bundle) var bundle
        let model: CameraModel
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

    /// A settings view for selecting the camera device and zoom factor.
    struct DeviceSettingsView: View {
        @Environment(\.bundle) var bundle
        let model: CameraModel
        var body: some View {
            List {
                Section(header: Text(CameraHelper.stringFrom("option_title_camera", bundle: bundle)).bold()) {
                    VStack {
                        Slider(value: Binding(
                            get: { model.zoom },
                            set: { value in model.selectZoom(value) }),
                               in: model.zoomRange,
                               step: 1.0)
                        Text("zoom \(model.zoom, specifier: "%.1f")x")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }.listRowSeparator(.hidden)

                    ForEach(model.devices, id: \.uniqueID) { device in
                        ListRow(text: Text(device.localizedName.uppercased()),
                                selected: device.uniqueID == model.selectedDevice?.uniqueID) {
                            model.selectDevice(device)
                        }
                    }
                }
            }
            .applySettingListStyle()
        }
    }

    /// A settings view for selecting the video codec format.
    struct FormatSettingsView: View {
        @Environment(\.bundle) var bundle
        let model: CameraModel
        var body: some View {
            List {
                Section(header: Text(CameraHelper.stringFrom("option_title_format", bundle: bundle)).bold()) {
                    ForEach(model.formats, id: \.self) { format in
                        ListRow(text: Text(CameraHelper.stringFrom(format.stringKey, bundle: bundle)),
                                selected: format == model.selectedFormat) {
                            model.selectFormat(format)
                        }
                    }
                }
            }
            .applySettingListStyle()
        }
    }

    /// A settings view for selecting the flash mode.
    struct FlashModeSettingsView: View {
        @Environment(\.bundle) var bundle
        let model: CameraModel
        var body: some View {
            List {
                Section(header: Text(CameraHelper.stringFrom("option_title_flash_mode", bundle: bundle)).bold()) {
                    ForEach(model.flashModes, id: \.self) { flashMode in
                        ListRow(text: Text(CameraHelper.stringFrom(flashMode.stringKey, bundle: bundle)),
                                selected: flashMode == model.selectedFlashMode) {
                            model.selectFlashMode(flashMode)
                        }
                    }
                }
            }
            .applySettingListStyle()
        }
    }
    
    /// A generic list row for settings screens.
    struct ListRow: View {
        @Environment(\.bundle) var bundle
        var text: Text
        var selected = false
        var action: () -> Void
        var body: some View {
            Button(action: action) {
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

    /// A view to display the camera preview or the captured photo preview.
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
