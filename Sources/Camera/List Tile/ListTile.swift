//
//  ListTile.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import SwiftUI

/// A single fixed-height row that typically contains some text as well as
/// a leading or trailing icon.
///
/// A list tile contains one to two lines of text optionally flanked by icons or
/// other views, such as texts. The icons (or other views) for the
/// tile are defined with the `leading` and `trailing` parameters.
///
/// ```swift
/// ListTile(
///     backgroundColor: .red,
///     leading: Image(systemName: "info.circle"),
///     title: "Title",
///     subtitle: "Subtitle",
///     trailing: Image(systemName: "chevron.right"
///    )
/// ```
public struct ListTile<Content: View, Leading: View, Trailing: View>: View {
    /// The color of the surface of this `ListTile`.
    let backgroundColor: Color

    /// The content of this `ListTile`.
    @ViewBuilder let content: () -> Content

    /// The guide for aligning the subviews in this stack. This
    /// guide has the same vertical screen coordinate for every child view.
    let alignment: VerticalAlignment

    /// The amount of space by which to inset the leading view.
    @ViewBuilder let leading: (() -> Leading)?

    /// The amount of space by which to inset the leading view.
    let leadingPadding: EdgeInsets

    /// The amount of space by which to inset the content.
    let padding: EdgeInsets

    /// The amount of space by which to inset the trailing view.
    @ViewBuilder let trailing: (() -> Trailing)?

    /// The amount of space by which to inset the trailing view.
    let trailingPadding: EdgeInsets

    /// The content and behavior of the view.
    public var body: some View {
        HStack(alignment: alignment, spacing: .zero) {
            leading?()
                .padding(leadingPadding)
            content()
            Spacer()
            trailing?()
                .padding(trailingPadding)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            backgroundColor.edgesIgnoringSafeArea(.all)
        )
    }

    // MARK: Initializers

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - leading: The (optional) leading view of the `ListTile`.
    ///   - leadingPadding: The amount of space by which to inset the leading view.
    ///   - content: The content of the `ListTile`.
    ///   - trailing: The (optional) trailing view of the `ListTile`.
    ///   - trailingPadding: The amount of space by which to inset the trailing view.
    fileprivate init(
        alignment: VerticalAlignment?,
        backgroundColor: Color?,
        padding: EdgeInsets?,
        leading: (() -> Leading)?,
        leadingPadding: EdgeInsets?,
        @ViewBuilder content: @escaping () -> Content,
        trailing: (() -> Trailing)?,
        trailingPadding: EdgeInsets?
    ) {

        self.alignment = alignment ?? .center
        self.backgroundColor = backgroundColor ?? .clear
        self.content = content
        self.leading = leading
        self.leadingPadding = leadingPadding ?? .only(trailing: TruVideoSpacing.sm)
        self.padding = padding ?? .all(0)
        self.trailing = trailing
        self.trailingPadding = trailingPadding ?? .only(leading: TruVideoSpacing.sm)
    }

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - leading: The (optional) leading view of the `ListTile`.
    ///   - leadingPadding: The amount of space by which to inset the leading view.
    ///   - content: The content of the `ListTile`.
    ///   - trailing: The (optional) trailing view of the `ListTile`.
    ///   - trailingPadding: The amount of space by which to inset the trailing view.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        leading: @autoclosure @escaping (() -> Leading),
        leadingPadding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping (() -> Trailing),
        trailingPadding: EdgeInsets? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: leading,
            leadingPadding: leadingPadding,
            content: content,
            trailing: trailing,
            trailingPadding: trailingPadding
        )
    }

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - leading: The (optional) leading view of the `ListTile`.
    ///   - leadingPadding: The amount of space by which to inset the leading view.
    ///   - content: The content of the `ListTile`.
    ///   - trailing: The (optional) trailing view of the `ListTile`.
    ///   - trailingPadding: The amount of space by which to inset the trailing view.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        @ViewBuilder leading: @escaping (() -> Leading),
        leadingPadding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> Content,
        trailing: @autoclosure @escaping (() -> Trailing),
        trailingPadding: EdgeInsets? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: leading,
            leadingPadding: leadingPadding,
            content: content,
            trailing: trailing,
            trailingPadding: trailingPadding
        )
    }
}

