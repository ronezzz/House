//
//  PlayerViews.swift
//  House
//
//  Created by Adam Roney on 8/10/25.
//

import SwiftUI
import Observation

struct PlayerRows: View {
	@Bindable var vm: GameViewModel
	let hands: [Hand]
	var body: some View {
		VStack(spacing: 10) {
			ForEach(Array(hands.enumerated()), id: \.element.id) { index, hand in
				playerRow(index: index, hand: hand)
			}
		}
	}
	
	@ViewBuilder
	private func playerRow(index: Int, hand: Hand) -> some View {
		HStack(spacing: 6) {
			Text("Hand \(index+1)").font(.headline)
			Spacer(minLength: 8)
			cardsView(hand.cards)
			Text("\(hand.total.hard)")
				.font(.subheadline).monospacedDigit()
			Spacer()
			Text("Bet: \(hand.bet)")
				.font(.subheadline)
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
				.background(Capsule().strokeBorder(Color.secondary.opacity(0.3)))
				.overlay(alignment: .topTrailing) {
					if hand.sideBet > 0 {
						Text("＋\(hand.sideBet)")
							.font(.caption2)
							.padding(4)
							.background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
							.offset(y: -18)
					}
				}
			if vm.engine.activeHandIndex == index { activeActions(index) }
		}
		.padding(.vertical, 4)
		.background(
			RoundedRectangle(cornerRadius: 12)
				.fill(vm.engine.activeHandIndex == index ? Color.primary.opacity(0.05) : .clear)
		)
	}
	
	private func cardsView(_ cards: [Card]) -> some View {
		HStack(spacing: -18) {
			ForEach(cards) { card in
				cardGlyph(card)
			}
		}
	}
	
	private func activeActions(_ index: Int) -> some View {
		let allowed = Set(vm.engine.availableActions(for: index))
		let all: [Action] = [.hit, .stand, .double, .split, .surrender]
		return HStack(spacing: 6) {
			ForEach(all, id: \.self) { action in
				Button(action.rawValue.capitalized) { perform(action) }
					.buttonStyle(.bordered)
					.disabled(!allowed.contains(action))
					.opacity(allowed.contains(action) ? 1 : 0.35)
			}
		}
	}
	
	private func perform(_ action: Action) {
		switch action {
			case .hit: vm.engine.hit()
			case .stand: vm.engine.stand()
			case .double: vm.engine.doubleDown()
			case .split: vm.engine.split()
			case .surrender: vm.engine.surrender()
		}
	}
}
