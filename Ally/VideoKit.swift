import SwiftUI
import PhotosUI
import AVKit

struct VideoPicker: View {
    var onPicked: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sel: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                PhotosPicker("Pick a video", selection: $sel, matching: .videos)
                if isLoading { ProgressView() }
                Spacer()
            }
            .padding()
            .navigationTitle("Add Video")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onPicked(nil); dismiss() }
                }
            }
            .onChange(of: sel) { _ in Task { await load() } }
        }
    }

    private func load() async {
        guard let item = sel else { return }
        isLoading = true
        defer { isLoading = false }

        if let url = try? await item.loadTransferable(type: URL.self) {
            onPicked(url); dismiss(); return
        }
        if let data = try? await item.loadTransferable(type: Data.self),
           let tmp = try? saveTemp(data: data, ext: "mov") {
            onPicked(tmp); dismiss(); return
        }
        onPicked(nil); dismiss()
    }

    private func saveTemp(data: Data, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("picked-\(UUID().uuidString).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }
}

struct VideoPlayerView: View {
    let fileURL: URL
    var body: some View {
        VideoPlayer(player: AVPlayer(url: fileURL))
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
    }
}

// If your call site uses `VideoPlayerView(autoPlayAudioURL: url)` keep this:
extension VideoPlayerView {
    init(autoPlayAudioURL url: URL) { self.init(fileURL: url) }
}
