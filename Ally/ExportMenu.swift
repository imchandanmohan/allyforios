import SwiftUI
import UniformTypeIdentifiers

// Generic document you can export via the system Files sheet.
struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.data]
    static var writableContentTypes: [UTType] = [.data]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ExportMenu: View {
    @EnvironmentObject var store: JournalStore

    @State private var exporterPresented = false
    @State private var exportDoc: DataDocument?
    @State private var suggestedFilename = "export"
    @State private var exportAlert: (title: String, msg: String)?
    
    var body: some View {
        Menu {
            Button {
                let csv = CSVExporter.makeCSV(from: store.entries)
                exportDoc = DataDocument(data: Data(csv.utf8))
                suggestedFilename = "anxiety-journal.csv"
                exporterPresented = true
            } label: { Label("Export CSV", systemImage: "tablecells") }

            Button {
                let data = JSONExporter.makeJSON(from: store.entries)
                exportDoc = DataDocument(data: data)
                suggestedFilename = "anxiety-journal.json"
                exporterPresented = true
            } label: { Label("Export JSON", systemImage: "curlybraces.square") }

            Button {
                let text = JSONExporter.makeTextSummary(from: store.entries)
                exportDoc = DataDocument(data: Data(text.utf8))
                suggestedFilename = "anxiety-journal.txt"
                exporterPresented = true
            } label: { Label("Export TXT", systemImage: "doc.plaintext") }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .fileExporter(isPresented: $exporterPresented,
                      document: exportDoc,
                      contentType: .data,
                      defaultFilename: suggestedFilename) { result in
            switch result {
            case .success(let url):
                exportAlert = ("Saved", "Exported to: \(url.lastPathComponent)\n(Open the Files app to share or move it.)")
            case .failure(let err):
                exportAlert = ("Export failed", err.localizedDescription)
            }
        }
        .alert(exportAlert?.title ?? "", isPresented: Binding(get: { exportAlert != nil },
                                                             set: { _ in exportAlert = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportAlert?.msg ?? "")
        }
        .disabled(store.entries.isEmpty)
    }
}