extension ListTile where Leading == Never {

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - content: The content of this `ListTile`.
    ///   - trailing: The trailing view of the `ListTile`.
    ///   - trailingPadding: The amount of space by which to inset the trailing view.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> Content,
        trailing: @autoclosure @escaping () -> Trailing,
        trailingPadding: EdgeInsets? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: nil,
            leadingPadding: nil,
            content: content,
            trailing: trailing,
            trailingPadding: trailingPadding
        )
    }

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - content: The content of this `ListTile`.
    ///   - trailing: The trailing view of the `ListTile`.
    ///   - trailingPadding: The amount of space by which to inset the trailing view.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing,
        trailingPadding: EdgeInsets? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: nil,
            leadingPadding: nil,
            content: content,
            trailing: trailing,
            trailingPadding: trailingPadding
        )
    }
}

extension ListTile where Trailing == Never {

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - leading: The leading view of the `ListTile`.
    ///   - leadingPadding: The amount of space by which to inset the leading view.
    ///   - content: The content of this `ListTile`.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        leading: @autoclosure @escaping () -> Leading,
        leadingPadding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: leading,
            leadingPadding: leadingPadding,
            content: content,
            trailing: nil,
            trailingPadding: nil
        )
    }

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - leading: The leading view of the `ListTile`.
    ///   - leadingPadding: The amount of space by which to inset the leading view.
    ///   - content: The content of this `ListTile`.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        leadingPadding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: leading,
            leadingPadding: leadingPadding,
            content: content,
            trailing: nil,
            trailingPadding: nil
        )
    }
}

extension ListTile where Leading == Never, Trailing == Never {

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - content: The content of this `ListTile`.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: nil,
            leadingPadding: nil,
            content: content,
            trailing: nil,
            trailingPadding: nil
        )
    }
}

extension ListTile where Content == AnyView, Leading == Never, Trailing == Never {

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this stack.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - title: The primary content of the list tile.
    ///   - subtitle: Additional content displayed below the title.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        title: String,
        titleTextStyle: TruVideoTextStyle? = nil,
        subtitle: String? = nil,
        subtitleTextStyle: TruVideoTextStyle? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: nil,
            leadingPadding: nil,
            content: {
                VListTile(
                    title: title,
                    titleTextStyle: titleTextStyle,
                    subtitle: subtitle,
                    subtitleTextStyle: subtitleTextStyle
                )
                    .eraseToAnyView()
            },
            trailing: nil,
            trailingPadding: nil
        )
    }
}

extension ListTile where Content == AnyView, Trailing == Never {

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - leading: The  leading view of the `ListTile`.
    ///   - leadingPadding: The amount of space by which to inset the leading view.
    ///   - title: The primary content of the list tile.
    ///   - titleTextStyle: The text style to apply to the main content
    ///   - subtitle: Additional content displayed below the title.
    ///   - subtitleTextStyle: The text style to apply to the secondary content
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        leading: @autoclosure @escaping () -> Leading,
        leadingPadding: EdgeInsets? = nil,
        title: String,
        titleTextStyle: TruVideoTextStyle? = nil,
        subtitle: String? = nil,
        subtitleTextStyle: TruVideoTextStyle? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: leading,
            leadingPadding: leadingPadding,
            content: {
                VListTile(
                    title: title,
                    titleTextStyle: titleTextStyle,
                    subtitle: subtitle,
                    subtitleTextStyle: subtitleTextStyle
                )
                    .eraseToAnyView()
            },
            trailing: nil,
            trailingPadding: nil
        )
    }
}

