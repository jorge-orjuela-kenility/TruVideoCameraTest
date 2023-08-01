//
//  CircularButton.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import SwiftUI

/// A circular black background button with a sligthly opacity.
struct CircularButton<Label: View>: View {
    /// The view to use for the button.
    let label: () -> Label
    
    /// The  color for the background.
    let color: Color

    /// The callback action for the button.
    let action: () -> Void

    /// The content and behavior of the view.
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)

                label()
            }
        }
    }

    // MARK: Initalizers

    /// Creates a new instance of the `CircularButton`
    ///
    /// - Parameters:
    ///    - icon: The  view to use for the button.
    ///    - action: The callback action for the button
    ///    - color: The  color for the background.
    init(
        color: Color = .gray.opacity(0.3),
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {

        self.action = action
        self.color = color
        self.label = label
    }
}
