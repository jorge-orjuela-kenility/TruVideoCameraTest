//
//  TruVideoTextStyle.swift
//  TruVideoExample
//
//  Created by Jorge Orjuela on 6/16/23.
//

import SwiftUI

/// Tru Video Text Style Definitions
public struct TruVideoTextStyle {
    /// Color
    let color: Color

    /// Font design
    let design: Font.Design

    /// Font style
    let style: Font.TextStyle

    /// Font weight
    let weight: Font.Weight

    /// Body Text Style.
    public static let body = TruVideoTextStyle(color: .black, design: .default, style: .body, weight: .regular)

    /// Callout Text Style.
    public static let callout = TruVideoTextStyle(color: .black, design: .default, style: .callout, weight: .regular)

    /// Caption 1 Text Style.
    public static let caption = TruVideoTextStyle(
        color: .black,
        design: .default,
        style: .caption,
        weight: .regular
    )

    /// Footnote Text Style.
    public static let footnote = TruVideoTextStyle(
        color: .black,
        design: .default,
        style: .footnote,
        weight: .regular
    )

    /// Subheadline Text Style.
    public static let subheadline = TruVideoTextStyle(
        color: .black,
        design: .default,
        style: .subheadline,
        weight: .regular
    )

    /// Title 1 Text Style.
    public static let title = TruVideoTextStyle(
        color: .black,
        design: .default,
        style: .title,
        weight: .regular
    )

    /// Title 2 Text Style.
    public static let title2 = TruVideoTextStyle(
        color: .black,
        design: .default,
        style: .title2,
        weight: .regular
    )

    /// Title 3 Text Style.
    public static let title3 = TruVideoTextStyle(
        color: .black,
        design: .default,
        style: .title3,
        weight: .regular
    )

    // MARK: Instance methods

    /// Returns a copy of this `TruVideoTextStyle` with the given fields replaced with
    /// the new values.
    public func copyWith(
        color: Color? = nil,
        design: Font.Design? = nil,
        style: Font.TextStyle? = nil,
        weight: Font.Weight? = nil
    ) -> TruVideoTextStyle {

        .init(
            color: color ?? self.color,
            design: design ?? self.design,
            style: style ?? self.style,
            weight: weight ?? self.weight
        )
    }
}
