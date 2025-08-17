//
//  CameraView.swift
//  Camera
//
//  Created by Kevin LAUNAY on 12/08/2025.
//

import SwiftUI

public struct CameraView: View {
    @StateObject var model = CameraModel()
    
    public init() {
        
    }
    
    public var body: some View {
        ZStack {
            ImagePreview(image: model.preview)
        }
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .safeAreaInset(edge: .bottom) {
            HStack() {
                Spacer()
                Button {
                    model.handleButtonPhoto()
                } label: {
                    Image(systemName: "camera.circle")
                        .frame(width:80, height: 80)
                }
            }.padding(8)
        }
        .task {
            await model.configureAndStart()
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
    CameraView()
}

#Preview(traits: .landscapeLeft) {
    CameraView()
}
