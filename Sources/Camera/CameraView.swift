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
    @State var isSettingShown = false
    public let completion : OnComplete?
    
    public init(completion: OnComplete?) {
        self.completion = completion
    }

    init(model: CameraModel) {
        _model = StateObject(wrappedValue: model)
        completion = nil
    }
    
    var buttonReject: some View {
        Button {
            withAnimation {
                model.handleRejectPhoto()
            }
        } label: {
            Image(systemName: "xmark.circle.fill")
        }
        .accessibilityLabel("Reject Photo")
        .padding(.trailing, 16)
    }
    
    var buttonAccept: some View {
        Button {
            withAnimation {
                model.handleButtonSelectPhoto()
            }
        } label: {
            Image(systemName: "checkmark.circle.fill")
        }
        .accessibilityLabel("Accept Photo")
    }
    
    var buttonSettings: some View {
        Button {
            withAnimation {
                isSettingShown.toggle()
                
            }
        } label: {
            Image(systemName: "gear.circle.fill")
        }
        .accessibilityLabel("Oprn settings")
    }
    var buttonSwitchPosition: some View {
        Button {
            withAnimation {
                model.handleSwitchPosition()
            }
        } label: {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera")
        }
        .accessibilityLabel("Switch Camera")
    }
    
    var buttonTakePhoto: some View {
        Button {
            withAnimation {
                model.handleButtonPhoto()
            }
        } label: {
            Image(systemName: "circle.circle.fill")
        }
        .accessibilityLabel("Take Photo")
    }

    var buttonSwitchFlash: some View {
        Button {
            withAnimation {
                model.handleButtonPhoto()
            }
        } label: {
            Image(systemName: "bolt")
        }
        .accessibilityLabel("Set Flash")
        
        
        //bolt.fill
        
    }

    
    
    public var body: some View {
        ZStack {
            ImagePreview(image: model.preview)
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 16) {
                Spacer()
                Button {
                    model.handleButtonExit()
                    dismiss()
                    completion?(nil)
                } label: {
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
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                switch model.state {
                    case .previewing:
                    Spacer()
                        buttonSettings
                    Spacer()
                        buttonSwitchPosition
                    Spacer()
                        buttonTakePhoto
                    case .processing:
                        Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.orange)
                        .symbolEffect(.rotate)
                    case .validating:
                    Spacer()
                        buttonReject
                        buttonAccept
                    
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
        .task {
            await model.start()
        }
        .onChange(of: model.capture) {
            completion?(model.capture)
            dismiss()
        }
        .sheet(isPresented: $isSettingShown) {
            SettingsView(model: model)
        }
    }
}

struct SettingsView: View {
    @StateObject var model: CameraModel
    var body: some View {
        TabView {
            List {
                Section(header: Text("Output Quality").font(.largeTitle).bold()) {
                    ForEach(0 ..< model.presets.count) { index in
                        Label {
                            Text("\(model.presets[index].name)".uppercased())
                        } icon: {
                            if (index == model.presetSelected) {
                                Image(systemName: "checkmark")
                            } else {
                                Color.clear
                            }
                        }
                        .onTapGesture {
                            withAnimation {
                                model.handleSelectIndexPreset(index)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .listRowSeparator(.hidden)
                .refreshable {
                    //await mailbox.fetch()
                }
                
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .tabItem {
                Image(systemName: "slider.horizontal.3")
            }
            List {
                Section(header: Text("Devices").font(.largeTitle).bold()) {
                    ForEach(0 ..< model.devices.count) { index in
                        Label {
                            Text("\(model.devices[index].localizedName)".uppercased())
                        } icon: {
                            if (index == model.deviceSelected) {
                                Image(systemName: "checkmark")
                            } else {
                                Color.clear
                            }
                        }
                        .onTapGesture {
                            withAnimation {
                                model.handleSelectIndexDevice(index)
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
            List {
                Section(header: Text("Formats").font(.largeTitle).bold()) {
                    ForEach(0 ..< model.formats.count) { index in
                        Label {
                            Text("\(model.formats[index])".uppercased())
                        } icon: {
                            if (index == model.formatSelected) {
                                Image(systemName: "checkmark")
                            } else {
                                Color.clear
                            }
                        }
                        .onTapGesture {
                            withAnimation {
                                model.handleSelectIndexFormat(index)
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
        .presentationDetents([ .medium, .large])
        .presentationBackground(.clear)
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
