//
//  FitToParent.swift
//  Camera
//
//  Created by Kevin LAUNAY on 19/08/2025.
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
