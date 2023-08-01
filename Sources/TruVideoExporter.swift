//
//  TruVideoExporter.swift
//  TruVideoCamera
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import Foundation

private extension AVAssetWriterInput {
    
    /// Instructs the receiver to invoke a client-supplied block repeatedly, at its convenience, in order to gather media data for writing to the output file.
    ///
    /// - Parameter queue: The queue on which the block should be invoked.
    func requestMediaDataWhenReady(on queue: DispatchQueue) async {
        await withUnsafeContinuation { continuation in
            requestMediaDataWhenReady(on: queue) {
                continuation.resume()
            }
        }
    }
}

/// 🔄 TruVideoExporter, export and transcode media in Swift
open class TruVideoExporter: NSObject {
    /// Progress handler type
    public typealias ProgressHandler = (_ progress: Float) -> Void
    
    private var assetWriter: AVAssetWriter?
    private var assetReader: AVAssetReader?
    private var audioMixOutput: AVAssetReaderAudioMixOutput?
    private var audioWriterInput: AVAssetWriterInput?
    private var duration: TimeInterval = 0
    private var inputQueue: DispatchQueue
    private var lastSamplePresentationTime: CMTime = .invalid
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var progressHandler: ProgressHandler?
    private let queueLabel = "TruVideoExporterQueue"
    private var videoCompositionOutput: AVAssetReaderVideoCompositionOutput?
    private var videoWriterInput: AVAssetWriterInput?

    /// The asset to be exported.
    public let asset: AVAsset
    
    /// Enables audio mixing and parameters for the session.
    public var audioMix: AVAudioMix?
    
    /// Audio output configuration dictionary, using keys defined in `<AVFoundation/AVAudioSettings.h>`
    public var audioOutputConfiguration: [String : Any]?
    
    /// Indicates if an export session should expect media data in real time.
    public var expectsMediaDataInRealTime = false
    
    /// Metadata to be added to an export.
    public var metadata: [AVMetadataItem]?
    
    /// Indicates if an export should be optimized for network use.
    public var optimizeForNetworkUse = false
    
    /// Output file type. UTI string defined in `AVMediaFormat.h`.
    public var outputFileType = AVFileType.mp4
    
    /// Output file location for the session.
    public var outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
    
    /// Session exporting progress from 0 to 1.
    public private(set) var progress: Float = 0 {
        didSet {
            progressHandler?(progress)
        }
    }
    
    /// Time range or limit of an export from `kCMTimeZero` to `kCMTimePositiveInfinity`
    public var timeRange: CMTimeRange

    /// Enables video composition and parameters for the session.
    public var videoComposition: AVVideoComposition?
    
    /// Video input configuration dictionary, using keys defined in `<CoreVideo/CVPixelBuffer.h>`
    public var videoInputConfiguration: [String : Any]?
    
    /// Video output configuration dictionary, using keys defined in `<AVFoundation/AVVideoSettings.h>`
    public var videoOutputConfiguration: [String : Any]?
    
    /// Export session status state.
    public var status: AVAssetExportSession.Status {
        get {
            if let assetWriter = assetWriter {
                switch assetWriter.status {
                case.cancelled:
                    return .cancelled
                    
                case .completed:
                    return .completed
                    
                case .failed:
                    return .failed
                    
                case .writing:
                    return .exporting
                
                case .unknown:
                    fallthrough
                    
                @unknown default:
                    break
                }
            }

            return .unknown
        }
    }
    
    /// All errors that can be thrown by the exporter
    public enum TruVideoExporterError: Error {
        /// Explicitly cancelled.
        case cancelled
        
        /// Encoding buffer failed.
        case encodingFailed
        
        /// Exporter setup.
        case setupFailure
        
        /// Buffer reading failed.
        case readingFailure
        
        /// Failed to write the buffer.
        case writingFailure
    }

    // MARK: - Initializers
    
    /// Creates a new `TruVideoExporter` with an asset to export.
    ///
    /// - Parameter asset: The asset to export.
    public init(asset: AVAsset) {
        self.asset = asset
        self.inputQueue = DispatchQueue(
            label: queueLabel, autoreleaseFrequency: .workItem,
            target: DispatchQueue.global()
        )
        self.timeRange = CMTimeRange(start: CMTime.zero, end: CMTime.positiveInfinity)
        
        super.init()
    }
    
    // MARK: Open methods
    
