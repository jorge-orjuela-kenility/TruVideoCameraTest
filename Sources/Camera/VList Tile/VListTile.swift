//
//  VListTile.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import SwiftUI

/// A single fixed-height column that typically contains some title and subtitle text
public struct VListTile: View {
    /// Primary text content
    let title: String

    /// The text style to apply to the main content
    let titleTextStyle: TruVideoTextStyle?

    /// Secondary text content
    let subtitle: String?

    /// The text style to apply to the secondary content
    let subtitleTextStyle: TruVideoTextStyle?

    /// The content and behavior of the view.
    public var body: some View {
        VStack(alignment: .leading, spacing: TruVideoSpacing.xs) {
            Text(title)
                .textStyle(titleTextStyle ?? .subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = subtitle {
                Text(subtitle)
                    .textStyle(subtitleTextStyle ?? .caption.copyWith(color: .gray.opacity(0.5)))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Initializers

    /// Creates a `VListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - title: The primary content of the list tile.
    ///   - titleTextStyle: The text style to apply to the main content
    ///   - subtitle: Additional content displayed below the title.
    ///   - subtitleTextStyle: The text style to apply to the secondary content
    public init(
        title: String,
        titleTextStyle: TruVideoTextStyle? = nil,
        subtitle: String? = nil,
        subtitleTextStyle: TruVideoTextStyle? = nil
    ) {

        self.subtitle = subtitle
        self.subtitleTextStyle = subtitleTextStyle
        self.title = title
        self.titleTextStyle = titleTextStyle
    }
}
