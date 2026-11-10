import SwiftUI

@main
struct HouseApp: App {
    var body: some Scene {
        WindowGroup { TableView() }
    }
}

struct TableView: View {
    @State private var vm = GameViewModel()
    @State private var settings = false
    private let felt = Color(red: 0.04, green: 0.19, blue: 0.17)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("PRACTICE BANKROLL").font(.caption).tracking(2)
                            Text("\(vm.engine.bankroll.balance) chips").font(.title.bold()).monospacedDigit()
                        }
                        Spacer()
                        Text("NO REAL MONEY").font(.caption2.bold()).padding(8)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                    VStack(spacing: 12) {
                        Text("DEALER").font(.caption.bold()).tracking(3)
                        if vm.engine.dealer.cards.isEmpty {
                            Text("Your table is ready").foregroundStyle(.white.opacity(0.6)).frame(height: 70)
                        } else {
                            DealerCardsRow(cards: vm.engine.dealer.cards, revealHole: vm.engine.revealDealerHole,
                                           dealerShouldSpread: true, destinationOpacity: { _ in 1 })
                            Text(vm.engine.revealDealerHole ? "Total: \(vm.engine.dealer.total.hard)" : "Hole card hidden")
                                .font(.caption)
                        }
                    }.frame(maxWidth: .infinity).padding(20).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    Text(vm.engine.message).font(.headline).accessibilityIdentifier("roundStatus")
                    ForEach(Array(vm.engine.hands.enumerated()), id: \.element.id) { index, hand in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("HAND \(index + 1)").font(.caption.bold()).tracking(2)
                                Spacer()
                                Text("\(hand.bet) chips").font(.caption)
                            }
                            HStack {
                                CardsView(cards: hand.cards, destinationOpacity: { _ in 1 })
                                Spacer()
                                if !hand.cards.isEmpty {
                                    Text("\(hand.total.hard)").font(.title2.bold())
                                    Text(hand.isSoft ? "soft" : "hard").font(.caption)
                                }
                            }.frame(minHeight: 56)
                            if vm.engine.activeHandIndex == index {
                                ViewThatFits(in: .horizontal) {
                                    actionButtons(index: index)
                                    actionButtons(index: index).controlSize(.small)
                                }
                            }
                        }.padding(18)
                            .background(.white.opacity(vm.engine.activeHandIndex == index ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 18))
                    }
                    if vm.engine.roundOver {
                        VStack(spacing: 14) {
                            Stepper("Bet: \(vm.baseBet) chips", value: $vm.baseBet, in: 10...1000, step: 10)
                            Button {
                                for i in vm.engine.hands.indices { vm.engine.setBet(vm.baseBet, forHand: i) }
                                Task { await vm.engine.dealAnimated() }
                            } label: {
                                Text("Deal hand").font(.headline).frame(maxWidth: .infinity).padding(10)
                            }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                                .accessibilityIdentifier("dealButton")
                        }
                    }
                    if !vm.engine.announcements.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(vm.engine.announcements.enumerated()), id: \.offset) { _, item in Text(item) }
                        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if vm.showCount {
                        HStack {
                            Label("Running: \(vm.engine.counter.running)", systemImage: "number")
                            Spacer()
                            Text("True: \(vm.engine.counter.trueCount, specifier: "%.1f")")
                        }.font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                    }
                    Text("Practice decisions. Explore the rules. Play with chips, never money.")
                        .font(.caption).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
                }.padding(20).frame(maxWidth: 660)
                    .frame(maxWidth: .infinity)
            }.background(felt).foregroundStyle(.white)
                .navigationTitle("House")
#if os(iOS)
                .toolbarColorScheme(.dark, for: .navigationBar)
#endif
                .toolbar {
                    Button("Settings", systemImage: "slider.horizontal.3") { settings = true }
                        .disabled(!vm.engine.roundOver)
                }
                .sheet(isPresented: $settings) { SettingsView(vm: vm) }
                .onChange(of: vm.engine.roundOver) { _, done in if done { vm.persist() } }
        }.tint(.mint)
    }

    private func actionButtons(index: Int) -> some View {
        HStack {
            ForEach(vm.engine.availableActions(for: index), id: \.self) { action in
                Button(action.rawValue.capitalized) {
                    switch action {
                    case .hit: vm.engine.hit()
                    case .stand: vm.engine.stand()
                    case .double: vm.engine.doubleDown()
                    case .split: vm.engine.split()
                    case .surrender: vm.engine.surrender()
                    }
                }.buttonStyle(.bordered).tint(.mint)
            }
        }
    }
}
