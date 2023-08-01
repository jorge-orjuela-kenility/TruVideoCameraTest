//
//  Camera.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import SwiftUI

extension Double {
    /// Returns the readable Hours, Minutes and Seconds from
    /// a number of seconds recorded.
    func toHMS() -> String {
        String(format: "%02d:%02d:%02d", Int(self) / 3600, Int(self) % 3600 / 60, Int(self) % 3600 % 60)
    }
}

private extension Image {
    /// Modifies the icon of the current view to represent a graphical image.
    /// The icon adapts based on the selected or unselected state.
    ///
    /// - Returns: A view representing the graphical icon, adapted to the selected state.
    func modifiedIcon() -> some View {
        resizable()
            .withRenderingMode(.template, color: .white)
            .scaledToFit()
            .frame(width: 25, height: 25)
    }
}

private extension View {
    /// Modifies the button of the current view to represent a graphical image.
    /// The button adapts based on the selected or unselected state.
    ///
    /// - Returns: A view representing the graphical button, adapted to the selected state.
    func modifiedButton(with orientation: UIDeviceOrientation) -> some View {
        frame(minWidth: 50, minHeight: 50)
            .fixedSize()
            .rotationEffect(orientation.angle ?? Angle(degrees: 0))
    }
}

/// Represents the previous and current orientation state.
struct OrientationState: Equatable {
    /// The previous device orientation.
    let previous: UIDeviceOrientation

    /// The current device orientation.
    let current: UIDeviceOrientation

    /// Whether the camera should continue displayed.
    var canDisplayCamera: Bool {
        switch (previous, current) {
        case (.landscapeLeft, .faceDown), (.landscapeLeft, .faceUp):
            return true
            
        default:
            return current.isAllowedForRecording
        }
    }
}

/// Manages the video/audio capture session.
struct Camera: View {
    /// An action that dismisses the view.
    let dismiss: DismissAction
    
    /// A flag that indicates if the quality configurations view is presented.
    @State var isImageQualityPresented = false

    /// The view model handling the logic and data for camera features.
    @EnvironmentObject var viewModel: CameraViewModel

    /// The content and behavior of the view.
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: .zero) {
                VStack(alignment: .trailing, spacing: TruVideoSpacing.s10) {
                    ConfigurationView(dismiss: dismiss, isImageQualityPresented: $isImageQualityPresented)
                    makeCamera()
                }

                ControlsView()
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !viewModel.clips.isEmpty || !viewModel.photos.isEmpty {
                ContinueButton(action: dismiss.callAsFunction)
            }
            
            if isImageQualityPresented {
                BlurView(style: .dark)
                    .ignoresSafeArea(.all, edges: .all)
                    .onTapGesture {
                        withAnimation(.easeInOut) { isImageQualityPresented.toggle() }
                    }

                ImageQualityView(isImageQualityPresented: $isImageQualityPresented)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .overlay(alignment: .topTrailing, content: makeQualityOverlayContent)
        .background(.black)
    }

    // MARK: Private methods

    private func makeCamera() -> some View {
        ZStack(alignment: .trailing) {
            CameraPreview(previewLayer: viewModel.previewLayer)
                .cornerRadius(10)

            TimerView()

            if viewModel.recordStatus == .recording {
                TruVideoImage.recordingScreen
                    .resizable()
            }
        }
    }
    
    @ViewBuilder
    private func makeQualityOverlayContent() -> some View {
        if isImageQualityPresented {
            CircularButton(color: .gray.opacity(0.3)) {
                withAnimation(.easeInOut) {
                    isImageQualityPresented.toggle()
                }
            } label: {
                TruVideoImage.close
                    .resizable()
                    .withRenderingMode(.template, color: .white)
                    .scaledToFit()
                    .frame(minWidth: 5, minHeight: 5)
                    .fixedSize()
            }
            .frame(minWidth: 40, minHeight: 40)
            .fixedSize()
            .padding(.trailing, TruVideoSpacing.xlg)
        }
    }
}

/// A custom SwiftUI button designed to allow users to proceed to the
/// next step or action in the camera.
private struct ContinueButton: View {
    /// The action to perform when the user triggers the button.
    let action: () -> Void
    
    /// The content and behavior of the view.
    var body: some View {
        Button(action: action) {
            ListTile(
                content: {
                    Text("CONTINUE")
                        .tracking(1)
                        .textStyle(TruVideoTextStyle.callout.copyWith(color: .white))
                },
                trailing: makeChevronRightImage,
                trailingPadding: .only(leading: TruVideoSpacing.xxs)
            )
            .padding(.horizontal, TruVideoSpacing.md)
            .padding(.vertical, TruVideoSpacing.s6)
            .overlay(
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .background(Color.clear)
            )
        }
        .rotationEffect(Angle(degrees: 90))
        .fixedSize()
        .offset(x: 40, y: -60)
    }
    
    // MARK: Private methods

    private func makeChevronRightImage() -> some View {
        TruVideoImage.chevronRight
            .resizable()
            .withRenderingMode(.template, color: .white)
            .scaledToFit()
            .frame(width: 12, height: 12)
    }
}

/// Shows the camera for controls.
private struct ControlsView: View {
    /// The current orientation state of the device.
    @State private var orientation = OrientationState(
        previous: UIDevice.current.orientation,
        current: UIDevice.current.orientation
    )

    /// The view model handling the logic and data for camera features.
    @EnvironmentObject var viewModel: CameraViewModel
    
    /// The content and behavior of the view.
    var body: some View {
        PublisherListener(
            initialValue: viewModel.recordStatus,
            publisher: viewModel.$recordStatus,
            buildWhen: { previous, current in previous != current }
        ) { state in

            HStack(spacing: TruVideoSpacing.lg) {
                CircularButton(action: viewModel.takePhoto) {
                    TruVideoImage.camera
                        .modifiedIcon()
                }
                .disabled(!orientation.canDisplayCamera)
                .modifiedButton(with: orientation.current)

                RecordButton()
                CircularButton(action: viewModel.flipCamera) {
                    TruVideoImage.flipCamera
                        .modifiedIcon()
                }
                .modifiedButton(with: orientation.current)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.easeInOut(duration: 0.25), value: state)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                withAnimation {
                    orientation = .init(previous: orientation.current, current: UIDevice.current.orientation)
                }
            }
            .padding(.vertical, TruVideoSpacing.lg)
        }
    }
}

/// A view that displays the elapsed time when recording.
private struct TimerView: View {
    /// The view model handling the logic and data for camera features.
    @EnvironmentObject var viewModel: CameraViewModel

    /// The content and behavior of the view.
    var body: some View {
        PublisherListener(
            initialValue: viewModel.secondsRecorded,
            publisher: viewModel.$secondsRecorded,
            buildWhen: { previous, current in previous != current }
        ) { secondsRecorded in

            Text(secondsRecorded.toHMS())
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.vertical, TruVideoSpacing.sm)
                .background(
                    Rectangle()
                        .foregroundColor(viewModel.recordStatus == .recording ? .red.opacity(0.8): .black.opacity(0.8))
                        .cornerRadius(5)
                        .animation(.linear, value: viewModel.recordStatus)
                )
                .rotationEffect(Angle(degrees: 90))
        }
        .fixedSize()
        .offset(x: 24)
    }
}
