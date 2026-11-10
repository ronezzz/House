//
//  SettingsView.swift
//  House
//
//  Created by Adam Roney on 8/10/25.
//

import SwiftUI

struct SettingsView: View {
	@Environment(\.dismiss) private var dismiss
	@State var vm: GameViewModel
	
	var body: some View {
		NavigationStack {
			Form {
				Section("Bankroll & Bets") {
					TextField("Bankroll", value: $vm.engine.bankroll.balance, formatter: NumberFormatter())
					TextField("Base Bet", value: $vm.baseBet, formatter: NumberFormatter())
					Toggle("Show Card Count", isOn: $vm.showCount)
				}
				
				Section("Rules") {
					Stepper("Decks: \(vm.engine.rules.decks)", value: $vm.engine.rules.decks, in: 1...8)
					Toggle("Dealer hits soft 17", isOn: $vm.engine.rules.hitSoft17)
					Toggle("Double allowed", isOn: $vm.engine.rules.doubleAllowed)
					Toggle("Double after split", isOn: $vm.engine.rules.doubleAfterSplit)
					Stepper("Splits allowed: \(vm.engine.rules.splitsAllowed)", value: $vm.engine.rules.splitsAllowed, in: 0...3)
					Toggle("Resplit Aces", isOn: $vm.engine.rules.resplitAces)
					Toggle("Hit split Aces", isOn: $vm.engine.rules.hitSplitAces)
					Toggle("Surrender allowed", isOn: $vm.engine.rules.surrenderAllowed)
				}
				
				Section("Payouts & Side Bets") {
					Picker("Blackjack Payout", selection: Binding(get: {
						"\(vm.engine.rules.blackjackPayout.num):\(vm.engine.rules.blackjackPayout.den)"
					}, set: { tag in
						if tag == "6:5" { vm.engine.rules.blackjackPayout = .init(num: 6, den: 5) }
						else { vm.engine.rules.blackjackPayout = .init(num: 3, den: 2) }
					})) {
						Text("3:2").tag("3:2"); Text("6:5").tag("6:5")
					}
					Toggle("Enable Side Bets", isOn: $vm.engine.rules.allowSideBets)
					Stepper("Side Bet Min: \(vm.engine.rules.sideBetMinimum)", value: $vm.engine.rules.sideBetMinimum, in: 0...1_000)
					Stepper("Side Bet Max: \(vm.engine.rules.sideBetMaximum)", value: $vm.engine.rules.sideBetMaximum, in: 0...10_000)
				}
				
				Section {
					Button("Save Settings") {
						save()
						dismiss()
					}
					Button("Reset Table") { vm.engine.resetTable() }
					Button("New Shoe") { vm.engine.newShoe() }
				}
			}
			.navigationTitle("Settings")
            .onChange(of: vm.engine.rules.decks) { _, _ in vm.engine.newShoe() }
            .onDisappear { save() }
			.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { save(); dismiss() } } }
		}
#if os(macOS)
		.frame(minWidth: 500, minHeight: 600)
#endif
	}
	
    private func save() {
        vm.baseBet = min(1000, max(10, vm.baseBet / 10 * 10))
        vm.engine.bankroll.balance = max(0, vm.engine.bankroll.balance)
        vm.persist()
    }

	var rulesPanel: some View {
		DisclosureGroup("Rules") {
			VStack(alignment: .leading, spacing: 8) {
				Stepper("Decks: \(vm.engine.rules.decks)", value: $vm.engine.rules.decks, in: 1...8)
				Picker("Blackjack Payout", selection: Binding(get: {
					"\(vm.engine.rules.blackjackPayout.num):\(vm.engine.rules.blackjackPayout.den)"
				}, set: { tag in
					if tag == "6:5" {
						vm.engine.rules.blackjackPayout = .init(num: 6, den: 5)
					} else {
						vm.engine.rules.blackjackPayout = .init(num: 3, den: 2)
					}
				})) {
					Text("3:2").tag("3:2"); Text("6:5").tag("6:5")
				}.pickerStyle(.segmented)
				Toggle("Dealer hits soft 17", isOn: $vm.engine.rules.hitSoft17)
				Toggle("Double allowed", isOn: $vm.engine.rules.doubleAllowed)
				Toggle("Double after split", isOn: $vm.engine.rules.doubleAfterSplit)
				Stepper("Splits allowed: \(vm.engine.rules.splitsAllowed)", value: $vm.engine.rules.splitsAllowed, in: 0...10)
					.disabled(vm.engine.rules.noSplitLimit)
				Toggle("No split limit", isOn: $vm.engine.rules.noSplitLimit)
				Toggle("Resplit Aces", isOn: $vm.engine.rules.resplitAces)
				Toggle("Hit split Aces", isOn: $vm.engine.rules.hitSplitAces)
				Toggle("Surrender allowed", isOn: $vm.engine.rules.surrenderAllowed)
				Toggle("Side bets enabled", isOn: $vm.engine.rules.allowSideBets)
			}
			.font(.caption)
		}
		.tint(Color.primary)
	}
}
