//
//  RecordButton.swift
//  TruVideoExample
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import SwiftUI

/// A circular button with some functionality to enable/disable
/// dependeing of the current orientation.
struct RecordButton: View {
    /// Whether the user is long pressing the button
    @State private var isOnLongPressing = false
    
    /// The radius of the circule inside the button.
    private var innerCircleWidth: CGFloat {
        viewModel.recordStatus == .recording ? 45 : 60
    }

    /// The current orientation state of the device
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
        ) { recordStatus in

            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: 70, height: 70)
                
                RoundedRectangle(cornerRadius: recordStatus == .recording ? 8 : innerCircleWidth / 2)
                    .fill(orientation.canDisplayCamera || recordStatus == .recording ? .red : .gray.opacity(0.5))
                    .frame(width: innerCircleWidth, height: innerCircleWidth)
            }
            .scaleEffect(x: isOnLongPressing ? 0.8 : 1, y: isOnLongPressing ? 0.8 : 1)
            .animation(.spring(response: 1, dampingFraction: 0.5, blendDuration: 1), value: isOnLongPressing)
            .onLongPressGesture(minimumDuration: 0.3, perform: onLongPress)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded(onDragEnded)
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded(onTapEnded)
            )
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                withAnimation {
                    orientation = .init(previous: orientation.current, current: UIDevice.current.orientation)
                }
            }
        }
    }

    // MARK: Private methods

    private func onDragEnded(_ value: DragGesture.Value) {
        let dragAllowed = orientation.canDisplayCamera || viewModel.recordStatus == .recording
        
        guard isOnLongPressing && dragAllowed else { return }
        
        viewModel.record()
        
        withAnimation {
            isOnLongPressing.toggle()
        }
    }

    private func onLongPress() {
        guard orientation.canDisplayCamera || viewModel.recordStatus == .recording else { return }

        withAnimation {
            isOnLongPressing.toggle()
        }
    }

    private func onTapEnded(_ value: TapGesture.Value) {
        guard orientation.canDisplayCamera else { return }
        guard viewModel.recordStatus == .recording else {
            viewModel.record()
            return
        }

        viewModel.stopRecording()
    }
}
