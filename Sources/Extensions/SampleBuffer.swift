//
//  SampleBuffer.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import CoreMedia
import UIKit

extension CMSampleBuffer {
    /// Extracts the metadata dictionary from a `CMSampleBuffer`.
    ///  (ie EXIF: Aperture, Brightness, Exposure, FocalLength, etc)
    ///
    /// - Parameter sampleBuffer: sample buffer to be processed
    /// - Returns: metadata dictionary from the provided sample buffer
    var metadata: [String: Any]? {
        guard let metadata = CMCopyDictionaryOfAttachments(
            allocator: kCFAllocatorDefault,
            target: self,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        ) else {
            return nil
        }

        return metadata as? [String: Any]
    }

    // MARK: Instance methods

    /// Appends the provided metadata dictionary key/value pairs.
    ///
    /// - Parameter metadataAdditions: Metadata key/value pairs to be appended.
    func append(metadataAdditions: [String: Any]) {
        if let attachments = CMCopyDictionaryOfAttachments(
            allocator: kCFAllocatorDefault,
            target: kCGImagePropertyTIFFDictionary,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        ) {

            let attachmentsDictionary = attachments as NSDictionary
            var metaDict: [String: Any] = [:]
            for (key, value) in metadataAdditions {
                metaDict.updateValue(value as AnyObject, forKey: key)
            }

            for (key, value) in attachmentsDictionary {
                if let keyString = key as? String {
                    metaDict.updateValue(value as AnyObject, forKey: keyString)
                }
            }
            CMSetAttachment(
                self,
                key: kCGImagePropertyTIFFDictionary,
                value: metaDict as CFTypeRef?,
                attachmentMode: kCMAttachmentMode_ShouldPropagate
            )
        } else {
            CMSetAttachment(
                self,
                key: kCGImagePropertyTIFFDictionary,
                value: metadataAdditions as CFTypeRef?,
                attachmentMode: kCMAttachmentMode_ShouldPropagate
            )
        }
    }
}
