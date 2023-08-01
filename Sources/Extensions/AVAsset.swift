//
//  AVAsset.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import UIKit

extension AVAsset {
    /// Returns the `AVCaptureVideoOrientation` for the current asset
    public var orientation: AVCaptureVideoOrientation? {
        guard let videoTrack = tracks(withMediaType: .video).first else {
            return nil
        }

        let size = videoTrack.naturalSize
        let preferredTransform = videoTrack.preferredTransform

        guard size.width > size.height else {
            switch (preferredTransform.a, preferredTransform.b, preferredTransform.d) {
            case (0, 1, 0): return .landscapeRight
            default: return .landscapeLeft
            }
        }

        switch (preferredTransform.a, preferredTransform.b, preferredTransform.d) {
        case (0, -1, 1): return .portraitUpsideDown
        default: return .portrait
        }
    }

    // MARK: Instance methods

    /// Returns the CGImage synchronously. Ownership follows the Create Rule.
    ///
    /// - Parameters:
    ///    - requestedTime: The time at which the image of the asset is to be created.
    ///    - actualTime: A pointer to a CMTime to receive the time at which the image was actually generated.
    func createImage(at requestedTime: CMTime, actualTime: UnsafeMutablePointer<CMTime>?) throws -> UIImage? {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: requestedTime, actualTime: actualTime)
            return UIImage(cgImage: cgImage)
        } catch {
            print("[TruVideoSession]: ⚠️ unable to generate frame image for \(self), at \(requestedTime)")
        }

        return nil
    }
}
