//
//  View+FitToParent.swift
//  Camera
//
//  Created by Kevin LAUNAY.
//

import SwiftUI

extension View {
    /// A view modifier that makes the view fit its parent's size.
    public func fitToParent() -> some View {
        modifier(FitToParent())
    }
}

/// A `ViewModifier` that uses a `GeometryReader` to make the content's frame match the size of its parent container.
public struct FitToParent: ViewModifier {
    public func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

extension List {
    /// Applies a standard style for settings lists within the camera view.
    public func applySettingListStyle() -> some View {
        modifier(SettingListStyle())
    }
}

/// A `ViewModifier` that applies a consistent style to `List` views used in the settings screens.
public struct SettingListStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundStyle(.tint)
            .background(.ultraThickMaterial)
            .scrollContentBackground(.hidden)
    }
}
