//
//  TruVideo.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import Combine
import Foundation
import UIKit

private extension AVCaptureSession {

    // MARK: Instance methods

    /// Returns the capture device input for the desired media type and capture session, otherwise nil.
    ///
    /// - Parameters:
    ///   - mediaType: Specified media type. (i.e. AVMediaTypeVideo, AVMediaTypeAudio, etc.)
    ///   - captureSession: Capture session for which to query
    /// - Returns: Desired capture device input for the associated media type, otherwise nil
    func deviceInput(for mediaType: AVMediaType) -> AVCaptureDeviceInput? {
        if let inputs = inputs as? [AVCaptureDeviceInput], !inputs.isEmpty {
            return inputs.first { $0.device.hasMediaType(mediaType) }
        }

        return nil
    }
}

private extension AVCaptureDevice {
    /// Returns the primary duo camera video device, if available, else the default wide angel camera, otherwise nil.
    ///
    /// - Parameter position: Desired position of the device
    /// - Returns: Primary video capture device found, otherwise nil
    static func primaryVideoDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera],
            mediaType: .video,
            position: position
        )

        let devices = discoverySession.devices
        return devices.first(where: { $0.deviceType == .builtInDualCamera }) ?? devices.first
    }
}

private extension UIDevice {
    /// Returns the `AVCaptureVideoOrientation`
    var captureVideoOrientation: AVCaptureVideoOrientation {
        switch orientation {
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }
}

private extension UIImage {
    /// Rotates the image by the given radians.
    ///
    /// - Parameter radians: The radians angle.
    /// - Returns: The rotated image.
    func rotate(radians: CGFloat) -> UIImage? {
      var newSize = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians)).size

      newSize.width = floor(newSize.width)
      newSize.height = floor(newSize.height)
      
      UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
      let context = UIGraphicsGetCurrentContext()!
      
      context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
      context.rotate(by: CGFloat(radians))
      
      draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
      
      let newImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      
      return newImage
    }
    
    /// Returns a new image with the given orientation
    ///
    /// - Parameter orientation: The desired orientation for the image
    /// - Returns: A new image with the fixed orientation
    func withOrientation(_ orientation: UIImage.Orientation) -> UIImage? {
        guard let cgImage = cgImage else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }
}

public typealias TruVideoAuthorizationStatus = AVAuthorizationStatus
public typealias TruVideoDeviceOrientation = AVCaptureVideoOrientation
public typealias TruVideoDevicePosition = AVCaptureDevice.Position
public typealias TruVideoFlashMode = AVCaptureDevice.FlashMode
public typealias TruVideoStabilizationMode = AVCaptureVideoStabilizationMode
public typealias TruVideoTorchMode = AVCaptureDevice.TorchMode

let TruVideoMetadataTitle = "TruVideo"
let TruVideoMetadataArtist = "https://truvideo.com/"

/// Operation modes for TruVideoRecorder.
public enum TruVideoRecorderCaptureMode {
    /// Whether is recording only audio.
    case audio

    /// Whether is taking photos.
    case photo

    /// Whether is recording a video.
    case video
}

/// 📸 TruVideoRecorder, Raw Media Capture in Swift
public class TruVideoRecorder: NSObject {
    /// Audio input
    private var audioInput: AVCaptureDeviceInput?

    /// The audio output
    private var audioOutput: AVCaptureAudioDataOutput?

    /// The current subscription  for the recording time, if any.
    private var cancellable: AnyCancellable?

    /// Process metadata objects from an attached connection
    private var captureMetadata: AVCaptureMetadataOutput?

    /// Implements the complete file recording interface for writing media data
    private var captureMovieOutput: AVCaptureVideoDataOutput?

    /// Provides an interface for capture workflows related to still photography
    private var capturePhotoOutput: AVCapturePhotoOutput?

    /// The underlying capture session
    private var captureSession: AVCaptureSession?

    /// Current device
    private var currentDevice: AVCaptureDevice?

    /// Last audio frame recorded
    private var lastAudioFrame: CMSampleBuffer?

    /// Last video frame recorded
    private var lastVideoFrame: CMSampleBuffer?

    /// The last video frame time interval
    private var lastVideoFrameTimeInterval: TimeInterval = 0

    /// Used to mediate access between configurations
    private let lock = NSLock()

    /// Capture metadata output
    private var metadataOutput: AVCaptureMetadataOutput?

    /// Whether the configuration needs to be updated.
    private var needsUpdateConfiguration = false

    /// The current photo continuation if there is any capture in progress
    private var photoContinuation: CheckedContinuation<TruVideoPhoto?, Error>?

