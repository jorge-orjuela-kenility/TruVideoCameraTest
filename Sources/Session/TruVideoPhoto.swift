//
//  TruVideoPhoto.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import UIKit

/// Represents a single video photo record
public struct TruVideoPhoto {
    /// Unique identifier of this `TruVideoPhoto`
    public let id: UUID = .init()

    /// Metadata key for setting the device orientation when the
    /// photo was taken
    public static let DeviceOrientationKey = "DeviceOrientation"

    /// Cropped image
    public var croppedImage: UIImage? {
        guard let croppedImageData = croppedImageData else {
            return nil
        }

        return .init(data: croppedImageData)
    }

    /// Raw data for the cropped image
    public let croppedImageData: Data?

    /// UI Image from the raw data
    public var image: UIImage? {
        guard let imageData = imageData else {
            return nil
        }
            
        return .init(data: imageData)
    }

    /// Raw data for the image
    public let imageData: Data?

    /// Metadata dictionary from the provided sample buffer
    public let metadata: [String: Any]

    // MARK: Initializers

    /// Initialize a new clip instance.
    ///
    /// - Parameters:
    ///   - imageData: Raw data for the image
    ///   - croppedImageData: Raw data for the cropped image
    ///   - metadata: Metadata dictionary from the provided sample buffer
    init(imageData: Data, croppedImageData: Data, metadata: [String: Any]) {
        self.imageData = imageData
        self.croppedImageData = croppedImageData
        self.metadata = metadata
    }
}

extension TruVideoPhoto: Hashable {

    // MARK: Hashable

    /// Returns a Boolean value indicating whether two values are equal.
    public static func == (lhs: TruVideoPhoto, rhs: TruVideoPhoto) -> Bool {
        lhs.croppedImageData == rhs.croppedImageData && lhs.imageData == rhs.imageData
    }

    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    public func hash(into hasher: inout Hasher) {
        croppedImageData.hash(into: &hasher)
        imageData.hash(into: &hasher)
    }
}
