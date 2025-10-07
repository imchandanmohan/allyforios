import Foundation

struct JSONExporter {
    static func makeJSON(from entries: [Entry]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(entries)) ?? Data()
    }

    static func makeTextSummary(from entries: [Entry]) -> String {
        var s = ""
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        for e in entries {
            s += "Entry – \(df.string(from: e.timestamp))\n"
            for a in e.answers {
                s += "• \(a.questionPrompt)\n  \(a.transcript)\n"
            }
            if !e.copingPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                s += "Coping Plan: \(e.copingPlan)\n"
            }
            s += "\n"
        }
        return s
    }
}
