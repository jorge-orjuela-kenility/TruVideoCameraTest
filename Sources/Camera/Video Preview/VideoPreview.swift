//
//  VideoPreview.swift
//
//  Created by TruVideo on 6/16/22.
//  Copyright © 2023 TruVideo. All rights reserved.
//

import AVKit
import SwiftUI

/// Shows the camera for recording videos
struct VideoPreview: View {
    /// An action that dismisses the view.
    @Environment(\.dismiss) var dismiss
    
    /// The  url of the asset to play.
    let url: URL

    /// The content and behavior of the view.
    var body: some View {
        NavigationView {
            ZStack {
                AVKit.VideoPlayer(player: AVPlayer(url: url))
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                
                Button(action: dismiss.callAsFunction) {
                    TruVideoImage.close
                        .withRenderingMode(.template, color: .white)
                        .padding([.horizontal, .top], TruVideoSpacing.lg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .edgesIgnoringSafeArea(.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarHidden(true)
            .statusBar(hidden: true)
        }
    }
}
