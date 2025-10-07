import SwiftUI

@main
struct LetmecheckApp: App {
    @StateObject private var store = JournalStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
