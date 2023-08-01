//
//  CIContext.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import CoreImage
import CoreMedia
import UIKit

extension CIContext {
    /// Factory for creating a CIContext using the available graphics API.
    ///
    /// - Returns: Default configuration rendering context, otherwise nil.
    static func createDefault() -> CIContext? {
        let options: [CIContextOption: Any] = [
            .outputColorSpace: CGColorSpaceCreateDeviceRGB(),
            .outputPremultiplied: true,
            .useSoftwareRenderer: NSNumber(booleanLiteral: false)
        ]

        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: options)
        }

        return nil
    }

    // MARK: Instance methods

    /// Creates a UIImage from the given sample buffer input
    ///
    /// - Parameter sampleBuffer: sample buffer input
    /// - Returns: UIImage from the sample buffer, otherwise nil
    func image(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciimage = CIImage(cvPixelBuffer: pixelBuffer)
        var sampleBufferImage: UIImage?
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

        if let cgimage = createCGImage(ciimage, from: .init(origin: .zero, size: size)) {
            sampleBufferImage = UIImage(cgImage: cgimage)
        }

        return sampleBufferImage
    }
}
