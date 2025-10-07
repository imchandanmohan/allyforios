import Foundation
import UIKit
import Combine

// MARK: - Data models

struct Question: Identifiable, Hashable, Codable {
    let id: UUID
    let prompt: String
    init(prompt: String) { id = UUID(); self.prompt = prompt }
}

struct Answer: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let questionPrompt: String
    var audioFileName: String?
    var videoFileName: String?       // NEW: optional video attached to the answer
    var transcript: String
}

struct Entry: Identifiable, Codable, Hashable, Equatable {
    var id: UUID = UUID()
    let timestamp: Date
    var answers: [Answer]
    var copingPlan: String = ""
    var copingPlanAudioFileName: String?   // NEW: voice note for coping plan
}

struct FavoritePhotos: Codable, Hashable {
    var filenames: [String] = []
}

struct GoodThing: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String
}

struct ReflectCard: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var body: String
}

// MARK: - Store

final class JournalStore: ObservableObject {
    @Published var questions: [Question] = [
        Question(prompt: "Situation (when/where)?"),
        Question(prompt: "Thoughts?"),
        Question(prompt: "Physical sensations?"),
        Question(prompt: "Anxiety rating (1–10)?"),
        Question(prompt: "What did I do?"),
        Question(prompt: "What did I say to myself?"),
        Question(prompt: "Second rating (1–10)?")
    ]

    @Published var currentAnswers: [Answer] = []
    @Published var lastAdvice: String? {
        didSet { UserDefaults.standard.set(lastAdvice, forKey: "lastAdvice") }
    }

    @Published var entries: [Entry] = [] { didSet { saveEntries() } }
    @Published var favorites: FavoritePhotos = FavoritePhotos() { didSet { saveFavorites() } }
    @Published var goodThings: [GoodThing] = [] { didSet { saveGoodThings() } }
    @Published var reflectCards: [ReflectCard] = [] { didSet { saveReflectCards() } }

    init() {
        loadEntries()
        loadFavorites()
        loadGoodThings()
        loadReflectCards()
        self.lastAdvice = UserDefaults.standard.string(forKey: "lastAdvice")
        if reflectCards.isEmpty {
            reflectCards = Self.defaultReflectCards
        }
    }

    // MARK: Flow
    func startNewSession() {
        currentAnswers = questions.map { Answer(questionPrompt: $0.prompt, audioFileName: nil, videoFileName: nil, transcript: "") }
    }
    func completeSession() {
        guard !currentAnswers.isEmpty else { return }
        let entry = Entry(timestamp: Date(), answers: currentAnswers)
        entries.insert(entry, at: 0)
        currentAnswers.removeAll()
    }
    func updateEntry(_ e: Entry) {
        if let i = entries.firstIndex(where: { $0.id == e.id }) { entries[i] = e; saveEntries() }
    }

    var latestCopingPlan: String? {
        entries.first(where: { !$0.copingPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.copingPlan
    }
    var latestCopingPlanAudioURL: URL? {
        guard let name = entries.first(where: { $0.copingPlanAudioFileName != nil })?.copingPlanAudioFileName else { return nil }
        return imageURL(for: name)
    }

    // MARK: Bulk deletion (keep most recent 50)
    func deleteOlderKeepingFirst50() {
        guard entries.count > 50 else { return }
        entries = Array(entries.prefix(50))
        saveEntries()
    }

    // MARK: Prompt helper (top N transcripts)
    func topRecentTranscript(_ n: Int) -> [(Date, String)] {
        entries.prefix(n).map { e in
            let joined = e.answers.map { "- \($0.questionPrompt): \($0.transcript)" }.joined(separator: "\n")
            return (e.timestamp, joined)
        }
    }

    // MARK: Files
    private var docs: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first! }
    private var entriesURL: URL { docs.appendingPathComponent("entries.json") }
    private var favoritesURL: URL { docs.appendingPathComponent("favorites.json") }
    private var goodThingsURL: URL { docs.appendingPathComponent("goodthings.json") }
    private var reflectURL: URL { docs.appendingPathComponent("reflect.json") }

    private func saveEntries() {
        do { try JSONEncoder().encode(entries).write(to: entriesURL, options: .atomic) }
        catch { print("Save entries error: \(error)") }
    }
    private func loadEntries() {
        entries = (try? JSONDecoder().decode([Entry].self, from: Data(contentsOf: entriesURL))) ?? []
    }

    private func saveFavorites() {
        do { try JSONEncoder().encode(favorites).write(to: favoritesURL, options: .atomic) }
        catch { print("Save favorites error: \(error)") }
    }
    private func loadFavorites() {
        favorites = (try? JSONDecoder().decode(FavoritePhotos.self, from: Data(contentsOf: favoritesURL))) ?? FavoritePhotos()
    }

    private func saveGoodThings() {
        do { try JSONEncoder().encode(goodThings).write(to: goodThingsURL, options: .atomic) }
        catch { print("Save goodThings error: \(error)") }
    }
    private func loadGoodThings() {
        goodThings = (try? JSONDecoder().decode([GoodThing].self, from: Data(contentsOf: goodThingsURL))) ?? []
    }

    private func saveReflectCards() {
        do { try JSONEncoder().encode(reflectCards).write(to: reflectURL, options: .atomic) }
        catch { print("Save reflect error: \(error)") }
    }
    private func loadReflectCards() {
        reflectCards = (try? JSONDecoder().decode([ReflectCard].self, from: Data(contentsOf: reflectURL))) ?? []
    }

    // MARK: Generic file helpers
    func saveDataToDocuments(_ data: Data, fileExt: String) -> String? {
        let name = "file-\(UUID().uuidString).\(fileExt)"
        let url = docs.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic); return name }
        catch { print("Save data error: \(error)"); return nil }
    }
    func saveImageDataToDocuments(_ data: Data) -> String? {
        let name = "fav-\(UUID().uuidString).jpg"
        let url = docs.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic); return name }
        catch { print("Save image error: \(error)"); return nil }
    }
    func imageURL(for filename: String) -> URL { docs.appendingPathComponent(filename) }
    func uiImage(for filename: String) -> UIImage? { UIImage(contentsOfFile: imageURL(for: filename).path) }

    // Default Reflect cards (book-style prompts)
    static let defaultReflectCards: [ReflectCard] = [
        ReflectCard(title: "Name the feeling", body: "Write 3 words for what you feel right now. Then write one helpful response you would give a friend."),
        ReflectCard(title: "Trigger check", body: "What situation, person, or thought preceded your symptoms? Note time and place."),
        ReflectCard(title: "Body scan", body: "Where does the anxiety live in your body? Describe sensation and intensity (1–10)."),
        ReflectCard(title: "Reframe", body: "Write one thought that fuels anxiety. Now write a balanced thought that is true and kind."),
        ReflectCard(title: "Gratitude x3", body: "List three small wins from today (no matter how small).")
    ]
}
