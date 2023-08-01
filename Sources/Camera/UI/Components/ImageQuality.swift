//
//  ImageQuality.swift
//  TruVideoExample
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import SwiftUI

/// A custom SwiftUI view designed to display an image along with an associated quality indicator.
/// This view is useful when you want to showcase an image and provide a visual representation of
/// its quality, such as resolution, compression level, or any other relevant metric.
struct ImageQualityView: View {
    /// The current orientation state of the device.
    @State private var orientation = UIDevice.current.orientation
    
    /// A flag that indicates if show the quality configurations.
    @Binding var isImageQualityPresented: Bool

    /// The view model handling the logic and data for camera features.
    @EnvironmentObject var viewModel: CameraViewModel

    /// The content and behavior of the view.
    var body: some View {
        VStack {
            Text("Camera Quality")
                .textStyle(.title2.copyWith(color: .white))

            HStack(spacing: TruVideoSpacing.s25) {
                makeCircularButton(image: TruVideoImage.boltFill, imageQuality: .low, text: "Low")
                makeCircularButton(image: TruVideoImage.boltFill, imageQuality: .medium, text: "Medium")
                makeCircularButton(image: TruVideoImage.boltFill, imageQuality: .high, text: "High")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation {
                orientation = UIDevice.current.orientation
            }
        }
        .rotationEffect(orientation.angle ?? Angle(degrees: 0))
    }

    // MARK: Private methods

    private func makeCircularButton(image: Image, imageQuality: AVCaptureSession.Preset, text: String) -> some View {
        VStack(alignment: .center, spacing: TruVideoSpacing.xlg) {
            CircularButton(color: viewModel.imageQuality == imageQuality ? .iconFill : .gray.opacity(0.3)) {
                viewModel.imageQuality = imageQuality
                isImageQualityPresented.toggle()
            } label: {
                image
                    .resizable()
                    .withRenderingMode(.template, color: viewModel.imageQuality == imageQuality ? .black : .white)
                    .scaledToFit()
                    .frame(minWidth: 17, minHeight: 17)
                    .fixedSize()
            }
            .frame(minWidth: 60, minHeight: 60)
            .fixedSize()
            
            Text(text)
                .textStyle(.caption.copyWith(color: .white))
        }
    }
}
