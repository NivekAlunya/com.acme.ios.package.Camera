//
//  View+FitToParent.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import SwiftUI

extension View {
    public func fitToParent() -> some View {
        modifier(FitToParent())
    }
}

public struct FitToParent: ViewModifier {
    public func body(content: Content) -> some View {
        GeometryReader { geometry in
                content
                    .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

extension List {
    public func applySettingListStyle() -> some View {
        modifier(SettingListStyle())
    }
}

public struct SettingListStyle: ViewModifier {
    public func body(content: Content) -> some View {
            content
                .foregroundStyle(.tint)
                .background(.ultraThickMaterial)
                .scrollContentBackground(.hidden)
    }
}
