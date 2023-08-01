//
//  CaptureMovieOutput.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import UIKit

private extension Dictionary where Key == String {
    /// Returns true if the dictionary contains a valid settings
    /// for the video input
    var hasValidVideoSettings: Bool {
        self[AVVideoCodecKey] != nil && self[AVVideoHeightKey] != nil && self[AVVideoWidthKey] != nil
    }
}

private extension AVCaptureVideoOrientation {
    /// Returns the natural size for the current video orientation.
    var naturalSize: CGSize {
        switch self {
        case .landscapeLeft, .landscapeRight:
            return .init(width: UIScreen.main.bounds.height, height: UIScreen.main.bounds.width)

        default: return UIScreen.main.bounds.size
        }
    }
}

private extension AVMutableComposition {
    /// Creates a `AVMutableComposition` from the given clips.
    ///
    /// - Parameter clips: The recorded clips during the session.
    /// - Returns: A new instance of `AVMutableComposition`.
    static func from(_ clips: [TruVideoClip]) -> AVMutableComposition {
        var audioTrack: AVMutableCompositionTrack?
        let mutableComposition = AVMutableComposition()
        var currentTime = mutableComposition.duration
        var videoTrack: AVMutableCompositionTrack?

        for clip in clips {
            guard let asset = clip.asset else { continue }

            let audioAssetTracks = asset.tracks(withMediaType: .audio)
            var maxRange = CMTime.invalid
            let videoAssetTracks = asset.tracks(withMediaType: .video)
            var videoTime = currentTime

            for videoAssetTrack in videoAssetTracks {
                videoTrack = mutableComposition.addMutableTrack(
                    withMediaType: .video,
                    preferredTransform: videoAssetTrack.preferredTransform,
                    trackID: videoAssetTrack.trackID
                )

                videoTime = videoTrack?.append(videoAssetTrack, startTime: videoTime, range: maxRange) ?? videoTime
                maxRange = videoTime
            }

            var audioTime = currentTime

            for audioAssetTrack in audioAssetTracks {
                if audioTrack == nil {
                    audioTrack = mutableComposition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: audioAssetTrack.trackID
                    )
                }

                audioTime = audioTrack?.append(audioAssetTrack, startTime: audioTime, range: maxRange) ?? audioTime
            }

            currentTime = mutableComposition.duration
        }

        return mutableComposition
    }

    /// Adds an empty track to a mutable composition.
    ///
    /// - Parameters:
    ///    - mediaType: The media type of the new track.
    ///    - preferredTransform: The preferred transformation of the visual media data for display purposes.
    /// - Returns: A new instance of the `AVMutableCompositionTrack`
    func addMutableTrack(
        withMediaType mediaType: AVMediaType,
        preferredTransform: CGAffineTransform = .identity,
        trackID: CMPersistentTrackID
    ) -> AVMutableCompositionTrack? {

        let tracks = tracks(withMediaType: mediaType)
        guard let track = tracks.first else {
            let track = addMutableTrack(withMediaType: mediaType, preferredTrackID: trackID)
            track?.preferredTransform = preferredTransform
            return track
        }

        return track
    }
}

private extension AVMutableCompositionTrack {
    /// Appends a new track to the composition
    ///
    /// - Parameters:
    ///    - track: The `AVAssetTrack` to append into the composition
    ///    - startTime: The initial time where the asset is going to be added
    ///    - range: Time Range
    /// - Returns: The total time of the asset
    func append(_ track: AVAssetTrack, startTime: CMTime, range: CMTime) -> CMTime {
        let timeRange = track.timeRange
        let startTime = startTime + timeRange.start

        if timeRange.duration > .zero {
            do {
                try insertTimeRange(timeRange, of: track, at: startTime)
            } catch {
                print("[TruVideoSession]: ⚠️ Could not add the track \(track)")
            }

            return startTime + timeRange.duration
        }

        return startTime
    }
}

