//
//  EdgeInsets+Extensions.swift
//  TruVideoExample
//
//  Created by Jorge Orjuela on 6/16/23.
//

import SwiftUI

extension EdgeInsets {

    /// Creates insets with only the given value for the layouts.
    ///
    /// - Parameter padding: The padding to apply to the all layouts
    /// - Returns: A new instance of the `EdgeInsets`
    public static func all(_ padding: CGFloat) -> EdgeInsets {
        .init(top: padding, leading: padding, bottom: padding, trailing: padding)
    }

    /// Creates insets with only the given values non-zero.
    ///
    /// - Parameters:
    ///    - bottom: The padding to apply to the bottom layout
    ///    - leading: The padding to apply to the leading layout
    ///    - top: The padding to apply to the top layout
    ///    - trailing: The padding to apply to the trailing layout
    /// - Returns: A new instance of the `EdgeInsets`
    public static func only(
        bottom: CGFloat = 0,
        leading: CGFloat = 0,
        top: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> EdgeInsets {

        .init(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }

    /// Creates insets with only the given values non-zero.
    ///
    /// - Parameters:
    ///    - horizontal: The padding to apply to the leading and trailing layout
    ///    - vertical: The padding to apply to the top and bottom layout
    /// - Returns: A new instance of the `EdgeInsets`
    public static func symmetric(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> EdgeInsets {
        .init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}
