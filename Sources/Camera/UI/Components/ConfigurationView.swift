//
//  ConfigurationButtonsView.swift
//  TruVideoExample
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import SwiftUI

extension Color {
    /// The fill color when the button is selected.
    ///
    /// - Note: Move this to color struct.
    static var iconFill: Color {
        Color(red: 245 / 255, green: 189 / 255, blue: 65 / 255)
    }
}

/// A custom SwiftUI view designed to provide buttons for various camera configuration options.
/// This view is useful when you want to offer users the ability to control different camera settings,
/// such as flash, HDR, timer, or grid. 
struct ConfigurationView: View {
    /// The current orientation state of the device.
    @State private var orientation = UIDevice.current.orientation
    
    /// A flag that indicates if the button should be disabled.
    private var isDisableButton: Bool {
        viewModel.recordStatus == .recording || !viewModel.clips.isEmpty || !viewModel.photos.isEmpty
    }
    
    /// An action that dismisses the view.
    let dismiss: DismissAction
    
    /// A flag that indicates if show the quality configurations.
    @Binding var isImageQualityPresented: Bool
    
    /// The view model handling the logic and data for camera features.
    @EnvironmentObject var viewModel: CameraViewModel

    /// The content and behavior of the view.
    var body: some View {
        HStack(spacing: TruVideoSpacing.s10) {
            GalleryCounter()
            Spacer()
            makeCircularButton(icon: TruVideoImage.noiseCancellation, isSelected: false, action: {})
            makeCircularButton(icon: TruVideoImage.microphoneFill, isSelected: false, action: {})
            makeFlashButton()
            makeCircularButton(icon: TruVideoImage.imageQuality, isSelected: false) {
                guard viewModel.recordStatus == .initialized else { return }

                withAnimation(.easeInOut) { isImageQualityPresented.toggle() }
            }

            makeCircularButton(icon: TruVideoImage.close, isSelected: false, action: dismiss.callAsFunction)
        }
        .padding(.trailing, TruVideoSpacing.md)
    }

    // MARK: Private methods
    
    private func makeCircularButton(icon: Image, isSelected: Bool, action: @escaping () -> Void) -> some View {
        CircularButton(color: isSelected ? .iconFill : .gray.opacity(0.3), action: action) {
            icon
                .resizable()
                .withRenderingMode(.template, color: isSelected ? .black : .white)
                .scaledToFit()
                .frame(minWidth: 17, minHeight: 17)
                .fixedSize()
        }
        .frame(minWidth: 40, minHeight: 40)
        .fixedSize()
        .disabled(icon == TruVideoImage.close ? false : isDisableButton)
        .rotationEffect(orientation.angle ?? Angle(degrees: 0))
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation {
                orientation = UIDevice.current.orientation
            }
        }
    }

    private func makeFlashButton() -> some View {
        PublisherListener(
            initialValue: viewModel.torchStatus,
            publisher: viewModel.$torchStatus,
            buildWhen: { previous, current in previous != current }
        ) { torchStatus in

            CircularButton(color: torchStatus == .on ? .iconFill : .gray.opacity(0.3), action: viewModel.toggleTorch) {
                (torchStatus == .on ? TruVideoImage.boltFill : TruVideoImage.boltSlashFill)
                    .resizable()
                    .withRenderingMode(.template, color: torchStatus == .on ? .black : .white)
                    .scaledToFit()
                    .frame(minWidth: 17, minHeight: 17)
                    .fixedSize()
            }
            .frame(minWidth: 40, minHeight: 40)
            .fixedSize()
            .id(torchStatus)
            .animation(.easeInOut(duration: 0.25), value: viewModel.recordStatus)
            .transition(.opacity)
            .rotationEffect(orientation.angle ?? orientation.angle ?? Angle(degrees: 0))
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                withAnimation {
                    orientation = UIDevice.current.orientation
                }
            }
        }
    }
}

/// A user interface that shows the current number of videos and pictures
/// that the user has taken.
private struct GalleryCounter: View {
    //// The view model handling the logic and data for camera features.
    @EnvironmentObject var viewModel: CameraViewModel

    /// The content and behavior of the view.
    var body: some View {
        VStack(spacing: TruVideoSpacing.xxs) {
            HStack(spacing: TruVideoSpacing.xxs) {
                TruVideoImage.play
                    .resizable()
                    .withRenderingMode(.template, color: .white)
                    .scaledToFit()
                    .frame(width: 15, height: 10)

                Text("\(viewModel.clips.count)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }

            HStack(spacing: TruVideoSpacing.xxs) {
                TruVideoImage.image
                    .resizable()
                    .withRenderingMode(.template, color: .white)
                    .scaledToFit()
                    .frame(width: 15, height: 10)

                Text("\(viewModel.photos.count)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        .opacity(viewModel.clips.isEmpty && viewModel.photos.isEmpty ? 0 : 1)
        .padding(.bottom, TruVideoSpacing.xlg)
        .rotationEffect(Angle(degrees: 90))
    }
}