private extension AVMutableVideoComposition {
    /// Creates a `AVMutableVideoComposition` from the given clips.
    ///
    /// - Parameter clips: The recorded clips during the session.
    /// - Returns: A new instance of `AVMutableVideoComposition`.
    static func from(_ clips: [TruVideoClip]) -> AVMutableVideoComposition {
        var currentTime = CMTime.zero
        var layerInstructions: [AVVideoCompositionLayerInstruction] = []
        let mainInstruction = AVMutableVideoCompositionInstruction()
        let mutableVideoComposition = AVMutableVideoComposition()
        let targetSize = CGSize(width: 640, height: 480)

        mutableVideoComposition.frameDuration = .init(value: 1, timescale: 30)
        mutableVideoComposition.renderSize = targetSize

        for (index, clip) in clips.enumerated() {
            guard let asset = clip.asset else { continue }

            let videoAssetTracks = asset.tracks(withMediaType: .video)

            for videoAssetTrack in videoAssetTracks {
                let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoAssetTrack)
                var transform = videoAssetTrack.preferredTransform

                if index == 0 {
                    instruction.setOpacity(0, at: CMTimeAdd(currentTime, asset.duration))
                }

                if asset.orientation == .landscapeRight {
                    transform = transform.translatedBy(x: 0, y: -targetSize.width)
                } else {
                    transform = transform.translatedBy(x: -targetSize.height, y: 0)
                }

                instruction.setTransform(transform, at: .zero)
                layerInstructions.append(instruction)
            }

            currentTime = CMTimeAdd(currentTime, asset.duration)
        }

        mainInstruction.timeRange = .init(start: .zero, duration: currentTime)
        mainInstruction.layerInstructions = layerInstructions        
        mutableVideoComposition.instructions = [mainInstruction]

        return mutableVideoComposition
    }
}

private extension CMSampleBuffer {

    /// Returns an offset `CMSampleBuffer` for the given time offset and duration.
    ///
    /// - Parameters:
    ///   - sampleBuffer: Input sample buffer to copy and offset.
    ///   - timeOffset: Time offset for the output sample buffer.
    ///   - duration: Optional duration for the output sample buffer.
    /// - Returns: Sample buffer with the desired time offset and duration, otherwise nil.
    func offset(by time: CMTime, duration: CMTime? = nil) -> CMSampleBuffer? {
        var itemCount: CMItemCount = 0
        var status = CMSampleBufferGetSampleTimingInfoArray(
            self,
            entryCount: 0,
            arrayToFill: nil,
            entriesNeededOut: &itemCount
        )

        guard status == 0 else { return nil }

        var timingInfo = [CMSampleTimingInfo](
            repeating: CMSampleTimingInfo(
                duration: CMTimeMake(value: 0, timescale: 0),
                presentationTimeStamp: CMTimeMake(value: 0, timescale: 0),
                decodeTimeStamp: CMTimeMake(value: 0, timescale: 0)
            ),
            count: itemCount
        )

        status = CMSampleBufferGetSampleTimingInfoArray(
            self,
            entryCount: itemCount,
            arrayToFill: &timingInfo,
            entriesNeededOut: &itemCount
        )

        guard status == 0 else { return nil }

        for index in 0 ..< itemCount {
            timingInfo[index].decodeTimeStamp = CMTimeSubtract(timingInfo[index].decodeTimeStamp, time)
            timingInfo[index].presentationTimeStamp = CMTimeSubtract(timingInfo[index].presentationTimeStamp, time)

            if let duration = duration {
                timingInfo[index].duration = duration
            }
        }

        var sampleBufferOffset: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: itemCount,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &sampleBufferOffset
        )

        return sampleBufferOffset
    }
}

private extension FileManager {
    /// Removes the file at the destination `url`
    ///
    /// - Parameter url: The url where the file is located
    func removeFile(at url: URL) {
        guard fileExists(atPath: url.path) else { return }

        do {
            try removeItem(atPath: url.path)
        } catch {
            print("[TruVideoSession]: ⚠️ Could not remove file at path \(url)")
        }
    }
}

private extension TruVideoRecorder {
    /// Returns the default metadata for an `AVAssetWriter`
    class var assetWriterMetadata: [AVMutableMetadataItem] {
        let modelItem = AVMutableMetadataItem()
        modelItem.keySpace = AVMetadataKeySpace.common
        modelItem.key = AVMetadataKey.commonKeyModel as (NSCopying & NSObjectProtocol)
        modelItem.value = UIDevice.current.localizedModel as (NSCopying & NSObjectProtocol)

        let softwareItem = AVMutableMetadataItem()
        softwareItem.keySpace = AVMetadataKeySpace.common
        softwareItem.key = AVMetadataKey.commonKeySoftware as (NSCopying & NSObjectProtocol)
        softwareItem.value = TruVideoMetadataTitle as (NSCopying & NSObjectProtocol)