    /// Validates the curret video configuration.
    ///
    /// - Returns: A boolean indicating if the current video configuration is valid.
    open func hasValidVideoOutputConfiguration() -> Bool {
        guard let videoOutputConfiguration = videoOutputConfiguration else {
            return false
        }

        let videoHeight = videoOutputConfiguration[AVVideoHeightKey] as? NSNumber
        let videoWidth = videoOutputConfiguration[AVVideoWidthKey] as? NSNumber
                
        return !(videoHeight == nil && videoWidth == nil)
    }
    
    // MARK: Private methods
    
    private func complete() throws {
        if assetReader?.status == .cancelled || assetWriter?.status == .cancelled {
            if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            
            throw TruVideoError(kind: .exporter, underlyingError: TruVideoExporterError.cancelled)
        }
        
        guard
            /// Asset reader
            let assetReader = assetReader,
        
            /// Asset writer
            let assetWriter = assetWriter else {
                
            throw TruVideoError(kind: .exporter, underlyingError: TruVideoExporterError.setupFailure)
        }
        
        switch assetReader.status {
        case .failed:
            if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            
            throw TruVideoError(kind: .exporter, underlyingError: TruVideoExporterError.readingFailure)
        default:
            break
        }
        
        switch assetWriter.status {
        case .failed:
            if FileManager.default.fileExists(atPath: outputURL.absoluteString) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            
            throw TruVideoError(kind: .exporter, underlyingError: TruVideoExporterError.writingFailure)
        default:
            break
        }
    }
    
