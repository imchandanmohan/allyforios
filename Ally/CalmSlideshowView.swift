import SwiftUI
import AVFoundation

struct CalmSlideshowView: View {
    let imageNames: [String]
    let quote: String
    let autoPlayAudioURL: URL?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: JournalStore
    @State private var page = 0
    @State private var player: AVAudioPlayer?
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = CGSize(width: geo.size.width - 40, height: min(geo.size.width * 0.66, 420))
            VStack(spacing: 12) {
                TabView(selection: $page) {
                    ForEach(Array(imageNames.enumerated()), id: \.offset) { idx, name in
                        if let img = ImageDownsampler.downsample(url: store.imageURL(for: name), to: size) {
                            Image(uiImage: img)
                                .resizable().scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                                .padding()
                                .tag(idx)
                        } else {
                            Color.gray.opacity(0.2)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .padding().tag(idx)
                        }
                    }
                    ZStack {
                        Color.white
                        VStack(spacing: 12) {
                            Text("You told yourself:").font(.headline)
                            Text("\"\(quote)\"")
                                .multilineTextAlignment(.center).font(.title3).padding(.horizontal)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20)).padding().tag(imageNames.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: size.height + 40)
                .onReceive(timer) { _ in page = (page + 1) % (imageNames.count + 1) }

                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .onAppear {
                if let url = autoPlayAudioURL {
                    do { let p = try AVAudioPlayer(contentsOf: url); p.play(); player = p } catch {}
                }
            }
        }
    }
}
