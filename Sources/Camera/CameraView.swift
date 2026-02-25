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
    public typealias OnComplete = (PhotoCapture?, CameraConfiguration?) -> Void

    /// The view model that manages the camera state.
    private let model: CameraModel

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
    ///   - cameraConfig: The camera configuration to use. Defaults to a new `CameraConfiguration` instance.
    ///   - dismissOnComplete: Whether to dismiss the view automatically on completion. Defaults to `true`.
    ///   - completion: The closure to call upon completion.
    public init(bundle: Bundle? = nil, cameraConfig: CameraConfiguration = CameraConfiguration(), dismissOnComplete: Bool = true, completion: OnComplete?) {
        let resolvedBundle = bundle ?? Bundle.module
        self.completion = completion
        self.bundle = resolvedBundle
        self.dismissOnComplete = dismissOnComplete
        self.model = CameraModel(camera: Camera(config: cameraConfig))
    }

    /// Internal initializer for previews and testing.
    init(model: CameraModel, dismissOnComplete: Bool = true) {
        self.completion = nil
        self.bundle = .module
        self.dismissOnComplete = dismissOnComplete
        self.model = model
    }

    public var body: some View {
        GeometryReader { reader in
            ZStack {
                ImagePreview(image: model.preview)
                    .overlay(alignment: .center) {
                        if reader.size.width > 0 && reader.size.height > 0,
                           let targetSize = model.ratio.targetSize(for: reader.size) {
                            ZStack {
                                Color.black.opacity(0.8)
                                Rectangle()
                                    .blendMode(.destinationOut)
                                    .frame(width: targetSize.width, height: targetSize.height)
                            }
                            .compositingGroup()
                        }
                    }

            }
            .background(Color(UIColor.systemBackground))
            
        }
        .overlay {
            switch model.state {
            case .processing:
                ProcessingView()
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding()
                    .background(.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            default:
                EmptyView()
            }
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            FooterView(model: model, isSettingShown: $isSettingShown) {
                Task { await model.handleExit() }
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
        .colorScheme(.dark) // Force dark mode for better camera preview visibility

    }
}

// MARK: - Subviews
extension CameraView {

    /// The footer view that contains the main camera controls.
    /// The controls shown depend on the current state of the `CameraModel`.
    struct FooterView: View {
        @Namespace private var namespace
        @Environment(\.bundle) var bundle
        let model: CameraModel
        @Binding var isSettingShown: Bool
        var onCancel: (() -> Void)

        var body: some View {
            GlassEffectContainer {
                HStack(spacing: 16) {
                    Group {
                        switch model.state {
                        case .previewing:
                            CancelButton(onCancel: onCancel)
                            SettingsButton(isSettingShown: $isSettingShown)
                            SwitchRatioButton(ratio: model.ratio) {
                                Task { await model.handleSwitchRatio() }
                            }
                            SwitchPositionButton {
                                Task { await model.handleSwitchPosition() }
                            }
                            TakePhotoButton {
                                Task { await model.handleTakePhoto() }
                            }

                        case .processing, .loading, .accepted:
                            EmptyView()
                        case .validating:
                            RejectButton {
                                Task { await model.handleRejectPhoto() }
                            }
                            .frame(maxWidth: .infinity)
                            AcceptButton {
                                Task { await model.handleAcceptPhoto() }
                            }
                            .frame(maxWidth: .infinity)
                        case .unauthorized:

                            OpenSettingsButton()
                                .frame(maxWidth: .infinity)
                            CancelButton(onCancel: onCancel)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding()
                    .font(.title.bold())
                    .glassEffect(.clear)
                    .glassEffectUnion(id: 1, namespace: namespace)
                }
                .padding()
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
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_switch_front_back", bundle: bundle))
        }
    }

    struct SwitchRatioButton: View {
        @Environment(\.bundle) private var bundle
        let ratio: CaptureSessionAspectRatio
        var action: () -> Void
        var body: some View {
            Button(action: action) {
                Image(systemName: ratio.getSfSymbol())
            }
            .accessibilityLabel(CameraHelper.stringFrom("accessibility_switch_ratio", bundle: bundle))
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

#if DEBUG

class CameraModelMock: CameraModel {
    override init(camera: any CameraProtocol = MockCamera()) {
        super.init(camera: camera)
        self.state = .previewing
        self.preview = Image(systemName: "camera.fill")
    }
    
    override func start() async {
        // No-op for mock
    }
    
    override func stop() async {
        // No-op for mock
        state = .loading
    }
    override func handleTakePhoto() async {
        // No-op for mock
        state = .validating
    }

    
}

#Preview {
    let cameraModel = CameraModelMock()

    return ZStack {
        CameraView(model: cameraModel)
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.red)
}

#Preview(traits: .landscapeLeft) {
    let cameraModel = CameraModelMock()
    return CameraView(model: cameraModel)
}
#endif // DEBUG