    /// Tracks the previous duration of the recording
    private var previousDuration: TimeInterval = 0

    /// The requested device
    private var requestedDevice: AVCaptureDevice?

    /// The session worker queue
    private let sessionQueue: DispatchQueue

    /// Video input
    private var videoInput: AVCaptureDeviceInput?

    /// Video output
    private var videoOutput: AVCaptureVideoDataOutput?

    /// Configuration for the audio.
    public let audioConfiguration: TruAudioConfiguration = .init()

    /// Indicates whether the capture session automatically changes settings in the app’s shared audio session. By default, is `true`.
    public var automaticallyConfiguresApplicationAudioSession = true

    /// When `true` actives device orientation updates
    public var automaticallyUpdatesDeviceOrientation = false

    /// The current capture mode of the device
    public var captureMode: TruVideoRecorderCaptureMode = .video {
        didSet {
            guard captureMode != oldValue else { return }

            /// call delegate
            sessionQueue.async {
                do {
                    try self.configureSession()
                    self.configureSessionDevices()
                    self.configureMetadataObjects()
                    self.updateVideoOrientation()
                    /// Notify delegate
                } catch {
                    print("[TruVideoSession]: 🛑 failed to set the capture mode \(self.captureMode).")
                }
            }
        }
    }

    /// Shared Core Image rendering context.
    public var context: CIContext? = .createDefault()

    /// The current orientation of the device.
    public var deviceOrientation: TruVideoDeviceOrientation = .portrait {
        didSet {
            sessionQueue.async {
                self.automaticallyUpdatesDeviceOrientation = false
                self.updateVideoOrientation()
            }
        }
    }

    /// The current device position.
    private(set) var devicePosition: TruVideoDevicePosition = .back

    /// Flash mode of the device.
    public var flashMode: TruVideoFlashMode {
        get {
            photoConfiguration.flashMode
        }

        set {
            guard photoConfiguration.flashMode != newValue else { return }

            photoConfiguration.flashMode = newValue
        }
    }

    /// Checks if a flash is available.
    public var isFlashAvailable: Bool {
        currentDevice?.hasFlash ?? false
    }

    /// True if the session has been interrupted
    @Published
    public private(set) var isInterrupted = false

    /// Checks if the system is recording.
    public private(set) var isRecording = false

    /// Checks if the system is running.
    public var isRunning: Bool {
        captureSession?.isRunning == true
    }

    /// Checks if a torch is available.
    public var isTorchAvailable: Bool {
        currentDevice?.hasTorch ?? false
    }

    /// Specifies types of metadata objects to detect
    public var metadataObjectTypes: [AVMetadataObject.ObjectType]?

