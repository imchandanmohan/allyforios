import SwiftUI
import AVFoundation

private enum Brand {
    static let gradient = LinearGradient(colors: [Color.pink, Color.orange, Color.purple],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let card = Color.white.opacity(0.96)
    static let icon = Color.white
}

struct RecordFlowView: View {
    @EnvironmentObject var store: JournalStore
    @StateObject private var recorder = AudioRecorder()
    @State private var transcriber: SpeechTranscriber? = nil

    @State private var stepIndex = 0
    @State private var recordingURLForStep: URL?
    @State private var audioPlayer: AVAudioPlayer?

    // timer
    @State private var elapsed: TimeInterval = 0
    @State private var timerOn = false
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    // slideshow
    @State private var showSlideshow = false
    @State private var slideshowPicks: [String] = []

    // guards
    @State private var isFinishing = false
    @State private var showMicDenied = false
    @State private var showRecordError = false
    @State private var recordErrorMessage = "Recording failed."

    // UI
    @FocusState private var transcriptFocused: Bool

    // Derived
    private var stepIsValid: Bool {
        !store.currentAnswers.isEmpty &&
        stepIndex >= 0 &&
        stepIndex < store.currentAnswers.count &&
        stepIndex < store.questions.count
    }

    var body: some View {
        NavigationView {
            ZStack {
                Brand.gradient.ignoresSafeArea()
                VStack(spacing: 14) {
                    if store.currentAnswers.isEmpty {
                        header
                        startButton
                        quoteSquare
                        Spacer()
                    } else {
                        if stepIsValid {
                            flowView
                                .disabled(isFinishing)
                                .allowsHitTesting(!isFinishing)
                        } else {
                            VStack(spacing: 8) { ProgressView(); Text("Preparing…").foregroundColor(.white.opacity(0.9)) }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Letmecheck")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !store.currentAnswers.isEmpty {
                        Button("Cancel") { cancelSession() }.tint(Brand.icon)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { transcriptFocused = false }
                }
            }
            .onReceive(tick) { _ in if timerOn { elapsed += 0.2 } }
            .sheet(isPresented: $showSlideshow) {
                CalmSlideshowView(
                    imageNames: slideshowPicks,
                    quote: store.latestCopingPlan ?? "Be kind to yourself. Breathe.",
                    autoPlayAudioURL: store.latestCopingPlanAudioURL
                )
            }
            .alert("Microphone Access Needed", isPresented: $showMicDenied) { Button("OK", role: .cancel) {} } message: {
                Text("Please enable Microphone access in Settings to record your voice.")
            }
            .alert("Recording Error", isPresented: $showRecordError) { Button("OK", role: .cancel) {} } message: {
                Text(recordErrorMessage)
            }
        }
        .hideKeyboardOnTap()   // now simultaneous; won’t freeze buttons
    }

    // MARK: Home UI (lightweight)
    private var header: some View {
        VStack(spacing: 8) {
            Text("Breathe in. Breathe out.")
                .font(.title.bold()).foregroundColor(.white)
            Text("Answer by voice or type. Everything stays neat and organized.")
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }

    private var startButton: some View {
        Button(action: startSession) {
            Label("Start New Entry", systemImage: "record.circle")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Brand.card)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 8)
        }
        .padding(.top, 8)
        .tint(Brand.icon)
        .accessibilityIdentifier("startButton")
    }

    // Square quote card
    private var quoteSquare: some View {
        let quote = (store.latestCopingPlan?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Be kind to yourself. Breathe."
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                Text("You told yourself:").font(.headline)
                Text("“\(quote)”").font(.title3)
                Spacer()
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
    }

    // MARK: Flow (questions) — swipe only
    private var flowView: some View {
        VStack(spacing: 12) {
            Text("Question \(stepIndex + 1) of \(store.questions.count)")
                .font(.caption).foregroundColor(.white.opacity(0.95))

            let q = store.questions[stepIndex]
            Text(q.prompt)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Brand.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            TextEditor(text: answerBinding(for: stepIndex))
                .focused($transcriptFocused)
                .frame(minHeight: 200)
                .padding(8)
                .background(Brand.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .scrollContentBackground(.hidden)

            VStack(spacing: 8) {
                Button(action: startStopTapped) {
                    ZStack {
                        Circle().fill(isRecording ? Color.red : Color.green)
                            .frame(width: 76, height: 76).shadow(radius: 6)
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.title).foregroundColor(.white)
                    }
                }
                .tint(Brand.icon)

                Text(timerText)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)

                Text("Swipe to move between questions →")
                    .font(.footnote).foregroundColor(.white.opacity(0.8)).padding(.top, 2)
            }

            if let file = recordingURLForStep {
                Button { play(url: file) } label: { Label("Play audio", systemImage: "play.circle.fill") }
                    .buttonStyle(.borderedProminent)
            }

            Spacer(minLength: 8)
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 20).onEnded { g in
                guard !isFinishing else { return }
                if g.translation.width < -40 { goNext() }
                else if g.translation.width > 40, stepIndex > 0 {
                    transcriptFocused = false
                    stopIfRecording()
                    stepIndex -= 1
                }
            }
        )
    }

