//
//  TruVideoError.swift
//
//  Created by TruVideo on 6/14/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import Foundation

/// A type representing all the errors that can be thrown.
public struct TruVideoError: LocalizedError {
    /// The affected column line in the source code.
    public let column: Int

    /// The affected line in the source code.
    public let line: Int

    /// The underliying kind of error.
    public let kind: ErrorKind

    /// The underliying error.
    public let underlyingError: Error?

    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        underlyingError?.localizedDescription ?? localizedDescription
    }

    /// A default instance of the unknown error.
    static let unknown = TruVideoError(kind: .unknown)

    /// The underliying kind of error.
    public enum ErrorKind {
        /// The media type usage was denied
        case accessDenied

        /// canAddOutput threw an error in.
        case cannotAddAudioOutput

        /// canAddInput threw an error in
        case cannotAddDevice

        /// `addPhotoOutput` threw an error in.
        case cannotAddPhotoOutput

        /// canAddOutput threw an error in.
        case cannotAddVideoOutput

        /// sessionPreset threw an error in.
        case cannotSetPresset
        
        /// Exporter error.
        case exporter

        /// `capturePhoto` threw an error in.
        case failedToCapturePhoto

        /// Thrown when the pausing the recording fails
        case failedToPauseRecording

        /// Thrown when the stopping the recording fails
        case failedToStopRecording

        /// Thrown when the setting the torch has failed
        case failedToSetTorch

        /// Whether the record cant start due to lack of permissions
        case notAuthorized
        
        /// Whether there is a record in progress
        case recordInProgress

        /// Thrown when the torch is not available
        case torchNotAvailable

        /// Whether the torch is not supported
        case torchNotSupported
        
        /// Trimming failed.
        case trimFailed

        /// Unknown error.
        case unknown
    }

    // MARK: Initializers

    /// Creates a new instance of the network error with the given
    /// underliying error type.
    ///
    /// - Parameters:
    ///   - kind: The type of error.
    ///   - column: The affected column line in the source code.
    ///   - line: The affected line in the srouce code.
    ///   - underlyingError: The underliying error.
    public init(kind: ErrorKind, underlyingError: Error? = nil, column: Int = #column, line: Int = #line) {
        self.column = column
        self.kind = kind
        self.line = line
        self.underlyingError = underlyingError
    }
}
