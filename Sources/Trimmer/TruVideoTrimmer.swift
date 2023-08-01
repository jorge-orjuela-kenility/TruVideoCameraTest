//
//  TruVideoTrimmer.swift
//  TruVideoCamera
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation

/// Represents all the errors that can be thrown during the
/// trimming process.
enum TruVideoTrimmerError: Error {
    /// The export session could not be created.
    case failedToCreateExportSession
    
    /// The given file was not found.
    case fileNotFound
    
    /// The trimming process was canceled.
    case trimCancelled
}

/// A utility protocol that handles video trimming functionality.
public protocol TruVideoTrimmer {
    /// Trims the video from the specified start time to the specified end time.
    ///
    /// - Parameters:
    ///    - sourceURL: The URL of the source video to be trimmed.
    ///    - destination: The destination URL for the resulting video.
    ///    - startTime: The start time of the trimmed video segment.
    ///    - endTime: The end time of the trimmed video segment.
    /// - Returns: The URL of the resulting video.
    /// - Throws: An error if the trimming process fails.
    func trim(_ sourceURL: URL, destination: URL, from start: CMTime, to end: CMTime) async throws
}

/// A utility class built on top of  AVFoundation that handles video trimming functionality.
public class AVATruvideoTrimmer: TruVideoTrimmer {
    private let fileManager: FileManager
    
    // MARK: Initializers
    
    /// Creates a new instance of the `AVATruvideoTrimmer`.
    ///
    /// - Parameter fileManager: A convenient interface to the contents of the file system.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // MARK: TruVideoTrimmer
    
    /// Trims the video from the specified start time to the specified end time.
    ///
    /// - Parameters:
    ///    - sourceURL: The URL of the source video to be trimmed.
    ///    - destination: The destination URL for the resulting video.
    ///    - startTime: The start time of the trimmed video segment.
    ///    - endTime: The end time of the trimmed video segment.
    /// - Returns: The URL of the resulting video.
    /// - Throws: An error if the trimming process fails.
    public func trim(_ sourceURL: URL, destination: URL, from start: CMTime, to end: CMTime) async throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw TruVideoError(kind: .trimFailed, underlyingError: TruVideoTrimmerError.fileNotFound)
        }
        
        let asset = AVAsset(url: sourceURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            
            throw TruVideoError(kind: .trimFailed, underlyingError: TruVideoTrimmerError.failedToCreateExportSession)
        }
                
        exportSession.outputURL = destination
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.timeRange = CMTimeRange(start: start, end: end)
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw TruVideoError(kind: .trimFailed, underlyingError: error)
        }
        
        switch exportSession.status {
        case .cancelled:
            throw TruVideoError(kind: .trimFailed, underlyingError: TruVideoTrimmerError.trimCancelled)
            
        default:
            break
        }
    }
}
