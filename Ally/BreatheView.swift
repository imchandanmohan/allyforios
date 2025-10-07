import SwiftUI
import AVFoundation

struct BreatheView: View {
    private enum Phase: String { case inhale = "Inhale", hold = "Hold", exhale = "Exhale" }

    @State private var phase: Phase = .inhale
    @State private var cycle = 0 // 0...10
    @State private var isRunning = false
    @State private var scale: CGFloat = 0.9
    @State private var timer: Timer?

    let inhaleDur: Double = 4
    let holdDur: Double = 7
    let exhaleDur: Double = 8
    let totalCycles = 10

    var body: some View {
        VStack(spacing: 24) {
            Text("4–7–8 Breathing").font(.title2).bold()

            ZStack {
                Circle().fill(Color.blue.opacity(0.25))
                    .frame(width: 240, height: 240)
                    .scaleEffect(scale)
                Text(phase.rawValue).font(.title3).fontWeight(.semibold)
            }

            Text("Cycle \(min(cycle, totalCycles)) of \(totalCycles)")
                .font(.subheadline).foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button(isRunning ? "Pause" : (cycle == 0 ? "Start" : "Resume")) {
                    isRunning ? stop() : start()
                }
                .buttonStyle(.borderedProminent)
                Button("Reset", role: .destructive) { reset() }.buttonStyle(.bordered)
            }

            Text("Inhale 4s • Hold 7s • Exhale 8s").foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Breathe")
        .onDisappear { stop(); reset() }      // ✅ ensures no background timers
    }

    private func start() { isRunning = true; advance(to: phase) }
    private func stop() { isRunning = false; timer?.invalidate(); timer = nil }
    private func reset() { stop(); cycle = 0; phase = .inhale; scale = 0.9 }

    private func advance(to next: Phase) {
        guard isRunning else { return }
        switch next {
        case .inhale:
            withAnimation(.easeInOut(duration: inhaleDur)) { scale = 1.15 }
            schedule(after: inhaleDur) { phase = .hold; advance(to: .hold) }
        case .hold:
            schedule(after: holdDur) { phase = .exhale; advance(to: .exhale) }
        case .exhale:
            withAnimation(.easeInOut(duration: exhaleDur)) { scale = 0.9 }
            schedule(after: exhaleDur) {
                cycle += 1
                if cycle >= totalCycles { stop() } else { phase = .inhale; advance(to: .inhale) }
            }
        }
    }

    private func schedule(after seconds: Double, _ block: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in block() }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
