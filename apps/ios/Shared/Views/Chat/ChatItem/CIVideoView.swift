//
//  CIVideoView.swift
//  SimpleX
//
//  Created by Avently on 30/03/2023.
//  Copyright © 2023 SimpleX Chat. All rights reserved.
//

import SwiftUI
import AVKit
import SimpleXChat

struct CIVideoView: View {
    @Environment(\.colorScheme) var colorScheme
    private let chatItem: ChatItem
    private let image: String
    @State private var duration: Int
    @State private var progress: Int = 0
    @State private var videoPlaying: Bool = false
    private let maxWidth: CGFloat
    @Binding private var videoWidth: CGFloat?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var preview: UIImage? = nil
    @State private var player: AVPlayer?
    @State private var url: URL?
    @State private var showFullScreenPlayer = false
    @State private var timeObserver: Any? = nil
    @State private var fullScreenTimeObserver: Any? = nil

    init(chatItem: ChatItem, image: String, duration: Int, maxWidth: CGFloat, videoWidth: Binding<CGFloat?>, scrollProxy: ScrollViewProxy?) {
        self.chatItem = chatItem
        self.image = image
        self._duration = State(initialValue: duration)
        self.maxWidth = maxWidth
        self._videoWidth = videoWidth
        self.scrollProxy = scrollProxy
        if let url = getLoadedVideo(chatItem.file) {
            self._player = State(initialValue: VideoPlayerView.getOrCreatePlayer(url, false))
            self._url = State(initialValue: url)
        }
        if let data = Data(base64Encoded: dropImagePrefix(image)),
           let uiImage = UIImage(data: data) {
            self._preview = State(initialValue: uiImage)
        }
    }

    var body: some View {
        let file = chatItem.file
        ZStack {
            ZStack(alignment: .topLeading) {
                if let file = file, let preview = preview, let player = player, let url = url {
                    videoView(player, url, file, preview, duration)
                } else if let data = Data(base64Encoded: dropImagePrefix(image)),
                          let uiImage = UIImage(data: data) {
                    imageView(uiImage)
                    .onTapGesture {
                        if let file = file {
                            switch file.fileStatus {
                            case .rcvInvitation:
                                receiveFileIfValidSize(file: file, receiveFile: receiveFile)
                            case .rcvAccepted:
                                switch file.fileProtocol {
                                case .xftp:
                                    AlertManager.shared.showAlertMsg(
                                        title: "Waiting for video",
                                        message: "Video will be received when your contact completes uploading it."
                                    )
                                case .smp:
                                    AlertManager.shared.showAlertMsg(
                                        title: "Waiting for video",
                                        message: "Video will be received when your contact is online, please wait or check later!"
                                    )
                                }
                            case .rcvTransfer: () // ?
                            case .rcvComplete: () // ?
                            case .rcvCancelled: () // TODO
                            default: ()
                            }
                        }
                    }
                }
                durationProgress()
            }
            if let file = file, case .rcvInvitation = file.fileStatus {
                Button {
                    receiveFileIfValidSize(file: file, receiveFile: receiveFile)
                } label: {
                    playPauseIcon("play.fill")
                }
            }
        }
    }

    private func videoView(_ player: AVPlayer, _ url: URL, _ file: CIFile, _ preview: UIImage, _ duration: Int) -> some View {
        let w = preview.size.width <= preview.size.height ? maxWidth * 0.75 : maxWidth
        DispatchQueue.main.async { videoWidth = w }
        return ZStack(alignment: .topTrailing) {
            ZStack(alignment: .center) {
                VideoPlayerView(player: player, url: url, showControls: false)
                .frame(width: w, height: w * preview.size.height / preview.size.width)
                .onChange(of: ChatModel.shared.stopPreviousRecPlay) { playingUrl in
                    if playingUrl != url {
                        player.pause()
                        videoPlaying = false
                    }
                }
                .fullScreenCover(isPresented: $showFullScreenPlayer) {
                    fullScreenPlayer(url)
                }
                .onTapGesture {
                    switch player.timeControlStatus {
                    case .playing:
                        player.pause()
                        videoPlaying = false
                    case .paused:
                        showFullScreenPlayer = true
                    default: ()
                    }
                }
                if !videoPlaying {
                    Button {
                        ChatModel.shared.stopPreviousRecPlay = url
                        player.play()
                    } label: {
                        playPauseIcon("play.fill")
                    }
                }
            }
            loadingIndicator()
        }
        .onAppear {
            addObserver(player, url)
        }
        .onDisappear {
            removeObserver()
            player.pause()
            videoPlaying = false
        }
    }

    private func playPauseIcon(_ image: String, _ color: Color = .white) -> some View {
        Image(systemName: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 12, height: 12)
        .foregroundColor(color)
        .padding(.leading, 4)
        .frame(width: 40, height: 40)
        .background(Color.black.opacity(0.35))
        .clipShape(Circle())
    }

