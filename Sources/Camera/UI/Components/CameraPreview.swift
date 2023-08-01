//
//  CameraPreview.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import SwiftUI

/// Shows the current frames captured by the `AVCaptureSession`
struct CameraPreview: UIViewRepresentable {
    /// The underlying `AVCaptureVideoPreviewLayer`
    let previewLayer: AVCaptureVideoPreviewLayer

    /// Container view for the `AVCaptureVideoPreviewLayer`.
    class PlayerContainerView: UIView {
        /// The underlying `AVCaptureVideoPreviewLayer`
        private let previewLayer: AVCaptureVideoPreviewLayer

        // MARK: Initializers

        /// Creates a new instance of the `PlayerContainerView`.
        init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            layer.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: Overriden methods

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = frame
        }
    }

    // MARK: UIViewRepresentable

    /// Creates the view object and configures its initial state.
    func makeUIView(context: Context) -> UIView {
        let playerContainerView = PlayerContainerView(previewLayer: previewLayer)
        playerContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerContainerView.backgroundColor = .black
        playerContainerView.layer.addSublayer(previewLayer)

        return playerContainerView
    }

    /// Updates the state of the specified view with new information from
    /// SwiftUI.
    func updateUIView(_ uiView: UIView, context: Context) {}
}
