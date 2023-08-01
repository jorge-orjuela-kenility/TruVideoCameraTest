//
//  TruVideoSpacing.swift
//  TruVideoExample
//
//  Created by Jorge Orjuela on 6/16/23.
//

import UIKit

/// Default Spacing in Lion
public struct TruVideoSpacing {
    /// The default unit of spacing
    public static let spaceUnit: CGFloat = 16

    /// xxxs spacing value (1px)
    public static let xxxs: CGFloat = 0.0625 * spaceUnit

    /// xxs spacing value (2px)
    public static let xxs: CGFloat = 0.125 * spaceUnit

    // swiftlint:disable identifier_name
    /// xs spacing value (4px)
    public static let xs: CGFloat = 0.25 * spaceUnit

    // swiftlint:disable identifier_name
    /// sm spacing value (8px)
    public static let sm: CGFloat = 0.5 * spaceUnit

    // swiftlint:disable identifier_name
    /// md spacing value (12px)
    public static let md: CGFloat = 0.75 * spaceUnit

    /// lg spacing value (16px)
    public static let lg: CGFloat = spaceUnit

    /// xlg spacing value (20px)
    public static let xlg = 1.25 * spaceUnit

    /// xxlg spacing value (24px)
    public static let xxlg: CGFloat = 1.5 * spaceUnit

    /// xxlg spacing value (32px)
    public static let xxxlg: CGFloat = 2 * spaceUnit
    
    /// s6 spacing value (6px)
    public static let s6: CGFloat = 6
    
    /// s10 spacing value (10px)
    public static let s10: CGFloat = 10

    /// s14 spacing value (14px)
    public static let s14: CGFloat = 14
    
    /// s25 spacing value (25px)
    public static let s25: CGFloat = 25

    /// s40 spacing value (40px)
    public static let s40: CGFloat = 40

    /// s50 spacing value (50px)
    public static let s50: CGFloat = 50

    /// s70 spacing value (70px)
    public static let s70: CGFloat = 70
}
