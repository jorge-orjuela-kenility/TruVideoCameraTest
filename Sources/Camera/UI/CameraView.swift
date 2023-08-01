//
//  RecordVideoView.swift
//  TruVideoExample
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import AVKit
import SwiftUI

extension UIDeviceOrientation {
    /// Returns the rotation angle for the current `UIDeviceOrientation`.
    var angle: Angle? {
        switch self {
        case .faceDown, .faceUp: return nil
        case .landscapeLeft: return Angle.degrees(90)
        case .landscapeRight: return Angle.degrees(-90)
        case .portrait: return Angle.degrees(0)
        default: return Angle.degrees(-180)
        }
    }
}

extension UIDeviceOrientation {
    /// Whether the orientation is allowed for recording.
    var isAllowedForRecording: Bool {
        [UIDeviceOrientation.landscapeLeft].contains(self)
    }
}

/// A result of the recording session.
public struct RecordingResult {
    /// The clips recorded during the session.
    let clips: [TruVideoClip]

    /// The photos taken during the session.
    let photos: [TruVideoPhoto]
}

/// The Camera View is a custom SwiftUI view designed to provide a camera interface within your iOS  app.
/// This view allows users to access their device's camera to capture photos or record videos.
/// The Camera View simplifies the process of integrating camera functionality into your app, making it easier
/// for users to interact with the camera and capture media seamlessly.
public struct CameraView: View {
    private let onComplete: (RecordingResult) -> Void
    
    /// An action that dismisses the view.
    @Environment(\.dismiss) var dismiss
    
    /// A boolean indicating whether the preview is presented.
    @State var isPresented = false
    
    /// The view model handling the logic and data for camera features.
    @StateObject private var viewModel = CameraViewModel(recorder: .init())

    /// The content and behavior of the view.
    public var body: some View {
        NavigationView {
            ZStack {
                Camera(dismiss: dismiss)
                PublisherListener(
                    initialValue: viewModel.recordStatus,
                    publisher: viewModel.$recordStatus,
                    buildWhen: { previous, current in previous != current }
                ) { _ in
                    EmptyView()
                }
                .listen(when: { previous, current in previous != current }) { state in
                    UIApplication.shared.isIdleTimerDisabled = state == .recording
                }
            }
            .environmentObject(viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarHidden(true)
            .statusBar(hidden: true)
            .fullScreenCover(isPresented: $isPresented, onDismiss: dismiss.callAsFunction) {
                VideoPreview(url: viewModel.clips.last!.url)
            }
            .onAppear(perform: viewModel.beginConfiguration)
        }
    }
    
    // MARK: Initializers
    
    /// Creates a new instance of the `CameraView`.
    ///
    /// - Parameter onComplete: A callback to invoke when the recording session has finished.
    public init(onComplete: @escaping (RecordingResult) -> Void) {
        self.onComplete = onComplete
    }
}