    private func durationProgress() -> some View {
        HStack {
            Text("\(durationText(videoPlaying ? progress : duration))")
            .foregroundColor(.white)
            .font(.caption)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(Color.black.opacity(0.35))
            .cornerRadius(10)
            .padding([.top, .leading], 6)

            if let file = chatItem.file, !videoPlaying {
                Text("\(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .binary))")
                .foregroundColor(.white)
                .font(.caption)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.black.opacity(0.35))
                .cornerRadius(10)
                .padding(.top, 6)
            }
        }
    }

    private func imageView(_ img: UIImage) -> some View {
        let w = img.size.width <= img.size.height ? maxWidth * 0.75 : .infinity
        DispatchQueue.main.async { videoWidth = w }
        return ZStack(alignment: .topTrailing) {
            Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: w)
            loadingIndicator()
        }
    }

    @ViewBuilder private func loadingIndicator() -> some View {
        if let file = chatItem.file {
            switch file.fileStatus {
            case .sndStored:
                switch file.fileProtocol {
                case .xftp: progressView()
                case .smp: EmptyView()
                }
            case let .sndTransfer(sndProgress, sndTotal):
                switch file.fileProtocol {
                case .xftp: progressCircle(sndProgress, sndTotal)
                case .smp: progressView()
                }
            case .sndComplete:
                Image(systemName: "checkmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 10, height: 10)
                .foregroundColor(.white)
                .padding(13)
            case .rcvInvitation:
                Image(systemName: "arrow.down")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
                .padding(11)
            case .rcvAccepted:
                Image(systemName: "ellipsis")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundColor(.white)
                .padding(11)
            case let .rcvTransfer(rcvProgress, rcvTotal):
                if file.fileProtocol == .xftp && rcvProgress < rcvTotal {
                    progressCircle(rcvProgress, rcvTotal)
                } else {
                    progressView()
                }
            default: EmptyView()
            }
        }
    }

    private func progressView() -> some View {
        ProgressView()
        .progressViewStyle(.circular)
        .frame(width: 16, height: 16)
        .tint(.white)
        .padding(11)
    }

    private func progressCircle(_ progress: Int64, _ total: Int64) -> some View {
        Circle()
        .trim(from: 0, to: Double(progress) / Double(total))
        .stroke(
            Color(uiColor: .white),
            style: StrokeStyle(lineWidth: 2)
        )
        .rotationEffect(.degrees(-90))
        .frame(width: 16, height: 16)
        .padding([.trailing, .top], 11)
    }

    private func receiveFileIfValidSize(file: CIFile, receiveFile: @escaping (User, Int64) async -> Void) {
        Task {
            if let user = ChatModel.shared.currentUser {
                await receiveFile(user, file.fileId)
            }
            // TODO image accepted alert?
        }
    }

    private func fullScreenPlayer(_ url: URL) -> some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VideoPlayer(player: createFullScreenPlayerAndPlay(url)) {
            }
            .overlay(alignment: .topLeading, content: {
                Button(action: { showFullScreenPlayer = false },
                    label: {
                        Image(systemName: "multiply")
                        .resizable()
                        .tint(.white)
                        .frame(width: 15, height: 15)
                        .padding(.leading, 15)
                        .padding(.top, 13)
                    }
                )
            })
            .gesture(
                DragGesture(minimumDistance: 80)
                .onChanged { gesture in
                    let t = gesture.translation
                    let w = abs(t.width)
                    if t.height > 60 && t.height > w * 2 {
                        showFullScreenPlayer = false
                    }
                }
            )
            .onDisappear {
                if let fullScreenTimeObserver = fullScreenTimeObserver {
                    NotificationCenter.default.removeObserver(fullScreenTimeObserver)
                }
                fullScreenTimeObserver = nil
            }
        }
    }

    private func createFullScreenPlayerAndPlay(_ url: URL) -> AVPlayer {
        let player = AVPlayer(url: url)
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            ChatModel.shared.stopPreviousRecPlay = url
            player.play()
            fullScreenTimeObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                player.seek(to: CMTime.zero)
                player.play()
            }
        }
        return player
    }

    private func addObserver(_ player: AVPlayer, _ url: URL) {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.01, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { time in
            if let item = player.currentItem {
                let dur = CMTimeGetSeconds(item.duration)
                if !dur.isInfinite && !dur.isNaN {
                    duration = Int(dur)
                }
                progress = Int(CMTimeGetSeconds(player.currentTime()))
                // `if` prevents showing Play button while the playback seeks to start and then plays
                if player.currentTime() != player.currentItem?.duration && player.currentTime() != .zero {
                    videoPlaying = player.timeControlStatus == .playing || player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                }
            }
        }
    }

    private func removeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
    }
}