    // MARK: Binding (bounds-safe)
    private func answerBinding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index >= 0 && index < store.currentAnswers.count else { return "" }
                return store.currentAnswers[index].transcript
            },
            set: { newVal in
                guard index >= 0 && index < store.currentAnswers.count else { return }
                store.currentAnswers[index].transcript = newVal
            }
        )
    }

    // MARK: Session control
    private func startSession() {
        stopTimer()
        recordingURLForStep = nil
        // If questions are missing, create a single free-text step so the UI always advances.
        let qs = store.questions.isEmpty ? [Question(prompt: "What’s on your mind? Say or type anything.")] : store.questions
        store.currentAnswers = qs.map {
            Answer(questionPrompt: $0.prompt, audioFileName: nil, videoFileName: nil, transcript: "")
        }
        stepIndex = 0
    }

    private func cancelSession() {
        guard !isFinishing else { return }
        transcriptFocused = false
        stopIfRecording()
        stopTimer()
        recordingURLForStep = nil
        withAnimation { store.currentAnswers.removeAll() }
        stepIndex = 0
    }

    private func goNext() {
        guard !isFinishing else { return }
        transcriptFocused = false
        stopIfRecording()
        guard !store.currentAnswers.isEmpty else { return }

        if stepIndex < store.questions.count - 1 {
            stepIndex += 1
            recordingURLForStep = nil
            return
        }
        isFinishing = true
        store.completeSession()

        // up to 3 images for slideshow (may be 0)
        let images = store.favorites.filenames.filter { $0.isImageFilename }
        slideshowPicks = Array(images.prefix(3))

        stepIndex = 0
        withAnimation { store.currentAnswers.removeAll() }
        DispatchQueue.main.async {
            showSlideshow = true
            isFinishing = false
        }
    }

    // MARK: Audio
    private var isRecording: Bool { recorder.isRecording() }
    private var timerText: String {
        let s = Int(elapsed); return String(format: "%02d:%02d", s/60, s%60)
    }
    private func startStopTapped() { isRecording ? stopIfRecording() : startWithPermission() }
    private func startWithPermission() {
        recorder.ensurePermissionThen { granted in
            guard granted else { showMicDenied = true; return }
            do {
                let url = try recorder.startRecording()
                recordingURLForStep = url
                elapsed = 0; timerOn = true
            } catch {
                recordErrorMessage = error.localizedDescription
                showRecordError = true
            }
        }
    }
    private func stopIfRecording() {
        guard isRecording else { return }
        if let url = recorder.stopRecording() {
            timerOn = false
            recordingURLForStep = url
            guard stepIndex >= 0 && stepIndex < store.currentAnswers.count else { return }
            store.currentAnswers[stepIndex].audioFileName = url.lastPathComponent
            Task {
                do {
                    let t = transcriber ?? { let x = SpeechTranscriber(); transcriber = x; return x }()
                    let text = try await t.transcribeFile(at: url)
                    guard stepIndex >= 0 && stepIndex < store.currentAnswers.count else { return }
                    let existing = store.currentAnswers[stepIndex].transcript
                    store.currentAnswers[stepIndex].transcript =
                        existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : existing + "\n" + text
                } catch { }
            }
        }
    }
    private func play(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay(); p.play()
            audioPlayer = p
        } catch { }
    }
    private func stopTimer() { timerOn = false; elapsed = 0 }
}

