import SwiftUI
import AVFoundation

struct EntryDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: JournalStore

    let entry: Entry
    @State private var working: Entry
    @FocusState private var planFocused: Bool

    // simple recorder for coping plan
    @StateObject private var recorder = AudioRecorder()
    @State private var copingURL: URL?
    @State private var player: AVAudioPlayer?

    init(entry: Entry) {
        self.entry = entry
        _working = State(initialValue: entry)
    }

    var body: some View {
        Form {
            Section {
                Text(entry.timestamp.formatted(date: .complete, time: .shortened))
                    .font(.subheadline).foregroundColor(.secondary)
            }
            ForEach(Array(working.answers.enumerated()), id: \.element.id) { idx, _ in
                Section {
                    Text(working.answers[idx].questionPrompt).font(.subheadline.bold())
                    TextEditor(text: bindingForTranscript(idx))
                        .frame(minHeight: 120)
                } header: { Text("Answer \(idx + 1)") }
            }
            Section {
                TextEditor(text: $working.copingPlan)
                    .frame(minHeight: 140)
                    .focused($planFocused)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                HStack(spacing: 14) {
                    Button(recorder.isRecording() ? "Stop" : "Record Plan") {
                        if recorder.isRecording() {
                            if let u = recorder.stopRecording() {
                                copingURL = u
                                working.copingPlanAudioFileName = u.lastPathComponent
                            }
                        } else {
                            recorder.ensurePermissionThen { ok in
                                if ok { _ = try? recorder.startRecording() }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if let name = working.copingPlanAudioFileName {
                        Button("Play Plan") {
                            let url = store.imageURL(for: name)
                            do { let p = try AVAudioPlayer(contentsOf: url); p.play(); player = p } catch {}
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: { Text("Coping Plan (What I’ll do better next time)") }
              footer: { Text("This message (and voice note) appears later in Calm and after sessions.") }
        }
        .navigationTitle("Entry")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { store.updateEntry(working); dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                    planFocused = false
                }
            }
        }
        .onDisappear { if working != entry { store.updateEntry(working) } }
        .hideKeyboardOnTap()
    }

    private func bindingForTranscript(_ idx: Int) -> Binding<String> {
        Binding(get: { working.answers[idx].transcript },
                set: { working.answers[idx].transcript = $0 })
    }
}
