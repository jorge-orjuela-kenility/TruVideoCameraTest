//
//  TruVideoClip.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import UIKit

/// Represents a single video clip record
public class TruVideoClip {
    /// Unique identifier of this `TruVideoClip`
    public let id: UUID = .init()

    /// Cached size in `KB`.
    private var cachedSize: Int64?

    /// Underliying `AVAsset`
    public private(set) lazy var asset: AVAsset? = {
        AVAsset(url: url)
    }()

    /// Duration of the clip, otherwise invalid.
    public var duration: CMTime {
        asset?.duration ?? .zero
    }

    /// True, if the clip's file exists
    public var fileExists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Frame rate at which the asset was recorded.
    var frameRate: Float {
        if
            // The list of video tracks
            let tracks = asset?.tracks(withMediaType: .video),

            // First track found in the asset
            let videoTrack = tracks.first {

            return videoTrack.nominalFrameRate
        }

        return 0
    }

    /// Image for the last frame of the clip.
    public private(set) lazy var lastFrameImage: UIImage? = {
        try? asset?.createImage(at: duration, actualTime: nil)
    }()

    /// The `AVCaptureVideoOrientation` of the clip
    public private(set) lazy var orientation: AVCaptureVideoOrientation? = asset?.orientation

    /// The size in `KB` of the clip
    public private(set) lazy var size: Int64? = {
        guard cachedSize == nil else {
            return cachedSize
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            print("[TruVideoSession]: ⚠️ Unable to get size of the clip error: \(error)")
            return nil
        }
    }()

    /// If it doesn't already exist, generates a thumbnail image of the clip.
    public private(set) lazy var thumbnailImage: UIImage? = {
        try? asset?.createImage(at: .zero, actualTime: nil)
    }()

    /// URL of the clip
    public let url: URL

    // MARK: Initializers

    /// Initialize a new clip instance.
    ///
    /// - Parameter url: URL and filename of the specified media asset
    public init(url: URL) {
        self.url = url
    }
}

extension TruVideoClip: Equatable {

    // MARK: Equatable

    public static func == (lhs: TruVideoClip, rhs: TruVideoClip) -> Bool {
        lhs.url == rhs.url
    }
}
