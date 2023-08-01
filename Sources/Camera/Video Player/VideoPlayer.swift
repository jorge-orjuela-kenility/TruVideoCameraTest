//
//  VideoPlayer.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVFoundation
import SwiftUI

private extension AVCaptureVideoOrientation {
    /// The preferred transformation for the current orientation
    ///
    /// - Returns: The transformation to be applied
    func transform(with orientation: UIDeviceOrientation) -> CGAffineTransform? {
        switch (self, orientation) {
        case (_, .faceDown), (_, .faceUp), (_, .portraitUpsideDown): return nil
        case (.landscapeLeft, .portrait): return .init(rotationAngle: 3 * .pi / 2)
        case (.landscapeRight, .portrait): return .init(rotationAngle: .pi)
        case (.portraitUpsideDown, .portrait): return .init(rotationAngle: .pi / 2)
        case (.landscapeLeft, .landscapeRight): return .init(rotationAngle: -.pi)
        default: return .identity
        }
    }
}

private extension UIDeviceOrientation {
    /// The preferred transformation for the current orientation
    var preferredTransform:  CGAffineTransform? {
        switch self {
        case .landscapeLeft: return .init(rotationAngle: .pi / 2)
        case .landscapeRight: return .init(rotationAngle: 3 * .pi / 2)
        case .portrait: return .identity
        case .portraitUpsideDown: return .init(rotationAngle: .pi)
        default: return nil
        }
    }
}

/// Shows the video player
struct VideoPlayer: UIViewRepresentable {
    /// The underlying `AVPlayer`
    let player: AVPlayer

    class VideoPlayerView: UIView {
        /// The underlying `AVPlayerLayer`
        private var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }

        // The associated player object.
        var player: AVPlayer? {
            get {
                playerLayer.player
            }

            set {
                playerLayer.player = newValue
                playerLayer.videoGravity = .resizeAspect
            }
        }

        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }
    }

    class VideoPlayerContainerView: UIView {
        /// Play button
        private var playButton: UIButton = {
            let playButton = UIButton()
            playButton.translatesAutoresizingMaskIntoConstraints = false
            playButton.tintColor = .lightGray
            playButton.setBackgroundImage(
                UIImage(systemName: "play.circle.fill")?.withRenderingMode(.alwaysOriginal),
                for: .normal
            )

            return playButton
        }()

        /// The video player view
        lazy var videoPlayerView: VideoPlayerView = {
            let videoPlayerView = VideoPlayerView()
            videoPlayerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            videoPlayerView.backgroundColor = .black

            return videoPlayerView
        }()

        // MARK: Initializers

        override init(frame: CGRect) {
            super.init(frame: frame)
            configure()
            configureObservers()
        }

        required init?(coder: NSCoder) {
            fatalError()
        }

        // MARK: Actions

        @IBAction func play(_ sender: UIButton) {
            videoPlayerView.player?.play()
            sender.isHidden = true
        }

        // MARK: Notification methods

        @objc
        private func didReceiveDeviceOrientationChangedNotification(_ notification: Notification) {
            UIView.animate(withDuration: 0.33) {
                self.updateOrientation()
            }
        }

        @objc
        private func didReceivePlayerItemDidPlayToEndTimeNotification(_ notification: Notification) {
            videoPlayerView.player?.seek(to: .zero) { [self] _ in
                self.playButton.isHidden = false
            }
        }

        // MARK: Private methods

        private func configure() {
            playButton.addTarget(self, action: #selector(play(_:)), for: .touchUpInside)

            addSubview(videoPlayerView)
            addSubview(playButton)

            NSLayoutConstraint.activate([
                playButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                playButton.heightAnchor.constraint(equalToConstant: 100),
                playButton.widthAnchor.constraint(equalToConstant: 100),
            ])

            updateOrientation()
        }

        private func configureObservers() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didReceiveDeviceOrientationChangedNotification(_:)),
                name: UIDevice.orientationDidChangeNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didReceivePlayerItemDidPlayToEndTimeNotification(_:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: nil
            )
        }

        private func updateOrientation() {
            let assetOrientation = videoPlayerView.player?.currentItem?.asset.orientation ?? .portrait
            let orientation = UIDevice.current.orientation

            if let preferredTransform = orientation.preferredTransform {
                playButton.transform = preferredTransform
            }

            if let transform = assetOrientation.transform(with: orientation) {
                videoPlayerView.transform = transform
            }

            frame = UIScreen.main.bounds
            videoPlayerView.frame = UIScreen.main.bounds
        }
    }

    // MARK: Initializers

    /// Creates a new instance of the `VideoPlayerView`
    ///
    /// - Parameter asset: The asset to play.
    init(asset: AVAsset) {
        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["playable", "hasProtectedContent"])
        self.player = .init(playerItem: playerItem)
    }

    // MARK: UIViewRepresentable

    /// Creates the view object and configures its initial state.
    func makeUIView(context: Context) -> UIView {
        let videoPlayerContainerView = VideoPlayerContainerView()
        videoPlayerContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoPlayerContainerView.backgroundColor = .black
        videoPlayerContainerView.videoPlayerView.player = player

        return videoPlayerContainerView
    }

    /// Updates the state of the specified view with new information from
    /// SwiftUI.
    func updateUIView(_ uiView: UIView, context: Context) {}
}