    /// Output directory for the session.
    public var outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory())

    /// Configuration for photos.
    public let photoConfiguration: TruPhotoConfiguration = .init()

    /// Live camera preview, add as a sublayer to the View's primary layer.
    public let previewLayer: AVCaptureVideoPreviewLayer = .init()

    /// Amount of  seconds recorded
    @Published
    public private(set) var secondsRecorded: Double = 0

    /// The current recording session, a powerful means for modifying and editing previously recorded clips.
    private(set) var session: TruVideoSession?

    /// Torch mode of the device.
    public var torchMode: TruVideoTorchMode {
        currentDevice?.torchMode ?? .off
    }

    /// Configuration for  videos.
    public let videoConfiguration: TruVideoConfiguration = .init()

    /// Video stabilization mode
    public var videoStabilizationMode: TruVideoStabilizationMode = .auto {
        didSet {
            lock.lock()
            updateVideoOutputSettings()
            lock.unlock()
        }
    }

    private let TruVideoRecorderQueueIdentifier = "org.TruVideo.CaptureSession"
    private let TruVideoRecorderQueueSpecificKey = DispatchSpecificKey<()>()

    /// Tiff image metadata
    static var tiffMetadata: [String: Any] {
        [
            kCGImagePropertyTIFFSoftware as String: TruVideoMetadataTitle,
            kCGImagePropertyTIFFArtist as String: TruVideoMetadataArtist,
            kCGImagePropertyTIFFDateTime as String: ISO8601DateFormatter().string(from: Date())
        ]
    }
    
    /// Represents all the possible errors that can be thrown.
    public enum TruVideoRecorderError: LocalizedError {
        /// Unable to get the photo data representation.
        case failedToGetPhotoDataRepresentation
        
        /// Video recorder has not initialized photo continuation.
        case photoCaptureInProgress
    }

    // MARK: Initializers

    /// Creates a new instance of `TruVideoRecorder`
    public override init() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.sessionQueue = DispatchQueue(label: TruVideoRecorderQueueIdentifier, qos: .userInteractive)
        self.sessionQueue.setSpecific(key: TruVideoRecorderQueueSpecificKey, value: ())

        super.init()

        configureDeviceObservers()
        configureSessionObservers()

        /// ADD Observers
    }

    // MARK: Instance methods

    /// Triggers a photo capture.
    ///
    /// - Returns: A new instance of `TruVideoPhoto` or nil otherwise
    public func capturePhoto() async throws -> TruVideoPhoto? {
        guard photoContinuation == nil else {
            throw TruVideoError(
                kind: .failedToCapturePhoto,
                underlyingError: TruVideoRecorderError.photoCaptureInProgress
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            guard
                /// capturePhotoOutput
                let capturePhotoOutput = capturePhotoOutput,

                /// format dictionary
                let formatDictionary = photoConfiguration.avDictionary() else {

                return continuation.resume(returning: nil)
            }

            let capturePhotoSettings = AVCapturePhotoSettings(format: formatDictionary)

            capturePhotoSettings.isHighResolutionPhotoEnabled = photoConfiguration.isHighResolutionEnabled
            capturePhotoOutput.isHighResolutionCaptureEnabled = photoConfiguration.isHighResolutionEnabled

            if isFlashAvailable {
                capturePhotoSettings.flashMode = photoConfiguration.flashMode
            }

            photoContinuation = continuation
            capturePhotoOutput.capturePhoto(with: capturePhotoSettings, delegate: self)
        }
    }

    /// Triggers a photo capture from the last video frame.
    ///
    /// - Returns: A new instance of `TruVideoPhoto` or nil otherwise
    public func capturePhotoFromVideo() -> TruVideoPhoto? {
        guard let lastVideoFrame = lastVideoFrame, session != nil else {
            return nil
        }

        let ratio = videoConfiguration.aspectRatio.ratio
        lastVideoFrame.append(metadataAdditions: TruVideoRecorder.tiffMetadata)

        if let photo = context?.image(from: lastVideoFrame) {
            let croppedPhoto = ratio != nil ? photo.croppedImage(to: ratio!) : photo
            if
                /// pngData photo
                var imageData = photo.pngData(),

                /// pngData cropped photo
                let croppedImageData = croppedPhoto.pngData() {
                
                // TODO: Ugly fix :/ no time for refactor
                imageData = UIImage(data: imageData)?.rotate(radians: 3 * .pi / 2)?.pngData() ?? imageData
                
                var metadata = lastVideoFrame.metadata ?? [:]
                metadata[TruVideoPhoto.DeviceOrientationKey] = UIDevice.current.orientation

                return TruVideoPhoto(
                    imageData: imageData,
                    croppedImageData: croppedImageData,
                    metadata: metadata
                )
            }
        }

        return nil
    }

    /// Pauses video recording, preparing 'NextLevel' to start a new clip with 'record()' with completion handler.
    public func pause() async throws {
        guard let session = session, session.hasStartedRecording else {
            print("[TruVideoSession]: ⚠️ unable to pause the session. The session has not started")
            return
        }

        isRecording = false
        previousDuration = secondsRecorded

        do {
            try await session.finishClip()
        } catch {
            print("[TruVideoSession]: 🛑 failed to pause the session error: \(error)")
            throw TruVideoError(kind: .failedToPauseRecording)
        }
    }

    /// Requests access to the underlying hardware for the media type, showing a dialog to the user if necessary.
    ///
    /// - Parameter mediaType: Specified media type (i.e. AVMediaTypeVideo, AVMediaTypeAudio, etc.)
    /// - Throws: An error if the authorization is not granted
    public func requestAuhorization(for mediaType: AVMediaType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            AVCaptureDevice.requestAccess(for: mediaType) { authorized in
                guard authorized else {
                    continuation.resume(throwing: TruVideoError(kind: .accessDenied))
                    return
                }

                continuation.resume()
            }
        }
    }

    /// Initiates video recording, managed as a clip within the `TruVideoSession`
    public func record() {
        sessionQueue.sync {
            self.isRecording = true
            if self.session != nil {
                self.beginNewClipIfNecessary()
            }
        }
    }

    /// Sets the capture device position
    ///
    /// - Parameter position: Indicates the physical position of an AVCaptureDevice's hardware on the system.
    public func setDevicePosition(_ position: TruVideoDevicePosition) async {
        let resumeRecording = isRecording
        devicePosition = position
        
        if isRecording {
            do {
                try await pause()
            } catch {
                print("[TruVideoSession]: ⚠️ unable to pause the recording before flipping device position")
            }
        }

        cleanupAVSession()
        try? setupAVSession()
        if resumeRecording {
            record()
        }
    }

    /// Sets whether the the configuration needs to be updated
    public func setNeedsUpdateConfiguration() {
        needsUpdateConfiguration = true
    }

    /// Sets the torch mode to the current device
    ///
    /// - Parameter mode: The new torch mode
    /// - Throws: An error when the torch is not available or not supported
    public func setTorchMode(_ mode: TruVideoTorchMode) throws {
        guard isTorchAvailable else {
            throw TruVideoError(kind: .torchNotAvailable)
        }

        try executeSync {
            guard let currentDevice = self.currentDevice, currentDevice.hasTorch, currentDevice.torchMode != mode else {
                return
            }

            do {
                try currentDevice.lockForConfiguration()

                if currentDevice.isTorchModeSupported(mode) {
                    currentDevice.torchMode = mode
                } else {
                    throw TruVideoError(kind: .torchNotSupported)
                }

                currentDevice.unlockForConfiguration()
            } catch {
                print("[TruVideoSession]: ⚠️ failed to set torch \(mode.rawValue).")
                throw TruVideoError(kind: .failedToSetTorch, underlyingError: error)
            }
        }
    }

    /// Starts the current recording session.
    ///
    /// - Throws: `TruVideoRecorderError.notAuthorized` when permissions are not authorized,
    ///           `TruVideoRecorderError.recordInProgress` when the session has already started.
    public func start() throws {
        guard authorizationStatusForCurrentCaptureMode() == .authorized else {
            throw TruVideoError(kind: .notAuthorized)
        }

        guard captureSession == nil else {
            throw TruVideoError(kind: .recordInProgress)
        }

        try setupAVSession()
    }

    /// Stops the current recording session.
    ///
    /// - Parameter preset: AVAssetExportSession preset name for export.
    /// - Returns: A new `TruVideoClip`.
    @MainActor
    public func stopRecording(usingPreset preset: String) async throws -> TruVideoClip? {
        guard let session = session else {
            return nil
        }

        defer {
            cleanupAVSession()
            self.session = nil
            previousDuration = 0
            secondsRecorded = 0
        }

        do {
            try await session.finishClip()
            if session.clips.count > 1 {
                let url = try await session.mergeClips(usingPreset: preset)
                return .init(url: url)
            }

            return session.clips.last
        } catch {
            print("[TruVideoSession]: 🛑 failed to stop recording error: \(error).")
            throw TruVideoError(kind: .failedToStopRecording, underlyingError: error)
        }
    }

    // MARK: Static methods

    /// Returns the client's authorization status for accessing the underlying hardware that supports a given media type.
    ///
    /// - Parameter mediaType: Specified media type (i.e. AVMediaTypeVideo, AVMediaTypeAudio, etc.)
    /// - Returns: Authorization status for the desired media type.
    public static func authorizationStatus(for mediaType: AVMediaType) -> TruVideoAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: mediaType)
    }

    // MARK: Notification methods

    @objc
    private func deviceOrientationDidChangeNotification(_ notification: Notification) {
        guard automaticallyUpdatesDeviceOrientation else {
            return
        }

        sessionQueue.sync {
            self.updateVideoOrientation()
        }
    }
    
    @objc
    private func didReceiveSessionInterruptionEndedNotification(_ notification: Notification) {
        isInterrupted = false
    }

    @objc
    private func didReceiveSessionRuntimeErrorNotification(_ notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            switch error.code {
            case .deviceIsNotAvailableInBackground:
                print("[TruVideoSession]: 🛑 media services are not available in the background")
                break
            case .mediaServicesWereReset: fallthrough
            default: break
            }
        }
    }

    @objc
    private func didReceiveSessionWasInterruptedNotification(_ notification: Notification) {
        isInterrupted = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] != nil
        if !isInterrupted && captureSession?.isInterrupted == true && UIApplication.shared.applicationState != .background {
            sessionQueue.async {
                self.captureSession?.stopRunning()
                self.captureSession?.startRunning()
            }
        }
    }

    // MARK: Private methods

    private func addAudioOuput() throws {
        if audioOutput == nil {
            audioOutput = AVCaptureAudioDataOutput()
        }

        guard
            /// The underlying capture session
            let captureSession = captureSession,

            /// Audio output
            let audioOutput = audioOutput, captureSession.canAddOutput(audioOutput) else {

            throw TruVideoError(kind: .cannotAddAudioOutput)
        }

        captureSession.addOutput(audioOutput)
        audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    }

    private func addInput(with captureDevice: AVCaptureDevice) throws {
        guard let captureSession = captureSession else {
            return
        }

        let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)

        guard captureSession.canAddInput(captureDeviceInput) else {
            throw TruVideoError(kind: .cannotAddDevice)
        }

        if captureDeviceInput.device.hasMediaType(.video) {
            /// ADD OBSERVERS
            videoInput = captureDeviceInput
        } else {
            audioInput = captureDeviceInput
        }

        captureSession.addInput(captureDeviceInput)
    }

    private func addPhotoOutput() throws {
        if capturePhotoOutput == nil {
            capturePhotoOutput = AVCapturePhotoOutput()
        }

        guard
            /// The underlying capture session
            let captureSession = captureSession,

            /// Capture photo output
            let capturePhotoOutput = capturePhotoOutput, captureSession.canAddOutput(capturePhotoOutput) else {

            throw TruVideoError(kind: .cannotAddAudioOutput)
        }

        captureSession.addOutput(capturePhotoOutput)        
    }

    private func addVideoOutput() throws {
        if videoOutput == nil {
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.alwaysDiscardsLateVideoFrames = false

            var videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)]

            if let formatTypes = videoOutput?.availableVideoPixelFormatTypes {
                var supportsFullRange = false
                var supportsVideoRange = false

                for formatType in formatTypes {
                    if formatType == Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                        supportsFullRange = true
                    }
                    if formatType == Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
                        supportsVideoRange = true
                    }
                }
                
                let settingsKey = String(kCVPixelBufferPixelFormatTypeKey)

                if supportsFullRange {
                    videoSettings[settingsKey] = Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                } else if supportsVideoRange {
                    videoSettings[settingsKey] = Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                }
            }

            videoOutput?.videoSettings = videoSettings
        }

        if
            /// Capture session
            let captureSession = captureSession,

            /// VideoOutput
            let videoOutput = videoOutput {

            if captureSession.canAddOutput(videoOutput) {
                videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                captureSession.addOutput(videoOutput)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.updateVideoOutputSettings()
                }
            } else {
                print("[TruVideoSession]: 🛑 failed to set add video output")
                throw TruVideoError(kind: .cannotAddVideoOutput)
            }
        }
    }

    private func authorizationStatusForCurrentCaptureMode() -> TruVideoAuthorizationStatus {
        switch captureMode {
        case .audio: return TruVideoRecorder.authorizationStatus(for: .audio)
        case .photo: return TruVideoRecorder.authorizationStatus(for: .video)
        case .video:
            let audioStatus = TruVideoRecorder.authorizationStatus(for: .audio)
            let videoStatus = TruVideoRecorder.authorizationStatus(for:  .video)
            return (audioStatus == .authorized && videoStatus == .authorized) ? .authorized : .denied
        }
    }

    private func beginNewClipIfNecessary() {
        guard let session = session, !session.isReady else { return }

        try? session.beginNewClip()
        DispatchQueue.main.async {
        /// ntify delegate
        }
    }

    private func checkSessionDuration() async {
        guard
            /// Current session.
            let session = session,

            /// The maximun duration allowed to record.
            let maximumCaptureDuration = videoConfiguration.maximumCaptureDuration,
            maximumCaptureDuration.isValid && session.totalDuration >= maximumCaptureDuration else { return }

        isRecording = false
        do {
            let _ = try await session.finishClip()
            DispatchQueue.main.async {
                //self.videoDelegate?.nextLevel(self, didCompleteClip: clip, inSession: session)
            }
        } catch {
            print("[TruVideoSession]: ⚠️ failed to finish the clip that exceeds the max duration.")
        }

        DispatchQueue.main.async {
            //self.videoDelegate?.nextLevel(self, didCompleteSession: session)
        }
    }

    private func cleanupAVSession() {
        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }

        removeInputs()
        removeOutputs()

        self.captureSession = nil
        currentDevice = nil
        isRecording = false
        previewLayer.session = nil
        session?.reset()
    }

    private func configureDevice(_ captureDevice: AVCaptureDevice, for mediaType: AVMediaType) throws {
        guard let captureSession = captureSession else { return }

        if let currentDeviceInput = captureSession.deviceInput(for: mediaType),
           currentDeviceInput.device == captureDevice {
            return
        }

        if mediaType == .video {
            do {
                try captureDevice.lockForConfiguration()

                if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
                    captureDevice.focusMode = .continuousAutoFocus

                    if captureDevice.isSmoothAutoFocusSupported {
                        captureDevice.isSmoothAutoFocusEnabled = true
                    }
                }

                if captureDevice.isExposureModeSupported(.continuousAutoExposure) {
                    captureDevice.exposureMode = .continuousAutoExposure
                }

                if captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                }

                captureDevice.isSubjectAreaChangeMonitoringEnabled = true

                if captureDevice.isLowLightBoostSupported {
                    captureDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
                }

                captureDevice.unlockForConfiguration()
            } catch {
                print("[TruVideoSession]: ⚠️ failed to lock device for configuration.")
            }
        }

        if let currentDeviceInput = captureSession.deviceInput(for: mediaType) {
            captureSession.removeInput(currentDeviceInput)

            if currentDeviceInput.device.hasMediaType(.video) {
                /// REMOVE OBSERVERS
            }
        }

        try addInput(with: captureDevice)
    }

    private func configureMetadataObjects() {
        guard
            /// Capture session
            let captureSession = captureSession,

            /// metadataObjectTypes
            let metadataObjectTypes = metadataObjectTypes, !metadataObjectTypes.isEmpty else { return }

        if metadataOutput == nil {
            metadataOutput = AVCaptureMetadataOutput()
        }

        guard let metadataOutput = metadataOutput else { return }

        if !captureSession.outputs.contains(metadataOutput), captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = metadataObjectTypes.filter {
                metadataOutput.availableMetadataObjectTypes.contains($0)
            }
        }
    }

    private func configureDeviceObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChangeNotification(_:)),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    private func configureSession() throws {
        guard let captureSession = captureSession else {
            return
        }

        lock.lock()
        defer {
            captureSession.commitConfiguration()
            lock.unlock()
        }

        captureSession.beginConfiguration()
        removeUnusedOuputs(for: captureSession)

        switch captureMode {
        case .audio: try addAudioOuput()
        case .photo:
            if captureSession.sessionPreset != photoConfiguration.preset {
                guard captureSession.canSetSessionPreset(photoConfiguration.preset) else {
                    throw TruVideoError(kind: .cannotSetPresset)
                }
            }

            try addPhotoOutput()

        case .video:
            if captureSession.sessionPreset != videoConfiguration.preset {
                if captureSession.canSetSessionPreset(videoConfiguration.preset) {
                    captureSession.sessionPreset = videoConfiguration.preset
                } else {
                    print("[TruVideoSession]: ⚠️ failed to set present \(videoConfiguration.preset).")
                }
            }

            try addAudioOuput()
            try addPhotoOutput()
            try addVideoOutput()
        }
    }

    private func configureSessionDevices() {
        guard let captureSession = captureSession else {
            return
        }

        lock.lock()
        captureSession.beginConfiguration()

        defer {
            captureSession.commitConfiguration()
            lock.unlock()
        }

        var shouldConfigureVideo = false
        var shouldConfigureAudio = false

        switch captureMode {
        case .audio: shouldConfigureAudio = true
        case .photo: shouldConfigureVideo = true
        case .video:
            shouldConfigureVideo = true
            shouldConfigureAudio = true
        }

        if shouldConfigureVideo {
            var captureDevice: AVCaptureDevice?

            captureDevice = requestedDevice ?? AVCaptureDevice.primaryVideoDevice(for: devicePosition)

            if let captureDevice = captureDevice, captureDevice != currentDevice {
                do {
                    try configureDevice(captureDevice, for: .video)
                } catch {
                    print("[TruVideoSession]: ⚠️ failed to configure the video device error: \(error).")
                }

                let changingPosition = captureDevice.position != currentDevice?.position

                if changingPosition {
                    /*DispatchQueue.main.async {
                        self.deviceDelegate?.nextLevelDevicePositionWillChange(self)
                    }*/
                }
                
                willChangeValue(forKey: "currentDevice")
                currentDevice = captureDevice
                
                didChangeValue(forKey: "currentDevice")
                requestedDevice = nil

                if changingPosition {
                    /*DispatchQueue.main.async {
                        self.deviceDelegate?.nextLevelDevicePositionDidChange(self)
                    }*/
                }
            }
        }

        if shouldConfigureAudio {
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                do {
                    try configureDevice(audioDevice, for: .audio)
                } catch {
                    print("[TruVideoSession]: ⚠️ failed to configure the audio device error: \(error).")
                }
            }
        }
    }

    private func configureSessionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveSessionRuntimeErrorNotification(_:)),
            name: .AVCaptureSessionRuntimeError,
            object: captureSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveSessionWasInterruptedNotification(_:)),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveSessionWasInterruptedNotification(_:)),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )
    }

    private func executeSync(_ closure: @escaping () throws -> Void) throws {
        if DispatchQueue.getSpecific(key: TruVideoRecorderQueueSpecificKey) != nil {
            try closure()
        } else {
            try sessionQueue.sync(execute: closure)
        }
    }

    private func handleAudioBuffer(_ sampleBuffer: CMSampleBuffer, in session: TruVideoSession) {
        if !session.hasConfiguredAudio {
            if
                /// Audio settings
                let settings = audioConfiguration.avcaptureSettingsDictionary(sampleBuffer: sampleBuffer),

                /// Format description
                let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {

                if !session.configureAudio(
                    with: settings,
                    configuration: audioConfiguration,
                    formatDescription: formatDescription
                ) {
                    print("[TruVideoSession]: ⚠️ Could not setup audio")
                }
            }

            /// Notify delegate
        }

        if isRecording && session.hasConfiguredVideo && session.hasStartedRecording && session.currentClipHasVideo {
            beginNewClipIfNecessary()

            if session.appendAudioBuffer(sampleBuffer) {
                DispatchQueue.main.async {
                    /// Notify delegate
                }

                Task {
                    await self.checkSessionDuration()
                }
            } else {
                DispatchQueue.main.async {
                    /// Notify delegate
                }
            }
        }
    }

    private func handleVideoBuffer(_ sampleBuffer: CMSampleBuffer, in session: TruVideoSession) {
        if !session.hasConfiguredVideo || needsUpdateConfiguration {
            if
                /// Video settings
                let settings = videoConfiguration.avcaptureSettingsDictionary(sampleBuffer: sampleBuffer),

                /// Format description
                let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {

                if !session.configureVideo(
                    with: settings,
                    configuration: videoConfiguration,
                    formatDescription: formatDescription
                ) {
                    print("[TruVideoSession]: ⚠️ Could not setup video")
                } else {
                    needsUpdateConfiguration = false
                }
            }

            /// Notify delegate
        }

        if isRecording && session.hasConfiguredAudio && session.hasStartedRecording {
            beginNewClipIfNecessary()

            let minTimesBetweenFrames = 0.004
            let sleepDuration = minTimesBetweenFrames - CACurrentMediaTime() - lastVideoFrameTimeInterval
            if sleepDuration > 0 {
                Thread.sleep(forTimeInterval: sleepDuration)
            }

            guard let currentDevice = currentDevice else { return }

            lastVideoFrameTimeInterval = CACurrentMediaTime()

            if session.appendVideoBuffer(sampleBuffer, minFrameDuration: currentDevice.activeVideoMinFrameDuration) {
                DispatchQueue.main.async {
                    /// Notify delegate
                }

                Task {
                    await checkSessionDuration()
                }
            } else {
                DispatchQueue.main.async {
                    /// Notify delegate
                }
            }
        }
    }

    private func removeInputs() {
        guard
            /// The current capture session
            let captureSession = captureSession,

            /// Capture device inputs
            let inputs = captureSession.inputs as? [AVCaptureDeviceInput] else { return }

        for input in inputs {
            captureSession.removeInput(input)
            if input.device.hasMediaType(.video) {
                /// remove observers
            }
        }

        videoInput = nil
        videoOutput = nil
    }

    private func removeOutputs() {
        guard let captureSession = captureSession else {
            return
        }

        if capturePhotoOutput != nil {
           // self.removeCaptureOutputObservers()
        }

        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        capturePhotoOutput = nil
        audioOutput = nil
        metadataOutput = nil
        videoOutput = nil
    }

    private func removeUnusedOuputs(for captureSession: AVCaptureSession) {
        switch captureMode {
        case .audio:
            if let audioOutput = audioOutput, captureSession.outputs.contains(audioOutput) {
                captureSession.removeOutput(audioOutput)
                self.audioOutput = nil
            }

        case .photo:
            if let audioOutput = audioOutput, captureSession.outputs.contains(audioOutput) {
                captureSession.removeOutput(audioOutput)
                self.audioOutput = nil
            }

            if let videoOutput = videoOutput, captureSession.outputs.contains(videoOutput) {
                captureSession.removeOutput(videoOutput)
                self.videoOutput = nil
            }

        case .video:
            if let capturePhotoOutput = capturePhotoOutput, captureSession.outputs.contains(capturePhotoOutput) {
                captureSession.removeOutput(capturePhotoOutput)
                self.capturePhotoOutput = nil
            }
        }
    }

    private func setupAVSession() throws {
        let captureSession = AVCaptureSession()
        captureSession.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession

        self.captureSession = captureSession
        self.session = self.session ?? TruVideoSession(queue: sessionQueue)
        self.session?.outputDirectory = outputDirectory
        self.previewLayer.session = captureSession

        try configureSession()
        configureSessionDevices()
        configureMetadataObjects()
        updateVideoOrientation()
        
        if let session = session {
            cancellable?.cancel()
            cancellable = session.$totalDuration
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [self] totalDuration in
                    if totalDuration.seconds > 0 {
                        self.secondsRecorded = self.previousDuration + totalDuration.seconds
                    }
                })
        }

        if !captureSession.isRunning {
            /// Notify delegate
            sessionQueue.async {
                captureSession.startRunning()
            }
            /// Notify delegate
        }
    }

    private func updateVideoOutputSettings() {
        guard let videoConnection = videoOutput?.connection(with: .video) else {
            return
        }

        videoConnection.automaticallyAdjustsVideoMirroring = devicePosition != .front
        if !videoConnection.automaticallyAdjustsVideoMirroring {
            videoConnection.isVideoMirrored = devicePosition == .front
        }

        if videoConnection.isVideoStabilizationSupported {
            videoConnection.preferredVideoStabilizationMode = videoStabilizationMode
        }
    }

    private func updateVideoOrientation() {
        if let session = session, !session.currentClipHasAudio && !session.currentClipHasVideo {
            session.reset()
        }

        var didChangeOrientation = false
        let currentOrientation = automaticallyUpdatesDeviceOrientation ?
            UIDevice.current.captureVideoOrientation :
            deviceOrientation

        if let previewConnection = previewLayer.connection,
            previewConnection.isVideoOrientationSupported,
            previewConnection.videoOrientation != currentOrientation {

            previewConnection.videoOrientation = currentOrientation
            didChangeOrientation = true
        }

        if
            /// The current capture photo output
            let capturePhotoOutput = capturePhotoOutput,

            /// Photo connection
            let photoConnection = capturePhotoOutput.connection(with: .video),
                photoConnection.isVideoOrientationSupported,
                photoConnection.videoOrientation != currentOrientation {

            photoConnection.videoOrientation = currentOrientation
            didChangeOrientation = true
        }

        if let videoConnection = videoOutput?.connection(with: .video),
                videoConnection.isVideoOrientationSupported,
                videoConnection.videoOrientation != currentOrientation {

            videoConnection.videoOrientation = currentOrientation
            didChangeOrientation = true
        }

        if didChangeOrientation {
            /// Notify
        }
    }
}

