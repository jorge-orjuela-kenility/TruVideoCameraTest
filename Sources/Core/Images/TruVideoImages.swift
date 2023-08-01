//
//  TruVideoImages.swift
//  TruVideoExample
//
//  Created by Jorge Orjuela on 6/16/23.
//

import SwiftUI

extension Image {
    /// Indicates whether SwiftUI renders an image as-is, or
    /// by using a different mode.
    ///
    /// - Parameters:
    ///    - renderingMode: The mode SwiftUI uses to render images.
    ///    - color: The color to apply to the image.
    /// - Returns: A modified ``View``.
    func withRenderingMode(_ renderingMode: Image.TemplateRenderingMode?, color: Color) -> some View {
        self.renderingMode(.template)
            .foregroundColor(color)
    }
}

/// Defines the images for the GetTransparency UI Kit.
struct TruVideoImage {
    /// Bolt fill
    static let boltFill = Image(systemName: "bolt.fill")

    /// Bolt slash fill
    static let boltSlashFill = Image(systemName: "bolt.slash.fill")

    /// Camera
    static let camera = Image(systemName: "camera")

    /// Category
    static let category = Image(systemName: "rectangle.stack.fill")

    /// Checkmark
    static let checkmark = Image(systemName: "checkmark")

    /// Close
    static let close = Image(systemName: "xmark")

    /// Chevron backward
    static let chevronBackward = Image(systemName: "chevron.backward")
    
    /// Chevron right
    static let chevronRight = Image(systemName: "chevron.right")

    /// Flip camera
    static let flipCamera = Image(systemName: "arrow.triangle.2.circlepath.camera")

    /// Image quality
    static let imageQuality = Image(systemName: "camera.on.rectangle.fill")

    /// Images
    static let image = Image(systemName: "photo")

    /// Microphone slash fill
    static let microphoneSlasFill = Image(systemName: "mic.slash.fill")

    /// Microphone fill
    static let microphoneFill = Image(systemName: "mic.fill")

    /// Noise cancelation
    static let noiseCancellation = Image(systemName: "phone.and.waveform.fill")

    /// Pause
    static let pause = Image(systemName: "pause.fill")

    /// Photo
    static let photo = Image(systemName: "photo.fill")
    
    /// Play
    static let play = Image(systemName: "play.fill")
    
    /// Rotate camera
    static let rotateCamera = Image("rotate-camera")

    /// Settings
    static let settings = Image(systemName: "gearshape")

    /// Screen recording
    static let recordingScreen = Image("recording-screen", bundle: Bundle.main)
    
    /// Trash
    static let trash = Image(systemName: "trash.fill")
}
