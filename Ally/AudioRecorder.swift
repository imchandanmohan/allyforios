import Foundation
import AVFoundation

final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    @Published var micPermission: AVAudioSession.RecordPermission = .undetermined

    override init() {
        super.init()
        micPermission = AVAudioSession.sharedInstance().recordPermission
    }

    func ensurePermissionThen(_ action: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            DispatchQueue.main.async { action(true) }
        case .denied:
            DispatchQueue.main.async { action(false) }
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async { action(granted) }
            }
        @unknown default:
            DispatchQueue.main.async { action(false) }
        }
    }

    @discardableResult
    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .spokenAudio,
                                options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let fileURL = Self.newRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let rec = try AVAudioRecorder(url: fileURL, settings: settings)
        rec.delegate = self
        rec.isMeteringEnabled = true

        guard rec.record() else {
            throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
        }
        self.recorder = rec
        return fileURL
    }

    func stopRecording() -> URL? {
        guard let rec = recorder else { return nil }
        rec.stop()
        let url = rec.url
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return url
    }

    func isRecording() -> Bool { recorder?.isRecording ?? false }

    private static func newRecordingURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("rec-\(UUID().uuidString).m4a")
    }
}