extension TruVideoRecorder: AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate & AVCaptureVideoDataOutputSampleBufferDelegate

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {

        if
            /// Audio ouput
            let audioOutput = audioOutput,

            /// Video output
            let videoOutput = videoOutput {

            switch output {
            case audioOutput:
                lastAudioFrame = sampleBuffer

                if let session = session {
                    handleAudioBuffer(sampleBuffer, in: session)
                }

            case videoOutput:
                lastVideoFrame = sampleBuffer
                /// notify delegate
                if let session = session {
                    handleVideoBuffer(sampleBuffer, in: session)
                }

            default: break
            }
        }
    }
}

extension TruVideoRecorder: AVCaptureMetadataOutputObjectsDelegate {

    // MARK: AVCaptureMetadataOutputObjectsDelegate

    public func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {

    }
}

extension TruVideoRecorder: AVCapturePhotoCaptureDelegate {

    // MARK: AVCapturePhotoCaptureDelegate

    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {

        defer {
            photoContinuation = nil
        }

        if let error = error {
            photoContinuation?.resume(throwing: TruVideoError(kind: .failedToCapturePhoto, underlyingError: error))
            return
        }

        guard var data = photo.fileDataRepresentation() else {
            photoContinuation?.resume(
                throwing: TruVideoError(
                    kind: .failedToCapturePhoto,
                    underlyingError: TruVideoRecorderError.failedToGetPhotoDataRepresentation
                )
            )

            return
        }

        var metadata = photo.metadata
        metadata[TruVideoPhoto.DeviceOrientationKey] = UIDevice.current.orientation
        TruVideoRecorder.tiffMetadata.forEach { key, value in
            metadata[key] = value
        }

        /// TODO: FIX ME this should not be here check for a way to fix rotations for front camera
        let image = UIImage(data: data)

        if devicePosition == .front {
            data = image?.rotate(radians: .pi / 2)?.pngData() ?? data
        } else {
            data = image?.withOrientation(.left)?.pngData() ?? data
        }

        let photo = TruVideoPhoto(imageData: data, croppedImageData: data, metadata: metadata)
        photoContinuation?.resume(returning: photo)
    }
}
