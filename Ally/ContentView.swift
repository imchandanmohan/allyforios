import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordFlowView()
                .tabItem {
                    Image(systemName: "record.circle")
                    Text("Record")
                }
                .tint(.pink)

            JournalListView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Journal")
                }
                .tint(.indigo)

            ReflectView()
                .tabItem {
                    Image(systemName: "rectangle.3.offgrid.bubble.left")
                    Text("Reflect")
                }
                .tint(.teal)

            BreatheView()
                .tabItem {
                    Image(systemName: "wind")
                    Text("Breathe")
                }
                .tint(.blue)

            GalleryView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Calm")
                }
                .tint(.purple)
        }
    }
}
