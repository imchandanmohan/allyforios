import SwiftUI

struct JournalListView: View {
    @EnvironmentObject var store: JournalStore
    @State private var query: String = ""
    @State private var showConfirmDelete = false

    // Share + Export
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var showExport = false

    // Navigation without chevrons
    @State private var selectedEntryID: UUID?

    // Progressive loading
    @State private var loadedCount = 5
    private let loadStep = 5

    private var filteredAll: [Entry] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return store.entries }
        return store.entries.filter { e in
            e.answers.contains { $0.transcript.localizedCaseInsensitiveContains(query) } ||
            e.copingPlan.localizedCaseInsensitiveContains(query)
        }
    }
    private var filtered: [Entry] {
        Array(filteredAll.prefix(loadedCount))
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search your words…", text: $query)
                            .textInputAutocapitalization(.sentences)
                    }
                }

                if filtered.isEmpty {
                    Section {
                        ContentUnavailableView("No entries yet",
                                               systemImage: "text.badge.plus",
                                               description: Text("Start a new entry in the Record tab."))
                    }
                } else {
                    ForEach(filtered) { entry in
                        ZStack(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.bold())
                                Text(snippet(for: entry))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            // Hidden link (no chevron), drives navigation
                            NavigationLink(
                                destination: EntryDetailView(entry: entry),
                                tag: entry.id,
                                selection: $selectedEntryID
                            ) { EmptyView() }
                            .opacity(0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedEntryID = entry.id }
                        .onAppear {
                            if entry.id == filtered.last?.id, loadedCount < filteredAll.count {
                                loadedCount = min(filteredAll.count, loadedCount + loadStep)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        shareItems = [promptTextForAnalysis()]
                        showShare = true
                    } label: { Image(systemName: "square.and.arrow.up") }
                    .tint(.accentColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showExport = true
                    } label: { Image(systemName: "square.and.arrow.up.on.square") }
                    .tint(.accentColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.entries.count > 50 {
                        Button {
                            showConfirmDelete = true
                        } label: { Image(systemName: "trash") }
                        .tint(.red)
                    }
                }
            }
            .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
            .sheet(isPresented: $showExport) {
                ExportMenu()
                    .presentationDetents([.medium])      // ✅ smaller, faster sheet
                    .presentationDragIndicator(.visible)
            }
            .alert("Delete older entries?", isPresented: $showConfirmDelete) {
                Button("Cancel", role: .cancel) { }
                Button("Delete older (keep latest 50)", role: .destructive) {
                    store.deleteOlderKeepingFirst50()
                    loadedCount = min(loadedCount, store.entries.count)
                }
            } message: {
                Text("This will remove entries older than the 50 most recent. This action cannot be undone.")
            }
        }
        .hideKeyboardOnTap()
    }

    private func snippet(for entry: Entry) -> String {
        entry.answers.map { $0.transcript }.filter { !$0.isEmpty }.prefix(2).joined(separator: " • ")
    }

    private func promptTextForAnalysis() -> String {
        var s = """
You are a compassionate clinical psychologist specializing in anxiety and CBT. Please analyze the patterns across the following 10 most recent self-logs. Your goals:
1) Identify recurring triggers (situations, times, people, thoughts).
2) Map automatic thoughts to emotions and body sensations.
3) Detect safety behaviors and short-term relief patterns.
4) Suggest 2–3 tailored cognitive reframes based on the user's own words.
5) Suggest 2–3 behavioral experiments or coping actions for next time.
6) End with a short validating message in a warm, supportive tone.

Important:
- Be concise but specific.
- Use bullet points.
- Reflect the user’s own phrasing when possible.
- If data is missing, say so and make gentle suggestions.

Logs:
"""
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        for (date, body) in store.topRecentTranscript(10) {
            s += "\n=== \(df.string(from: date)) ===\n\(body)\n"
        }
        return s
    }
}
