//
//  TruVideoConfiguration.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation

private extension CGSize {
    /// Returns the aspect ratio of the current size
    var aspectRatio: CGFloat {
        height / width
    }
}

/// TruConfiguration, media capture configuration object
public class TruConfiguration {
    /// AVFoundation configuration preset, see AVCaptureSession.h
    public var preset: AVCaptureSession.Preset = .high

    /// Aspect ratio, specifies dimensions for video output
    public enum AspectRatio {
        /// active preset or specified dimensions (default)
        case active

        /// 2.35:1 cinematic
        case cinematic

        /// custom aspect ratio
        case custom(size: CGSize)

        /// 1:1 square
        case square

        /// 3:4
        case standard

        /// 4:3, landscape
        case standardLandscape

        /// 9:16 HD
        case widescreen

        /// 16:9 HD landscape
        case widescreenLandscape

        /// Returns the dimension of the current aspect ratio
        var dimensions: CGSize? {
            switch self {
            case .active: return nil
            case .cinematic: return CGSize(width: 2.35, height: 1)
            case .custom(let size): return size
            case .square: return CGSize(width: 1, height: 1)
            case .standard: return CGSize(width: 3, height: 4)
            case .standardLandscape: return CGSize(width: 4, height: 3)
            case .widescreen: return CGSize(width: 9, height: 16)
            case .widescreenLandscape: return CGSize(width: 16, height: 9)
            }
        }

        /// The ratio
        var ratio: CGFloat? {
            switch self {
            case .active: return nil
            case .custom(let size): return size.width / size.height
            case .square: return 1
            default: return dimensions?.aspectRatio
            }
        }
    }

    // MARK: Instance methods

    /// Provides an AVFoundation friendly dictionary for configuring output.
    ///
    /// - Parameter sampleBuffer: Sample buffer for extracting configuration information
    /// - Returns: Configuration dictionary for AVFoundation
    func avcaptureSettingsDictionary(
        sampleBuffer: CMSampleBuffer? = nil,
        pixelBuffer: CVPixelBuffer? = nil
    ) -> [String: Any]? {

        [:]
    }
}

/// TruAudioConfiguration,  audio capture configuration object
public class TruAudioConfiguration: TruConfiguration {
    /// Audio bit rate, AV dictionary key AVEncoderBitRateKey
    var bitRate = TruAudioConfiguration.AudioBitRateDefault

    /// Number of channels, AV dictionary key AVNumberOfChannelsKey
    var channelsCount: Int?

    /// Sample rate in hertz, AV dictionary key AVSampleRateKey
    var sampleRate: Float64?

    /// Audio data format identifier, AV dictionary key AVFormatIDKey
    /// https://developer.apple.com/reference/coreaudio/1613060-core_audio_data_types
    var format: AudioFormatID = kAudioFormatMPEG4AAC

    /// Default bit rate
    static let AudioBitRateDefault: Int = 96000

    /// Defailt sample rate
    static let AudioSampleRateDefault: Float64 = 44100

    /// Default audio channels
    static let AudioChannelsCountDefault: Int = 2

    // MARK: Overriden methods

    /// Provides an AVFoundation friendly dictionary for configuring output.
    ///
    /// - Parameter sampleBuffer: Sample buffer for extracting configuration information
    /// - Returns: Configuration dictionary for AVFoundation
    override func avcaptureSettingsDictionary(
        sampleBuffer: CMSampleBuffer? = nil,
        pixelBuffer: CVPixelBuffer? = nil
    ) -> [String: Any]? {

        var config: [String: Any] = [AVEncoderBitRateKey: NSNumber(integerLiteral: self.bitRate)]

        if
            /// Sample buffer
            let sampleBuffer = sampleBuffer,

            /// Sample format description
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {

            /// Stream basic description
            if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
               sampleRate == nil && channelsCount == nil {

                sampleRate = streamBasicDescription.pointee.mSampleRate
                channelsCount = Int(streamBasicDescription.pointee.mChannelsPerFrame)
            }

            var layoutSize: Int = 0
            if let currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, sizeOut: &layoutSize) {
                config[AVChannelLayoutKey] = layoutSize > 0 ?
                    Data(bytes: currentChannelLayout, count: layoutSize) :
                    Data()
            }
        }

        if let sampleRate = sampleRate, sampleRate > 0 {
            config[AVSampleRateKey] = sampleRate
        } else {
            config[AVSampleRateKey] = TruAudioConfiguration.AudioSampleRateDefault
        }

        if let channelsCount = channelsCount, channelsCount > 0 {
            config[AVNumberOfChannelsKey] = channelsCount
        } else {
            config[AVNumberOfChannelsKey] = TruAudioConfiguration.AudioChannelsCountDefault
        }

        config[AVFormatIDKey] = format
        return config
    }
}

/// TruPhotoConfiguration,  photo capture configuration object
public class TruPhotoConfiguration: TruConfiguration {
    /// Codec used to encode photo, AV dictionary key AVVideoCodecKey
    public var codec: AVVideoCodecType = .hevc

    /// When true, It should generate a thumbnail for the photo
    public var generateThumbnail = false

    /// Enabled high resolution capture
    public var isHighResolutionEnabled = false

    /// Change flashMode with TruVideoRecorder.flashMode
    public var flashMode: AVCaptureDevice.FlashMode = .off

    // MARK: Overriden methods

