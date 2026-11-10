//
//  DealerCardsRow.swift
//  House
//
//  Created by Adam Roney on 8/10/25.
//

import SwiftUI

public struct DealerCardsRow: View {
	let cards: [Card]
	let revealHole: Bool
	let dealerShouldSpread: Bool
	let destinationOpacity: (UUID) -> CGFloat
	
	public init(cards: [Card], revealHole: Bool, dealerShouldSpread: Bool, destinationOpacity: @escaping (UUID) -> CGFloat) {
		self.cards = cards; self.revealHole = revealHole; self.dealerShouldSpread = dealerShouldSpread; self.destinationOpacity = destinationOpacity
	}
	
	public var body: some View {
		let holeId: UUID? = cards.dropFirst().first?.id
		let shouldStack = !dealerShouldSpread || cards.count <= 2
		let baseSpacing: CGFloat = 8
		
		HStack(spacing: baseSpacing) {
			ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
				let alpha = destinationOpacity(card.id)
				let content: AnyView = {
					if card.id == holeId {
						return AnyView(
							FlipCard(
								isFlipped: revealHole,
								front:
									cardGlyph(card)
									.opacity(alpha)
									.anchorPreference(key: CardFrameKey.self, value: .bounds) { [card.id: $0] },
								back:
									cardBack()
									.anchorPreference(key: CardFrameKey.self, value: .bounds) { [card.id: $0] }
							)
						)
					} else {
						return AnyView(
							cardGlyph(card)
								.opacity(alpha)
								.anchorPreference(key: CardFrameKey.self, value: .bounds) { [card.id: $0] }
						)
					}
				}()
				
				content
					.offset(x: overlapOffset(idx, shouldStack: shouldStack))            // create stacked look before dealer draws
					.zIndex(Double(idx))                      // ensure rightmost card appears on top
			}
		}
		.animation(.spring(response: 0.9, dampingFraction: 0.85), value: dealerShouldSpread)
		.animation(.spring(response: 0.9, dampingFraction: 0.85), value: cards.count)
	}
	
	func overlapOffset(_ index: Int, shouldStack: Bool) -> CGFloat {
		shouldStack ? CGFloat(-26 * index) : 0
	}
}