        let artistItem = AVMutableMetadataItem()
        artistItem.keySpace = AVMetadataKeySpace.common
        artistItem.key = AVMetadataKey.commonKeyArtist as (NSCopying & NSObjectProtocol)
        artistItem.value = TruVideoMetadataArtist as (NSCopying & NSObjectProtocol)

        let creationDateItem = AVMutableMetadataItem()
        creationDateItem.keySpace = .common
        creationDateItem.key = AVMetadataKey.commonKeyCreationDate as NSString
        creationDateItem.value = Date() as NSDate

        return [modelItem, softwareItem, artistItem, creationDateItem]
    }
}

/// Represents all the errors that can be thrown
/// during a capture session
enum TruVideoSessionError: Error {
    /// canAddOutput threw an error in.
    /// when adding the audio input.
    case cannotAddAudioInput

    /// `canAddOutput` threw an error in
    /// when adding the video input.
    case cannotAddVideoInput

    /// `beginNewClip` threw an error in.
    case cannotBeginANewClip
}

/// Implements the complete file recording interface declared for writing media data to QuickTime/MP4 movie files.
class TruVideoSession {
    /// Instance of AVAssetWriter configured to write to a file in a specified container format.
    private var assetWriter: AVAssetWriter?

    /// Configuration to use when recording audio frames
    private var audioConfiguration: TruAudioConfiguration?

    /// Defines an interface for appending either new media samples for the audio recording
    private var audioInput: AVAssetWriterInput?

    /// Queue for the audio session operation
    private let audioQueue: DispatchQueue

    /// The identifier for the current background task.
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    /// The number of clips recorded
    private var clipFilenameCount = 0

    /// Timestamp of the last audio frame received
    private var lastAudioTimestamp: CMTime = .invalid

    /// Timestamp of the last video frame received
    private var lastVideoTimestamp: CMTime = .invalid

    /// The mutable video comsposition.
    private var videoComposition: AVMutableVideoComposition {
        AVMutableVideoComposition.from(clips)
    }

    /// The current interface for appending video samples packaged as CVPixelBuffer objects to a single AVAssetWriterInput object
    private var pixelBufferAdapter: AVAssetWriterInputPixelBufferAdaptor?

    /// Queue for a session operations
    private let queue: DispatchQueue

    /// Keeps track of the skipped the audio buffers
    private var skippedAudioBuffers: [CMSampleBuffer] = []

    /// Starting time stamp when a new clip is being recorded
    private var startTimestamp: CMTime = .invalid

    /// Time offset between the clip and the paused frames
    private var timeOffset: CMTime = .zero

    /// Configuration to use when recording video frames
    private var videoConfiguration: TruVideoConfiguration?

    /// Defines an interface for appending either new media samples for the video recording
    private var videoInput: AVAssetWriterInput?

    /// The list of the recorded clips
    private(set) var clips: [TruVideoClip] = []

    /// Whether the clip is being recorded with audio
    private(set) var currentClipHasAudio = false

    /// Whether the clip is being recorded with video
    private(set) var currentClipHasVideo = false

    /// Output file type for a session, see AVMediaFormat.h for supported types.
    var fileType: AVFileType = .mov

    /// Whether the session is recording a clip
    private(set) var hasStartedRecording = false

    /// Unique identifier for the session
    let identifier = UUID()

    /// `AVAsset` of the session.
    var asset: AVAsset? {
        if clips.count == 1 {
            return clips.first?.asset
        }

        return AVMutableComposition.from(clips)
    }

    /// Whether the session has configured the audio
    var hasConfiguredAudio: Bool {
        audioInput != nil
    }

    /// Whether the session has configured the video
    var hasConfiguredVideo: Bool {
        videoInput != nil
    }

    /// Checks if the session's asset writer is ready for data.
    var isReady: Bool {
        assetWriter != nil
    }

