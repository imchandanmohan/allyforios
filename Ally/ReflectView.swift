import SwiftUI

struct ReflectView: View {
    @EnvironmentObject var store: JournalStore
    @State private var page = 0

    private var cards: [ReflectCard] {
        store.reflectCards.isEmpty ? ReflectView.seedQuotes : store.reflectCards
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                Text("Reflect")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                TabView(selection: $page) {
                    ForEach(Array(cards.enumerated()), id: \.1.id) { idx, card in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(card.title)
                                .font(.title3.weight(.semibold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)

                            ScrollView {
                                Text(card.body)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity,
                               alignment: .topLeading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                        .padding(.horizontal)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: geo.size.height * 0.75) // bigger
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .navigationTitle("Reflect")
        .onAppear {
            if store.reflectCards.isEmpty {
                store.reflectCards = ReflectView.seedQuotes
            }
        }
    }
}

extension ReflectView {
    static let seedQuotes: [ReflectCard] = [
        ReflectCard(title: "Name the feeling",
                    body: "Write 3 words for what you feel right now. Then write one kind response you’d tell a friend."),
        ReflectCard(title: "Trigger check",
                    body: "What situation, place, person, or thought happened just before the feeling? Note time and place."),
        ReflectCard(title: "Body scan",
                    body: "Where do you feel it in your body? Describe the sensation and intensity (1–10)."),
        ReflectCard(title: "Reframe",
                    body: "Write the anxious thought. Now write a balanced thought that is true and supportive."),
        ReflectCard(title: "Gratitude ×3",
                    body: "List three small wins from today, no matter how small."),
        ReflectCard(title: "Evidence for/against",
                    body: "What facts support your fear? What facts don’t? What would a fair judge say?"),
        ReflectCard(title: "One tiny action",
                    body: "What’s a 2-minute step you can do now that your future self will thank you for?"),
        ReflectCard(title: "Values check",
                    body: "What matters to you here? What action moves you 1% closer to that value?"),
        ReflectCard(title: "Zoom out",
                    body: "Will this matter in 5 days, 5 months, or 5 years? What changes if you zoom out?"),
        ReflectCard(title: "Self-compassion",
                    body: "Finish: “It’s understandable that I feel __ because __. One thing I can try is __.”"),
    ]
}