extension ListTile where Content == AnyView, Leading == Never {

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - title: The primary content of the list tile.
    ///   - titleTextStyle: The text style to apply to the main content
    ///   - subtitle: Additional content displayed below the title.
    ///   - subtitleTextStyle: The text style to apply to the secondary content
    ///   - trailing: The  Trailing view of the `ListTile`.
    ///   - trailingPadding: The amount of space by which to inset the leading view.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        title: String,
        titleTextStyle: TruVideoTextStyle? = nil,
        subtitle: String? = nil,
        subtitleTextStyle: TruVideoTextStyle? = nil,
        trailing: @autoclosure @escaping () -> Trailing,
        trailingPadding: EdgeInsets? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: nil,
            leadingPadding: nil,
            content: {
                VListTile(
                    title: title,
                    titleTextStyle: titleTextStyle,
                    subtitle: subtitle,
                    subtitleTextStyle: subtitleTextStyle
                )
                    .eraseToAnyView()
            },
            trailing: trailing,
            trailingPadding: trailingPadding
        )
    }

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - title: The primary content of the list tile.
    ///   - titleTextStyle: The text style to apply to the main content
    ///   - subtitle: Additional content displayed below the title.
    ///   - subtitleTextStyle: The text style to apply to the secondary content
    ///   - trailing: The  Trailing view of the `ListTile`.
    ///   - trailingPadding: The amount of space by which to inset the leading view.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        title: String,
        titleTextStyle: TruVideoTextStyle? = nil,
        subtitle: String? = nil,
        subtitleTextStyle: TruVideoTextStyle? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing,
        trailingPadding: EdgeInsets? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: nil,
            leadingPadding: nil,
            content: {
                VListTile(
                    title: title,
                    titleTextStyle: titleTextStyle,
                    subtitle: subtitle,
                    subtitleTextStyle: subtitleTextStyle
                )
                    .eraseToAnyView()
            },
            trailing: trailing,
            trailingPadding: trailingPadding
        )
    }
}

extension ListTile where Content == AnyView {

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - leading: The (optional) leading view of the `ListTile`.
    ///   - leadingPadding: The amount of space by which to inset the leading view.
    ///   - title: The primary content of the list tile.
    ///   - titleTextStyle: The text style to apply to the main content
    ///   - subtitle: Additional content displayed below the title.
    ///   - subtitleTextStyle: The text style to apply to the secondary content
    ///   - trailingPadding: The amount of space by which to inset the leading view.
    ///   - trailing: The  Trailing view of the `ListTile`.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        leading: @autoclosure @escaping () -> Leading,
        leadingPadding: EdgeInsets? = nil,
        title: String,
        titleTextStyle: TruVideoTextStyle? = nil,
        subtitle: String? = nil,
        subtitleTextStyle: TruVideoTextStyle? = nil,
        trailing: @autoclosure @escaping () -> Trailing,
        trailingPadding: EdgeInsets? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: leading,
            leadingPadding: leadingPadding,
            content: {
                VListTile(
                    title: title,
                    titleTextStyle: titleTextStyle,
                    subtitle: subtitle,
                    subtitleTextStyle: subtitleTextStyle
                )
                    .eraseToAnyView()
            },
            trailing: trailing,
            trailingPadding: trailingPadding
        )
    }

    /// Creates a `ListTile` that computes its content on demand from an underlying
    /// `@ViewBuilder` parameters.
    ///
    /// - Parameters:
    ///   - alignment: The guide for aligning the subviews in this `ListTile`.
    ///   - backgroundColor: The color for the surface.
    ///   - padding: The amount of space by which to inset the content.
    ///   - leading: The (optional) leading view of the `ListTile`.
    ///   - leadingPadding: The amount of space by which to inset the leading view.
    ///   - title: The primary content of the list tile.
    ///   - titleTextStyle: The text style to apply to the main content
    ///   - subtitle: Additional content displayed below the title.
    ///   - subtitleTextStyle: The text style to apply to the secondary content
    ///   - trailingPadding: The amount of space by which to inset the leading view.
    ///   - trailing: The  Trailing view of the `ListTile`.
    public init(
        alignment: VerticalAlignment? = nil,
        backgroundColor: Color? = nil,
        padding: EdgeInsets? = nil,
        leading: @autoclosure @escaping () -> Leading,
        leadingPadding: EdgeInsets? = nil,
        title: String,
        titleTextStyle: TruVideoTextStyle? = nil,
        subtitle: String? = nil,
        subtitleTextStyle: TruVideoTextStyle? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing,
        trailingPadding: EdgeInsets? = nil
    ) {

        self.init(
            alignment: alignment,
            backgroundColor: backgroundColor,
            padding: padding,
            leading: leading,
            leadingPadding: leadingPadding,
            content: {
                VListTile(
                    title: title,
                    titleTextStyle: titleTextStyle,
                    subtitle: subtitle,
                    subtitleTextStyle: subtitleTextStyle
                )
                    .eraseToAnyView()
            },
            trailing: trailing,
            trailingPadding: trailingPadding
        )
    }
}

struct ListTile_Previews: PreviewProvider {
    static var previews: some View {
        ListTile(
            backgroundColor: .red,
            leading: Image(systemName: "info.circle"),
            title: "Title",
            subtitle: "Subtitle",
            trailing: Image(systemName: "chevron.right")
        )
    }
}

