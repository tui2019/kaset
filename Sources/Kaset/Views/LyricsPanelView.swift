import SwiftUI

// Non-AI fallback panel for environments where FoundationModels is unavailable.
// Keeps lyrics sidebar functional on older systems/toolchains.
struct LyricsPanelView: View {
    @Environment(PlayerService.self) private var playerService
    @Environment(SyncedLyricsService.self) private var syncedLyricsService

    let client: any YTMusicClientProtocol

    @State private var lastLoadedVideoId: String?
    @State private var isLoadingFallback = false
    @Namespace private var lyricsNamespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                self.headerView

                Divider()
                    .opacity(0.3)

                self.contentView
            }
            .frame(width: 280)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .glassEffectID("lyricsPanel", in: self.lyricsNamespace)
        }
        .glassEffectTransition(.materialize)
        .onChange(of: self.playerService.currentTrack?.videoId) { _, newVideoId in
            if let videoId = newVideoId, videoId != self.lastLoadedVideoId {
                Task {
                    await self.loadLyrics(for: videoId)
                }
            }
        }
        .task {
            if let videoId = self.playerService.currentTrack?.videoId {
                await self.loadLyrics(for: videoId)
            }
        }
        .onChange(of: self.syncedLyricsService.currentLyrics) { _, newLyrics in
            self.updateLyricsPolling(for: newLyrics)
        }
        .onDisappear {
            SingletonPlayerWebView.shared.stopLyricsPoll()
        }
        .onAppear {
            self.updateLyricsPolling(for: self.syncedLyricsService.currentLyrics)
        }
    }

    private func updateLyricsPolling(for result: LyricResult) {
        if case .synced = result {
            SingletonPlayerWebView.shared.startLyricsPoll()
        } else {
            SingletonPlayerWebView.shared.stopLyricsPoll()
        }
    }

    private var headerView: some View {
        HStack {
            Text("Lyrics")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var contentView: some View {
        if self.playerService.currentTrack == nil {
            self.noTrackPlayingView
        } else if self.syncedLyricsService.isLoading || self.isLoadingFallback {
            self.loadingView
        } else {
            switch self.syncedLyricsService.currentLyrics {
            case let .synced(synced):
                SyncedLyricsDisplayView(
                    lyrics: synced,
                    currentTimeMs: self.playerService.currentTimeMs,
                    onSeek: { timeMs in
                        Task { await self.playerService.seek(to: Double(timeMs) / 1000.0) }
                    }
                )
                .background(Color.clear)
            case let .plain(plain):
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(plain.text)
                            .font(.system(size: 15, weight: .medium))
                            .lineSpacing(8)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)

                        if let source = plain.source {
                            Divider()
                                .padding(.horizontal, 16)

                            Text(source)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }
                }
            case .unavailable:
                self.noLyricsView
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)
                .frame(width: 20, height: 20)
            Text("Loading lyrics...", comment: "Lyrics panel loading state")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noLyricsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No Lyrics Available")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("There aren't any lyrics available for this song.", comment: "Lyrics unavailable message")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noTrackPlayingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.circle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No Song Playing")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Play a song to view its lyrics here.", comment: "No song playing lyrics message")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadLyrics(for videoId: String) async {
        self.lastLoadedVideoId = videoId
        self.isLoadingFallback = false

        guard let track = self.playerService.currentTrack else { return }
        guard track.videoId == videoId else { return }

        let info = LyricsSearchInfo(
            title: track.title,
            artist: track.artistsDisplay,
            album: track.album?.title,
            duration: track.duration,
            videoId: track.videoId
        )

        if SettingsManager.shared.syncedLyricsEnabled {
            await self.syncedLyricsService.fetchLyrics(for: info)
        } else {
            self.syncedLyricsService.currentLyrics = .unavailable
            self.syncedLyricsService.activeProvider = nil
        }

        guard self.lastLoadedVideoId == videoId else { return }
        guard self.playerService.currentTrack?.videoId == videoId else { return }

        if case .unavailable = self.syncedLyricsService.currentLyrics {
            self.isLoadingFallback = true
            defer {
                if self.lastLoadedVideoId == videoId {
                    self.isLoadingFallback = false
                }
            }

            do {
                let fetchedLyrics = try await self.client.getLyrics(videoId: videoId)
                if self.lastLoadedVideoId == videoId,
                   self.playerService.currentTrack?.videoId == videoId
                {
                    self.syncedLyricsService.fallbackToPlainLyrics(fetchedLyrics, videoId: videoId)
                }
            } catch {
                DiagnosticsLogger.api.error("Failed to load plain lyrics fallback: \(error.localizedDescription)")
            }
        }
    }
}

