//
//  CameraViewModel.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import Combine
import SwiftUI

private extension URL {
    /// An URL object containing the URL of the output file.
    static var outputFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
    }
}

private extension AVCaptureSession.Preset {
    /// Returns the export preset.
    var exportPreset: String {
        switch self {
        case .vga640x480: return AVAssetExportPreset640x480
        case .hd1280x720: return AVAssetExportPreset1280x720
        default: return AVAssetExportPreset1920x1080
        }
    }
}

/// Represents the posibles status of a
/// capture photo process.
enum CapturePhotoStatus {
    /// Initial state
    case initial

    /// When photo is being captured
    case capturing

    /// Whether the capture photo has failed
    case failed

    /// Whether the recording has finished
    case finished
}

/// Represents the possible status when
/// loading data.
enum DataLoadStatus {
    /// Initial state
    case initial

    /// Whether the status is loading
    /// any async call
    case loading

    /// Flags the status as failed
    case failure

    /// Whether the status is refreshing
    /// Normally used for pull down to refreshs
    case refreshing

    /// Whether the async call has been finished
    /// succesfully
    case success
}

/// Represents the posibles status of the
/// recording video process.
enum RecordStatus {
    /// Initial state
    case initial

    /// When the camera has been initialized
    case initialized

    /// Whether the recording has finished
    case finished

    /// Whether is paused
    case paused

    /// Whether is recording
    case recording

    /// Whether video is being saved
    case saving
}

/// Represents the posibles status for the torch.
enum TorchStatus {
    /// When the camera has been initialized
    case notSupported

    /// Whether is paused
    case off

    /// Whether the recording has finished
    case on
    
    /// Returns the `TruVideoFlashMode` for the current status.
    fileprivate var flashMode: TruVideoFlashMode {
        self == .on ? .on : .off
    }
    
    /// Returns the `TruVideoTorchMode` for the current status.
    fileprivate var torchMode: TruVideoTorchMode {
        self == .on ? .on : .off
    }
}

/// Handles the comunication between the `CameraViewModel` with its state and events.
public class CameraViewModel: ObservableObject {
    private var backTorchStatus: TorchStatus = .notSupported
    private var cancellables = Set<AnyCancellable>()
    private var frontTorchStatus: TorchStatus = .notSupported
    private let outputFileURL: URL
    private let recorder: TruVideoRecorder
    
    /// The current camera position.
    @Published private(set) var cameraPosition: TruVideoDevicePosition = .back

    /// Current capture photo status.
    @Published private(set) var capturePhotoStatus: CapturePhotoStatus = .initial

    /// The clips generated during the session.
    @Published private(set) var clips: [TruVideoClip] = []

    /// The photos taken in this session.
    @Published private(set) var photos: [TruVideoPhoto] = []

    /// Current record status.
    @Published private(set) var recordStatus: RecordStatus = .initial

    /// The amount of seconds recorded.
    @Published private(set) var secondsRecorded: Double = 0

    /// Current loading status.
    @Published private(set) var status: DataLoadStatus = .initial

    /// The current torch status depending of the camera position.
    @Published private(set) var torchStatus: TorchStatus = .notSupported

    /// The current image quality of the camera.
    @Published var imageQuality: AVCaptureSession.Preset = .medium {
        didSet {
            recorder.videoConfiguration.preset = imageQuality
        }
    }
    
    /// The current `AVCaptureVideoPreviewLayer`.
    var previewLayer: AVCaptureVideoPreviewLayer {
        recorder.previewLayer
    }

    // MARK: Initializers
    
