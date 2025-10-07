import SwiftUI

struct AnalyzePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: JournalStore
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    Text(promptText)
                        .textSelection(.enabled)
                        .padding()
                }
                Button {
                    shareItems = [promptText]
                    showShare = true
                } label: {
                    Label("Share Prompt + Last 10 Entries", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Analyze Patterns")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
        }
    }

    private var promptText: String {
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