    private func createVideoComposition() -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return videoComposition
        }
        
        var frameRate = videoTrack.nominalFrameRate
        
        if let videoConfiguration = videoOutputConfiguration {
            if
                /// Compression configuration.
                let compressionConfiguration = videoConfiguration[AVVideoCompressionPropertiesKey] as? [String: Any],
            
                /// Track frame data.
                let trackFrameRate = compressionConfiguration[AVVideoAverageNonDroppableFrameRateKey] as? NSNumber {
                
                frameRate = trackFrameRate.floatValue
            }
        }
        
        if frameRate == 0 {
            frameRate = 30
        }
        
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
        
        if let videoConfiguration = videoOutputConfiguration {
            let height = (videoConfiguration[AVVideoHeightKey] as? NSNumber)?.intValue ?? 0
            let width = (videoConfiguration[AVVideoWidthKey] as? NSNumber)?.intValue ?? 0
            
            let targetSize = CGSize(width: width, height: height)
            var naturalSize = videoTrack.naturalSize
            var transform = videoTrack.preferredTransform
            
            let rect = CGRect(x: 0, y: 0, width: naturalSize.width, height: naturalSize.height)
            let transformedRect = rect.applying(transform)
            
            transform.tx -= transformedRect.origin.x;
            transform.ty -= transformedRect.origin.y;
            
            let videoAngleInDegrees = atan2(transform.b, transform.a) * 180 / .pi
            
            if videoAngleInDegrees == 90 || videoAngleInDegrees == -90 {
                let tempWidth = naturalSize.width
                naturalSize.width = naturalSize.height
                naturalSize.height = tempWidth
            }
            
            videoComposition.renderSize = naturalSize
            
            var ratio: CGFloat = 0
            let xRatio: CGFloat = targetSize.width / naturalSize.width
            let yRatio: CGFloat = targetSize.height / naturalSize.height
            
            ratio = min(xRatio, yRatio)
            
            let postWidth = naturalSize.width * ratio
            let postHeight = naturalSize.height * ratio
            let transX = (targetSize.width - postWidth) * 0.5
            let transY = (targetSize.height - postHeight) * 0.5
            
            var matrix = CGAffineTransform(translationX: (transX / xRatio), y: (transY / yRatio))
            matrix = matrix.scaledBy(x: (ratio / xRatio), y: (ratio / yRatio))
            transform = transform.concatenating(matrix)
            
            let compositionInstruction = AVMutableVideoCompositionInstruction()
            compositionInstruction.timeRange = CMTimeRange(start: CMTime.zero, duration: asset.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layerInstruction.setTransform(transform, at: .zero)
            
            compositionInstruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [compositionInstruction]
        }
        
        return videoComposition
    }
    
    private func encode(
        readySamplesFromReaderOutput readerOutput: AVAssetReaderOutput,
        toWriterInput input: AVAssetWriterInput
    ) throws {
        
        while input.isReadyForMoreMediaData {
            guard
                /// Next sample buffer.
                let sampleBuffer = readerOutput.copyNextSampleBuffer(),
                    assetReader?.status == .reading && assetWriter?.status == .writing else {
                
                input.markAsFinished()
                return
            }
            
            var handled = false
            
            if videoCompositionOutput == readerOutput {
                lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - timeRange.start
                progress = duration == 0 ? 1 : Float(CMTimeGetSeconds(lastSamplePresentationTime) / duration)
                
                if
                    /// Pixel adaptor
                    let pixelBufferAdaptor = pixelBufferAdaptor,
                    
                    /// Pixel pool
                    let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                    
                    var toRenderBuffer: CVPixelBuffer? = nil
                    let result = CVPixelBufferPoolCreatePixelBuffer(
                        kCFAllocatorDefault,
                        pixelBufferPool,
                        &toRenderBuffer
                    )
                    
                    if let toBuffer = toRenderBuffer, result == kCVReturnSuccess {
                        if !pixelBufferAdaptor.append(toBuffer, withPresentationTime: lastSamplePresentationTime) {
                            throw TruVideoExporterError.encodingFailed
                        }
                        
                        handled = true
                    }
                }
            }
            
            if !handled && !input.append(sampleBuffer) {
                throw TruVideoExporterError.encodingFailed
            }
        }
    }
    
    @MainActor
    private func finish() async throws {
        guard assetReader?.status != .cancelled && assetWriter?.status != .cancelled else {
            try complete()
            return
        }
        
        if assetWriter?.status == .failed {
           assetReader?.cancelReading()
       } else if assetReader?.status == .failed {
           assetWriter?.cancelWriting()
       } else {
           await assetWriter?.finishWriting()
       }
        
        try complete()
    }
    
    private func reset() {
        assetReader = nil
        assetWriter = nil
        pixelBufferAdaptor = nil
        progress = 0
        
        audioMix = nil
        audioMixOutput = nil
        videoCompositionOutput = nil
        videoComposition = nil
    }
    
    private func setupAudioInput() {
        guard audioMixOutput != nil else {
            return
        }
        
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputConfiguration)
        audioWriterInput?.expectsMediaDataInRealTime = expectsMediaDataInRealTime
        
        guard
            /// Asset writer
            let assetWriter = assetWriter,
            
            /// Audio writer input.
            let audioWriterInput = audioWriterInput, assetWriter.canAdd(audioWriterInput) else {
            
            return
        }
        
        assetWriter.add(audioWriterInput)
    }
    
    private func setupAudioOutput(for asset: AVAsset) {
        let audioTracks = asset.tracks(withMediaType: .audio)
        
        guard audioTracks.count > 0 else {
            audioMixOutput = nil
            return
        }

        audioMixOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: nil)
        audioMixOutput?.alwaysCopiesSampleData = false
        audioMixOutput?.audioMix = audioMix
        
        guard
            /// Asset reader
            let assetReader = assetReader,
            
            /// Audio mix output.
            let audioMixOutput = audioMixOutput, assetReader.canAdd(audioMixOutput) else {
            
            return
        }
        
        assetReader.add(audioMixOutput)
    }
    
    private func setupVideoOutput(for asset: AVAsset) {
        let videoTracks = asset.tracks(withMediaType: AVMediaType.video)
        
        guard videoTracks.count > 0 else {
            return
        }
        
        videoCompositionOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: videoTracks,
            videoSettings: videoInputConfiguration
        )
        
        videoCompositionOutput?.alwaysCopiesSampleData = false
        videoCompositionOutput?.videoComposition = videoComposition ?? createVideoComposition()
        
        if
            /// The video composition.
            let videoCompositionOutput = videoCompositionOutput,
            
            /// Asset reader.
            let assetReader = assetReader, assetReader.canAdd(videoCompositionOutput) {
            
            assetReader.add(videoCompositionOutput)
        }
        
        guard assetWriter?.canApply(outputSettings: videoOutputConfiguration, forMediaType: .video) == true else {
            print("Unsupported output configuration")
            return
        }
        
        if
            /// Asset writer.
            let assetWriter = assetWriter,
            
            /// Video writer.
            let videoWriterInput = videoWriterInput, assetWriter.canAdd(videoWriterInput) {
            
            assetWriter.add(videoWriterInput)
            
            var bufferAttributes: [String: Any] = [:]
            bufferAttributes[kCVPixelBufferPixelFormatTypeKey as String] = NSNumber(
                integerLiteral: Int(kCVPixelFormatType_32RGBA)
            )
            
            if let videoComposition = videoCompositionOutput?.videoComposition {
                bufferAttributes[kCVPixelBufferHeightKey as String] = NSNumber(
                    integerLiteral: Int(videoComposition.renderSize.height)
                )
                
                bufferAttributes[kCVPixelBufferWidthKey as String] = NSNumber(
                    integerLiteral: Int(videoComposition.renderSize.width)
                )
            }
            bufferAttributes["IOSurfaceOpenGLESTextureCompatibility"] = NSNumber(booleanLiteral:  true)
            bufferAttributes["IOSurfaceOpenGLESFBOCompatibility"] = NSNumber(booleanLiteral:  true)
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: bufferAttributes
            )
        }
    }
    
    // MARK: Public methods
    
    /// Cancels any export in progress.
    public func cancelExport() {
        if self.assetWriter?.status == .writing {
            self.assetWriter?.cancelWriting()
        }
        
        if self.assetReader?.status == .reading {
            self.assetReader?.cancelReading()
        }
        
        try? complete()
        reset()
    }
    
    /// Initiates the export process.
    ///
    /// - Parameters:
    ///    - url: The destination url of the new exported asset.
    ///    - progressHandler: Handler called notifying the progress of the export process.
    /// - Throws: Failure indication thrown when an error has occurred during export.
    public func export(to url: URL, progressHandler: ProgressHandler? = nil) async throws {
        if assetWriter?.status == .writing {
            assetWriter?.cancelWriting()
            assetWriter = nil
        }
        
        if assetReader?.status == .reading {
            assetReader?.cancelReading()
            assetReader = nil
        }
        
        progress = 0
        
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            print("[TruVideoExporter]: ⚠️ could not setup a reader for the provided asset \(asset)")
            throw TruVideoError(kind: .exporter, underlyingError: error)
        }
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: outputFileType)
        } catch {
            print("[TruVideoExporter]: ⚠️ could not setup a reader for the provided asset \(asset)")
            throw TruVideoError(kind: .exporter, underlyingError: error)
        }

        if videoOutputConfiguration == nil || !hasValidVideoOutputConfiguration() {
            print("[TruVideoExporter]: ⚠️ could not setup with the specified video output configuration")
            throw TruVideoError(kind: .exporter, underlyingError: TruVideoExporterError.setupFailure)
        }
        
        self.progressHandler = progressHandler
        
        assetReader?.timeRange = timeRange
        assetWriter?.shouldOptimizeForNetworkUse = optimizeForNetworkUse
        
        if let metadata = metadata {
            assetWriter?.metadata = metadata
        }
        
        if timeRange.duration.isValid && !timeRange.duration.isPositiveInfinity {
            duration = CMTimeGetSeconds(timeRange.duration)
        } else {
            duration = CMTimeGetSeconds(asset.duration)
        }
        
        if self.videoOutputConfiguration?.keys.contains(AVVideoCodecKey) == false {
            print("NextLevelSessionExporter, warning a video output configuration codec wasn't specified")
            videoOutputConfiguration?[AVVideoCodecKey] = AVVideoCodecType.h264
        }
        
        setupVideoOutput(for: asset)
        setupAudioOutput(for: asset)
        setupAudioInput()
        
        assetWriter?.startWriting()
        assetReader?.startReading()
        assetWriter?.startSession(atSourceTime: timeRange.start)
    
        let videoTracks = asset.tracks(withMediaType: .video)
        
        if
            /// Writer input
            let videoWriterInput = videoWriterInput,
            
            /// Video composition
            let videoCompositionOutput = videoCompositionOutput, videoTracks.count > 0 {
            
            await videoWriterInput.requestMediaDataWhenReady(on: inputQueue)
            try encode(readySamplesFromReaderOutput: videoCompositionOutput, toWriterInput: videoWriterInput)
        }
        
        if
            /// Audio  writer
            let audioWriterInput = audioWriterInput,
            
            /// Audio output
            let audioMixOutput = audioMixOutput {
            
            await audioWriterInput.requestMediaDataWhenReady(on: inputQueue)
            try encode(readySamplesFromReaderOutput: audioMixOutput, toWriterInput: audioWriterInput)
        }
        
        try await finish()
    }
}