    /// Creates a new instance of the `CameraViewModel`.
    ///
    /// - Parameters:
    ///    - recorder: The Raw Media Capture object.
    ///    - outputFileURL: The  output file URL for video recording.
    public init(recorder: TruVideoRecorder, outputFileURL: URL? = nil) {
        self.outputFileURL = outputFileURL ?? .outputFileURL
        self.recorder = recorder

        recorder.$isInterrupted
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [self] _ in
                handlePauseRecording()
            }
            .store(in: &cancellables)
    }

    deinit {
        print("") // NOT CALLED
    }
    
    // MARK: Instance methods
    
    /// Handles the `BeginConfigurationEvent` and emits the updated state for the view.
    func beginConfiguration() {
        status = .loading

        Task { @MainActor in
            do {
                if TruVideoRecorder.authorizationStatus(for: .video) != .authorized {
                    try await recorder.requestAuhorization(for: .video)
                }

                if TruVideoRecorder.authorizationStatus(for: .audio) != .authorized {
                    try await recorder.requestAuhorization(for: .audio)
                }

                recorder.videoConfiguration.transform = UIDevice.current.orientation == .landscapeLeft ?
                    .init(rotationAngle: 3 * .pi / 2) :
                    .init(rotationAngle: .pi / 2)

                recorder.outputDirectory = outputFileURL
                recorder.videoStabilizationMode = .off
                recorder.videoConfiguration.preset = .vga640x480

                try recorder.start()

                recorder.photoConfiguration.flashMode = recorder.isTorchAvailable ? .on : .off
                recordStatus = .initialized
                torchStatus = recorder.isTorchAvailable ? .on : .notSupported
                status = .success
            } catch {
                status = .failure
            }
        }
    }

    /// Flips the video camera's video output.
    ///
    /// - Note: This method allows you to flip the video camera's video output, which can be useful for
    /// applying various transformations or adjusting the camera orientation.
    public func flipCamera() {
        Task {
            guard status == .success else {
                return
            }
            
            let cameraPosition = cameraPosition == .back ? AVCaptureDevice.Position.front : .back

            await recorder.setDevicePosition(cameraPosition)

            if !recorder.isTorchAvailable {
                if cameraPosition == .front {
                    self.cameraPosition = cameraPosition
                    frontTorchStatus = .notSupported
                } else {
                    self.cameraPosition = cameraPosition
                    torchStatus = .notSupported
                }
            } else {
                self.cameraPosition = cameraPosition
            }
        }
    }
    
    /// Pauses the current video recording.
    ///
    /// - Note: This method allows you to pause the current video recording that is in progress.
    public func pause() {
        handlePauseRecording()
    }
    
    /// Starts recording a video using the specified camera device.
    ///
    /// - Note: This method allows you to start recording a video using the camera device.
    public func record() {
        guard status == .success else {
            return
        }
        
        if torchStatus != .notSupported {
            do {
                try recorder.setTorchMode(torchStatus.torchMode)
            } catch {
                torchStatus = .notSupported
            }
        }

        recorder.videoConfiguration.transform = UIDevice.current.orientation == .landscapeLeft ?
            .init(rotationAngle: 3 * .pi / 2) :
            .init(rotationAngle: .pi / 2)

        recorder.setNeedsUpdateConfiguration()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.recorder.$secondsRecorded
                .assign(to: \.secondsRecorded, on: self)
                .store(in: &self.cancellables)

            self.recorder.record()
            self.recordStatus = .recording
        }
    }
    
    /// Stops the current video recording.
    ///
    /// - Note: This method allows you to stop the current video recording that is in progress.
    public func stopRecording() {
        Task { @MainActor in
            guard status == .success else {
                return
            }
            
            defer {
                recordStatus = .finished
            }
            
            do {
                if let clip = try await recorder.stopRecording(
                    usingPreset: recorder.videoConfiguration.preset.exportPreset
                ) {
                    
                    clips.append(clip)
                }
            } catch {
                // TODO: Log error
                print(error)
            }
        }
    }
    
    /// Takes a photo using the specified camera device.
    ///
    /// - Note: This method allows you to capture a photo using the camera device.
    public func takePhoto() {
        Task { @MainActor in
            guard status == .success else {
                return
            }
            
            do {
                let isRecording = recordStatus == .recording
                
                capturePhotoStatus = .capturing
                
                guard let photo = isRecording ?
                        recorder.capturePhotoFromVideo() :
                        try await recorder.capturePhoto() else {
                    
                    capturePhotoStatus = .failed
                    return
                }
                
                capturePhotoStatus = .finished
                photos.append(photo)
            } catch {
                capturePhotoStatus = .failed
            }
        }
    }
    
    /// Toggles the torch (flashlight) on the specified camera device.
    ///
    /// - Note: This method allows you to toggle the torch (flashlight) on or off for the specified camera device.
    func toggleTorch() {
        guard recorder.isTorchAvailable, status == .success else {
            return
        }

        do {
            let torchStatus = torchStatus == .off ? TorchStatus.on : .off

            if recordStatus == .recording {
                try recorder.setTorchMode(torchStatus.torchMode)
            }

            recorder.flashMode = torchStatus.flashMode
            self.torchStatus = torchStatus

            if cameraPosition == .front {
                frontTorchStatus = torchStatus
            } else {
                backTorchStatus = torchStatus
            }
        } catch {
            if cameraPosition == .front {
                frontTorchStatus = .notSupported
            } else {
                backTorchStatus = .notSupported
            }
        }
    }
    
    // MARK: Private methods

    /// Handles the `PauseRecordingEvent` and emits the updated state for the view.
    private func handlePauseRecording() {
        Task { @MainActor in
            guard recorder.isRecording, status == .success else {
                return
            }
            
            if torchStatus != .notSupported {
                do {
                    try recorder.setTorchMode(.off)
                } catch {
                    torchStatus = .notSupported
                }
            }

            do {
                try await recorder.pause()
                recordStatus = .paused
            } catch {
                status = .failure
            }
        }
    }
}
