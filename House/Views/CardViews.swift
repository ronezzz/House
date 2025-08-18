//
//  CardViews.swift
//  House
//
//  Created by Adam Roney on 8/10/25.
//

import SwiftUI

struct CardsView: View {
	let cards: [Card]
	let destinationOpacity: (UUID) -> CGFloat
	
	var body: some View {
		HStack(spacing: -18) {
			ForEach(cards) { card in
				let alpha = destinationOpacity(card.id)
				cardGlyph(card)
					.opacity(alpha)
					.anchorPreference(key: CardFrameKey.self, value: .bounds) { [card.id: $0] }
			}
		}
		.animation(.spring(response: 1.0, dampingFraction: 0.85), value: cards.count)
	}
}

/// 3D flip between a back and front
struct FlipCard<Front: View, Back: View>: View {
	var isFlipped: Bool
	var front: Front
	var back: Back
	var body: some View {
		ZStack {
			back
				.opacity(isFlipped ? 0 : 1)
				.rotation3DEffect(.degrees(isFlipped ? 90 : 0), axis: (x: 0, y: 1, z: 0))
			front
				.opacity(isFlipped ? 1 : 0)
				.rotation3DEffect(.degrees(isFlipped ? 0 : -90), axis: (x: 0, y: 1, z: 0))
		}
		.animation(.easeInOut(duration: 1.2), value: isFlipped)
	}
}

public func cardGlyph(_ card: Card) -> some View {
	let suit: String = {
		switch card.suit {
			case .clubs: return "♣︎"
			case .diamonds: return "♦︎"
			case .hearts: return "♥︎"
			case .spades: return "♠︎"
		}
	}()
	let isRed = card.suit == .hearts || card.suit == .diamonds
	return VStack(spacing: 2) {
		Text(card.rank.label)
			.font(.system(size: 14, weight: .semibold, design: .rounded))
		Text(suit).font(.system(size: 12))
	}
	.foregroundStyle(isRed ? .red : .black)
	.frame(width: 40, height: 56)
	.background(RoundedRectangle(cornerRadius: 8).fill(.white))
	.overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.15)))
	.shadow(radius: 0.5)
	.rotationEffect(.degrees(isRed ? 0.8 : 0))
	.scaleEffect(1.0)
	.contentTransition(.interpolate)
}

public func cardBack() -> some View {
	RoundedRectangle(cornerRadius: 8)
		.fill(Color.white)
		.overlay(
			RoundedRectangle(cornerRadius: 8)
				.stroke(Color.black.opacity(0.10), lineWidth: 1)
		)
		.frame(width: 40, height: 56)
}

