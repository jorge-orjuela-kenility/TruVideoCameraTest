//
//  UIImage.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import UIKit

extension UIImage {

    /// Returns cropped image from CGRect
    func croppedImage(to ratio: CGFloat) -> UIImage {
        let height = size.width * ratio
        let y = (size.height - height) / 2

        let bound = CGRect(x: 0, y: y, width: size.width, height: height)
        let scaledBounds: CGRect = .init(
            x: bound.origin.x * scale,
            y: bound.origin.y * scale,
            width: bound.width * scale,
            height: bound.height * scale
        )

        let imageRef = cgImage?.cropping(to: scaledBounds)
        let croppedImage = UIImage(cgImage: imageRef!, scale: scale, orientation: .up)
        return croppedImage
    }
}