    /// Provides an AVFoundation friendly dictionary for configuring output.
    ///
    /// - Returns: Configuration dictionary for AVFoundation
    func avDictionary() -> [String: Any]? {
        var config: [String: Any] = [AVVideoCodecKey: codec]

        if generateThumbnail {
            let settings = AVCapturePhotoSettings()
            if settings.__availablePreviewPhotoPixelFormatTypes.count > 0 {
                if let formatType = settings.__availablePreviewPhotoPixelFormatTypes.first {
                    config[kCVPixelBufferPixelFormatTypeKey as String] = formatType
                }
            }
        }

        return config
    }
}

/// TruVideoConfiguration,  video capture configuration object
public class TruVideoConfiguration: TruConfiguration {
    /// Output aspect ratio automatically sizes output dimensions, `active` indicates TruVideoConfiguration.preset or TruVideoConfiguration.dimensions
    public var aspectRatio: AspectRatio = .active

    /// Average video bit rate (bits per second), AV dictionary key AVVideoAverageBitRateKey
    public var bitRate = TruVideoConfiguration.VideoBitRateDefault

    /// Codec used to encode video, AV dictionary key AVVideoCodecKey
    public var codec: AVVideoCodecType = AVVideoCodecType.h264

    /// Dimensions for video output, AV dictionary keys AVVideoWidthKey, AVVideoHeightKey
    public var dimensions: CGSize?

    /// Maximum recording duration, when set, session finishes automatically
    public var maximumCaptureDuration: CMTime?

    /// Maximum interval between key frames, 1 meaning key frames only, AV dictionary key AVVideoMaxKeyFrameIntervalKey
    public var maxKeyFrameInterval: Int?

    /// Profile level for the configuration, AV dictionary key AVVideoProfileLevelKey (H.264 codec only)
    public var profileLevel: String?

    /// Video scaling mode, AV dictionary key AVVideoScalingModeKey
    /// (AVVideoScalingModeResizeAspectFill, AVVideoScalingModeResizeAspect, AVVideoScalingModeResize, AVVideoScalingModeFit)
    public var scalingMode: String = AVVideoScalingModeResizeAspectFill

    /// Video output transform for display
    public var transform: CGAffineTransform = .identity

    /// Video time scale, value/timescale = seconds
    public var timescale: Float64?

    /// Default video bit rate
    static let VideoBitRateDefault: Int = 2000000

    // MARK: Overriden methods

    /// Provides an AVFoundation friendly dictionary for configuring output.
    ///
    /// - Parameter sampleBuffer: Sample buffer for extracting configuration information
    /// - Returns: Configuration dictionary for AVFoundation
    override func avcaptureSettingsDictionary(
        sampleBuffer: CMSampleBuffer? = nil,
        pixelBuffer: CVPixelBuffer? = nil
    ) -> [String: Any]? {

        var config: [String: Any] = [:]
        let sizeValuesDivisionValue = 16

        if let dimensions = dimensions {
            config[AVVideoHeightKey] = dimensions.height
            config[AVVideoWidthKey] = dimensions.width
        } else if
            /// The sample buffer
            let sampleBuffer = sampleBuffer,

            /// The format description for the `sampleBuffer`
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {

            let videoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            switch aspectRatio {
            case .custom(let size):
                config[AVVideoHeightKey] = videoDimensions.width * Int32(size.height) / Int32(size.width)
                config[AVVideoWidthKey] = Int(videoDimensions.width)

            case .square:
                let min = min(videoDimensions.width, videoDimensions.height)
                config[AVVideoHeightKey] = Int(min)
                config[AVVideoWidthKey] = Int(min)
                break

            case .standard:
                config[AVVideoHeightKey] = Int(videoDimensions.width * 3 / 4)
                config[AVVideoWidthKey] = Int(videoDimensions.width)
                break

            case .widescreen:
                config[AVVideoHeightKey] = Int(videoDimensions.width * 9 / 16)
                config[AVVideoWidthKey] = Int(videoDimensions.width)
                break

            default:
                config[AVVideoHeightKey] = Int(videoDimensions.height)
                config[AVVideoWidthKey] = Int(videoDimensions.width)
                break
            }

        } else if let pixelBuffer = pixelBuffer {
            config[AVVideoWidthKey] = CVPixelBufferGetWidth(pixelBuffer)
            config[AVVideoHeightKey] = CVPixelBufferGetHeight(pixelBuffer)
        }

        config[AVVideoCodecKey] = codec
        config[AVVideoScalingModeKey] = scalingMode

        if let height = config[AVVideoHeightKey] as? Int {
            config[AVVideoHeightKey] = height - (height % sizeValuesDivisionValue)
        }

        if let width = config[AVVideoWidthKey] as? Int {
            config[AVVideoWidthKey] = width - (width % sizeValuesDivisionValue)
        }

        var compressionDict: [String: Any] = [:]
        compressionDict[AVVideoAverageBitRateKey] = bitRate
        compressionDict[AVVideoAllowFrameReorderingKey] = false
        compressionDict[AVVideoExpectedSourceFrameRateKey] = 30

        if let maxKeyFrameInterval = maxKeyFrameInterval {
            compressionDict[AVVideoMaxKeyFrameIntervalKey] = NSNumber(integerLiteral: maxKeyFrameInterval)
        }

        if let profileLevel = profileLevel {
            compressionDict[AVVideoProfileLevelKey] = profileLevel
        }

        config[AVVideoCompressionPropertiesKey] = compressionDict
        return config
    }
}
