//
//  BlurView.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import SwiftUI

/// `BlurView` is a UIViewRepresentable that wraps a `UIVisualEffectView`
/// to create a blur effect within a SwiftUI view hierarchy. The effect can be customized
/// by specifying a `UIBlurEffect.Style`.
struct BlurView: UIViewRepresentable {
    /// The style of the blur effect to be applied.
    let style: UIBlurEffect.Style

    /// Creates and configures a `UIVisualEffectView` with the specified `style`.
    ///
    /// - Parameter context: The context for configuring the view.
    func makeUIView(context: Context) -> some UIView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    /// Updates the `UIVisualEffectView` when the view data changes (not used in this implementation).
    ///
    /// - Parameters:
    ///   - uiView: The view to be updated.
    ///   - context: The context for configuring the view.
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
