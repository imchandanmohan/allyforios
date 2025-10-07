import Foundation
import Speech

enum SpeechAuthState {
    case unknown, authorized, denied, restricted, notDetermined
}

final class SpeechTranscriber: ObservableObject {
    @Published var authState: SpeechAuthState = .unknown

    init() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized: self.authState = .authorized
                case .denied: self.authState = .denied
                case .restricted: self.authState = .restricted
                case .notDetermined: self.authState = .notDetermined
                @unknown default: self.authState = .restricted
                }
            }
        }
    }

    func transcribeFile(at url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer() else {
            throw NSError(domain: "Speech", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recognizer unavailable"])
        }
        guard recognizer.isAvailable else {
            throw NSError(domain: "Speech", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error); return
                }
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
            // Optional timeout safeguard
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { task.cancel() }
        }
    }
}