    /// Output directory for the session.
    var outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory())

    /// Video output transform for display
    var transform: CGAffineTransform? {
        get {
            videoInput?.transform
        }

        set {
            guard let newValue = newValue else {
                return
            }

            videoInput?.transform = newValue
        }
    }

    /// Duration of a session, the sum of all recorded clips.
    @Published
    private(set) var totalDuration: CMTime = .invalid

    private let TruVideoSessionAudioQueueIdentifier = "org.TruVideo.session.audioQueue"
    private let TruVideoSessionQueueIdentifier = "org.TruVideo.sessionQueue"
    private let TruVideoSessionQueueSpecificKey = DispatchSpecificKey<()>()

    // MARK: Initializers

    /// Creates a new instance of the `TruVideoSession`
    ///
    /// - Parameters:
    ///    - queue: The worker queue for the `AVAssetWriter`
    init(queue: DispatchQueue? = nil) {
        self.audioQueue = DispatchQueue(label: TruVideoSessionAudioQueueIdentifier)
        self.queue = queue ?? DispatchQueue(label: TruVideoSessionQueueIdentifier)
        self.queue.setSpecific(key: TruVideoSessionQueueSpecificKey, value: ())

        configureObservers()
    }

    // MARK: Instance methods

    /// Adds a specific clip to a session.
    ///
    /// - Parameter clip: Clip to be added
    func add(clip: TruVideoClip) {
        executeSync {
            self.clips.append(clip)
            self.totalDuration = CMTimeAdd(self.totalDuration, clip.duration)
        }
    }

    /// Adds a specific clip to a session at the desired index.
    ///
    /// - Parameters:
    ///   - clip: Clip to be added
    ///   - index: Index at which to add the clip
    func add(clip: TruVideoClip, at index: Int) {
        executeSync {
            self.clips.insert(clip, at: index)
            self.totalDuration = CMTimeAdd(self.totalDuration, clip.duration)
        }
    }

    /// Append audio sample buffer frames to a session for recording.
    ///
    /// - Parameters:
    ///   - sampleBuffer: Sample buffer input to be appended, unless an image buffer is also provided    
    /// - Returns: A boolean indicating whether the `sampleBuffer` was recorded
    @discardableResult
    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) -> Bool {
        startSessionIfNecessary(at: CMSampleBufferGetDuration(sampleBuffer))

        let buffers = skippedAudioBuffers + [sampleBuffer]
        var failedBuffers: [CMSampleBuffer] = []
        var hasFailed = false

        skippedAudioBuffers = []

        for buffer in buffers {
            let duration = CMSampleBufferGetDuration(sampleBuffer)

            if let adjustedBuffer = buffer.offset(by: timeOffset, duration: duration) {
                let presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(buffer)
                let lastTimestamp = CMTimeAdd(presentationTimestamp, duration)

                if let audioInput = audioInput,
                    audioInput.isReadyForMoreMediaData, audioInput.append(adjustedBuffer) {

                    lastVideoTimestamp = lastTimestamp
                    currentClipHasAudio = true

                    if !currentClipHasVideo {
                        totalDuration = CMTimeSubtract(lastTimestamp, startTimestamp)
                    }
                } else {
                    hasFailed = true
                    failedBuffers.append(buffer)
                }
            }
        }

        skippedAudioBuffers = failedBuffers
        return !hasFailed
    }

    /// Append video sample buffer frames to a session for recording.
    ///
    /// - Parameters:
    ///   - sampleBuffer: Sample buffer input to be appended, unless an image buffer is also provided
    ///   - minFrameDuration: Current active minimum frame duration
    /// - Returns: A boolean indicating whether the `sampleBuffer` was recorded
    @discardableResult
    func appendVideoBuffer(_ sampleBuffer: CMSampleBuffer, minFrameDuration: CMTime) -> Bool {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        startSessionIfNecessary(at: timestamp)

        guard assetWriter?.status == .writing else {
            return false
        }

        var frameDuration = minFrameDuration
        let offsetBufferTimestamp = CMTimeSubtract(timestamp, timeOffset)

        if let timeScale = videoConfiguration?.timescale, timeScale != 0 {
            let scaleDuration = CMTimeMultiplyByFloat64(minFrameDuration, multiplier: timeScale)
            if totalDuration.value > 0 {
                timeOffset = CMTimeAdd(timeOffset, CMTimeSubtract(minFrameDuration, scaleDuration))
            }
            frameDuration = scaleDuration
        }

        if
            // Video input
            let videoInput = videoInput,

            // Buffer adapter
            let pixelBufferAdapter = pixelBufferAdapter, videoInput.isReadyForMoreMediaData {

            /// Current buffer to process
            if let bufferToProcess = CMSampleBufferGetImageBuffer(sampleBuffer),
               offsetBufferTimestamp.isValid,
               pixelBufferAdapter.append(bufferToProcess, withPresentationTime: offsetBufferTimestamp) {

                currentClipHasVideo = true
                lastVideoTimestamp = timestamp
                totalDuration = CMTimeSubtract(CMTimeAdd(offsetBufferTimestamp, frameDuration), startTimestamp)

                return true
            }
        }

        return false
    }

    /// Starts a new clip
    ///
    /// - Throws: An error if the clip cannot be created.
    func beginNewClip() throws {
        guard self.assetWriter == nil else {
            print("[TruVideoSession]: ⚠️ Clip has already been created.")
            return
        }

        do {
            assetWriter = try AVAssetWriter(url: generateNextOuputURL(), fileType: fileType)

            if let assetWriter = assetWriter {
                assetWriter.metadata = TruVideoRecorder.assetWriterMetadata
                assetWriter.shouldOptimizeForNetworkUse = true

                if let audioInput = audioInput {
                    if assetWriter.canAdd(audioInput) {
                        assetWriter.add(audioInput)
                    } else {
                        print("[TruVideoSession]: 🛑 writer encountered an adding the audio input")
                        throw TruVideoSessionError.cannotAddAudioInput
                    }
                }

                if let videoInput = videoInput {
                    if assetWriter.canAdd(videoInput) {
                        assetWriter.add(videoInput)
                    } else {
                        print("[TruVideoSession]: 🛑 writer encountered an adding the video input")
                        throw TruVideoSessionError.cannotAddVideoInput
                    }
                }

                if assetWriter.startWriting() {
                    hasStartedRecording = true
                    startTimestamp = .invalid
                    timeOffset = .zero
                } else {
                    print("[TruVideoSession]: 🛑 writer encountered an error \(String(describing: assetWriter.error))")
                    self.assetWriter = nil
                    throw TruVideoSessionError.cannotBeginANewClip
                }
            }
        } catch {
            throw TruVideoSessionError.cannotBeginANewClip
        }
    }
    
    /// Prepares a session for recording audio.
    ///
    /// - Parameters:
    ///   - settings: AVFoundation audio settings dictionary
    ///   - configuration: Audio configuration for audio output
    ///   - formatDescription: sample buffer format description
    /// - Returns: True when setup completes successfully
    @discardableResult
    func configureAudio(
        with settings: [String: Any]?,
        configuration: TruAudioConfiguration,
        formatDescription: CMFormatDescription
    ) -> Bool {

        audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: settings,
            sourceFormatHint: formatDescription
        )

        if let audioInput = audioInput {
            audioInput.expectsMediaDataInRealTime = true
            audioConfiguration = configuration
        }

        return hasConfiguredAudio
    }

    /// Prepares a session for recording video.
    ///
    /// - Parameters:
    ///   - settings: AVFoundation video settings dictionary
    ///   - configuration: Video configuration for video output
    ///   - formatDescription: sample buffer format description
    /// - Returns: True when setup completes successfully
    @discardableResult
    func configureVideo(
        with settings: [String: Any]?,
        configuration: TruVideoConfiguration,
        formatDescription: CMFormatDescription? = nil
    ) -> Bool {

        if let formatDescription = formatDescription {
            videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: settings,
                sourceFormatHint: formatDescription
            )
        } else if let settings = settings, settings.hasValidVideoSettings == true {
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        } else {
            print("[TruVideoSession]: 🛑 failed to configure video output")
            videoInput = nil
            return false
        }

        if let videoInput = videoInput {
            videoInput.expectsMediaDataInRealTime = true
            videoInput.transform = configuration.transform
            videoConfiguration = configuration

            var pixelBufferAttibutes: [String: Any] = [
                String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]

            if let formatDescription = formatDescription {
                let videoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                pixelBufferAttibutes[String(kCVPixelBufferHeightKey)] = videoDimensions.height
                pixelBufferAttibutes[String(kCVPixelBufferWidthKey)] = videoDimensions.width
            } else if
                /// Video height
                let height = settings?[String(kCVPixelBufferHeightKey)],

                /// Video width
                let width = settings?[String(kCVPixelBufferWidthKey)] {

                pixelBufferAttibutes[String(kCVPixelBufferHeightKey)] = height
                pixelBufferAttibutes[String(kCVPixelBufferWidthKey)] = width
            }

            pixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: pixelBufferAttibutes
            )
        }

        return hasConfiguredVideo
    }

    /// Starts a new clip
    ///
    /// - Throws: An error if the clip cannot be created.
    @discardableResult
    func finishClip() async throws -> TruVideoClip? {
        hasStartedRecording = false

        return try await withUnsafeThrowingContinuation { continuation in
            if let assetWriter = self.assetWriter {
                if !self.currentClipHasAudio && !self.currentClipHasVideo {
                    assetWriter.cancelWriting()

                    FileManager.default.removeFile(at: assetWriter.outputURL)
                    self.destroyAssetWriter()
                    continuation.resume(returning: nil)
                } else {                    
                    assetWriter.finishWriting {
                        defer {
                            self.destroyAssetWriter()
                            self.destroyAssetWriter()
                            self.endBackgroundTaskIfNeeded()
                        }

                        guard let error = assetWriter.error else {
                            let clip = TruVideoClip(url: assetWriter.outputURL)
                            self.clips.append(clip)
                            continuation.resume(returning: clip)

                            return
                        }

                        continuation.resume(throwing: error)
                    }
                }
            } else {
                endBackgroundTaskIfNeeded()
                continuation.resume(returning: nil)
            }
        }
    }

    /// Merges all existing recorded clips in the session and exports to a file.
    ///
    /// - Parameter preset: AVAssetExportSession preset name for export.
    /// - Returns: The url of the exported file.
    func mergeClips(usingPreset preset: String) async throws -> URL {
        try await withUnsafeThrowingContinuation { continuation in
            self.executeSync {
                let outputURL = self.generateNextOuputURL()

                if !self.clips.isEmpty {
                    if self.clips.count == 1 {
                        print("[TruVideoSession]: ⚠️ a merge was requested for a single clip, use lastClipUrl instead")
                    }

                    if let exportAsset = self.asset {
                        FileManager.default.removeFile(at: outputURL)

                        if let exportSession = AVAssetExportSession(asset: exportAsset, presetName: preset) {
                            exportSession.shouldOptimizeForNetworkUse = true
                            exportSession.outputURL = outputURL
                            exportSession.outputFileType = self.fileType
                            exportSession.videoComposition = AVMutableVideoComposition.from(self.clips)
                            exportSession.exportAsynchronously {
                                defer {
                                    self.endBackgroundTaskIfNeeded()
                                }

                                guard let error = exportSession.error else {
                                    continuation.resume(with: .success(outputURL))
                                    return
                                }
                                
                                continuation.resume(with: .failure(error))
                            }
                            return
                        }
                    } else {
                        self.endBackgroundTaskIfNeeded()
                    }
                }
            }
        }
    }

    /// Finalizes the recording of a clip.
    func reset() {
        executeSync {
            self.audioConfiguration = nil
            self.audioInput = nil
            self.pixelBufferAdapter = nil
            self.skippedAudioBuffers = []
            self.videoInput = nil
            self.videoConfiguration = nil
        }
    }

    // MARK: Notification methods

    @objc
    private func didReceiveDidEnterBackgroundNotification(_ notification: Notification) {
        endBackgroundTaskIfNeeded()
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask()
    }

    @objc
    private func didReceiveWillEnterForegroundNotification(_ notification: Notification) {
        endBackgroundTaskIfNeeded()
    }

    // MARK: Private methods

    private func configureObservers() {
        UIApplication.shared.beginBackgroundTask()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveDidEnterBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveWillEnterForegroundNotification),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    private func destroyAssetWriter() {
        assetWriter = nil
        currentClipHasAudio = false
        currentClipHasVideo = false
        hasStartedRecording = false
        startTimestamp = .invalid
        timeOffset = .zero
        totalDuration = .zero
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskIdentifier != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }

    private func executeSync(_ closure: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: TruVideoSessionQueueSpecificKey) != nil {
            closure()
        } else {
            queue.sync(execute: closure)
        }
    }

    private func generateNextOuputURL() -> URL {
        let filename = "\(identifier.uuidString)-TV-clip.\(clipFilenameCount).mov"//\(fileType.rawValue)"
        let nextOutputURL = outputDirectory.appendingPathComponent(filename)

        clipFilenameCount += 1
        FileManager.default.removeFile(at: nextOutputURL)
        return nextOutputURL
    }

    private func startSessionIfNecessary(at timestamp: CMTime) {
        guard !startTimestamp.isValid && timestamp.isValid else { return }

        startTimestamp = timestamp
        assetWriter?.startSession(atSourceTime: timestamp)
    }
}
