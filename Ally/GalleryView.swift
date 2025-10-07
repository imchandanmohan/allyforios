import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreTransferable   // ✅ needed for custom Transferable

// A tiny wrapper so we can import UIImage via PhotosPickerItem.loadTransferable(...)
private enum ImportError: Error { case badData }
struct PickedUIImage: Transferable {
    let image: UIImage
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let ui = UIImage(data: data) else { throw ImportError.badData }
            return PickedUIImage(image: ui)
        }
    }
}

struct GalleryView: View {
    @EnvironmentObject var store: JournalStore
    @State private var selections: [PhotosPickerItem] = []
    @State private var picks: [String] = []   // up to 3 image filenames
    @State private var segment = 0  // 0 = Calm photos, 1 = Gratitude
    @State private var newGoodThing: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [.cyan, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("", selection: $segment) {
                            Text("Calm photos").tag(0)
                            Text("Gratitude").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if segment == 0 { photosPane } else { gratitudePane }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Calm")
        }
        .onAppear {
            // keep only first 3 images from favorites; no videos
            let imgs = store.favorites.filenames.filter { $0.isImageFilename }
            picks = Array(imgs.prefix(3))
        }
    }

    // MARK: Calm photos (only 3, full-screen feel)
    private var photosPane: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $selections, maxSelectionCount: 3, matching: .images) {
                Label(picks.isEmpty ? "Pick up to 3 photos" : "Replace photos", systemImage: "plus.circle")
                    .padding(10)
                    .background(Color.white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .onChange(of: selections) { _ in Task { await importSelections() } }

            // big carousel — fills most of the screen
            let screen = UIScreen.main.bounds
            let height = max(420, screen.height * 0.75)

            if picks.isEmpty {
                ZStack {
                    Color.white
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle").font(.largeTitle)
                        Text("Add up to three calming photos.")
                            .foregroundColor(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .frame(height: height)
            } else {
                TabView {
                    ForEach(picks, id: \.self) { name in
                        let size = CGSize(width: screen.width, height: height)
                        if let img = ImageDownsampler.downsample(url: store.imageURL(for: name), to: size) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()                 // ✅ cover
                                .frame(width: screen.width - 24, height: height)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                                .padding(.horizontal, 12)
                        }
                    }
                    // Quote page
                    ZStack {
                        Color.white
                        VStack(spacing: 10) {
                            Text("You told yourself:").font(.headline)
                            Text("\"\(store.latestCopingPlan ?? "Be kind to yourself. Breathe.")\"")
                                .multilineTextAlignment(.center).font(.title3).padding(.horizontal)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12)
                }
                .frame(height: height)
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
    }

    // MARK: Gratitude (lightweight)
    private var gratitudePane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Something good that happened…", text: $newGoodThing)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let t = newGoodThing.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    store.goodThings.insert(GoodThing(text: t), at: 0)
                    newGoodThing = ""
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            if store.goodThings.isEmpty {
                Text("Add your good moments here. Reviewing them later boosts mood.")
                    .foregroundColor(.white).padding(.horizontal)
            } else {
                ForEach(store.goodThings) { g in
                    HStack {
                        Text(g.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundColor(.white.opacity(0.9))
                        Spacer()
                    }.padding(.horizontal, 12)
                    Text(g.text)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
                        .padding(.horizontal)
                }
            }
        }
    }

    // MARK: Import helpers
    @MainActor
    private func importSelections() async {
        var newNames: [String] = []
        for item in selections.prefix(3) {
            // Try Data first
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = store.saveImageDataToDocuments(data) {
                newNames.append(name); continue
            }
            // Fallback to our Transferable-wrapped UIImage
            if let wrapped = try? await item.loadTransferable(type: PickedUIImage.self),
               let data = wrapped.image.jpegData(compressionQuality: 0.9),
               let name = store.saveImageDataToDocuments(data) {
                newNames.append(name); continue
            }
        }
        selections.removeAll()
        if !newNames.isEmpty {
            picks = Array(newNames.prefix(3))
            store.favorites.filenames = picks    // persist exactly these 3
        }
    }
}

