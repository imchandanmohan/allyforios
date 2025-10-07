import Foundation

struct CSVExporter {
    static func makeCSV(from entries: [Entry]) -> String {
        guard !entries.isEmpty else { return "No data" }

        let maxAnswers = entries.map { $0.answers.count }.max() ?? 0
        var headers = ["Timestamp"]
        for i in 0..<maxAnswers {
            headers += ["Q\(i+1)_Question", "Q\(i+1)_Text", "Q\(i+1)_AudioFile"]
        }
        headers.append("CopingPlan")
        let headerLine = headers.joined(separator: ",")

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines = [headerLine]
        for entry in entries {
            var cols: [String] = [df.string(from: entry.timestamp)]
            for i in 0..<maxAnswers {
                if i < entry.answers.count {
                    let a = entry.answers[i]
                    cols.append(csvEscape(a.questionPrompt))
                    cols.append(csvEscape(a.transcript))
                    cols.append(csvEscape(a.audioFileName ?? ""))
                } else { cols += ["", "", ""] }
            }
            cols.append(csvEscape(entry.copingPlan))
            lines.append(cols.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            let doubled = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return s
    }

    static func writeToTemp(_ data: Data, fileName: String) throws -> URL {
        let temp = FileManager.default.temporaryDirectory
        let url = temp.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func writeCSVToTemp(_ csv: String) throws -> URL {
        try writeToTemp(Data(csv.utf8), fileName: "anxiety-journal.csv")
    }
}
