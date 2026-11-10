//
//  Hand.swift
//  House
//
//  Created by Adam Roney on 8/8/25.
//

import Foundation
import Observation

enum HandState: String, Codable, Equatable {
	case playing, stood, busted, blackjack, doubled, surrendered, resolved
}

enum Outcome: Equatable { case win(Double), push, lose(Double) }

enum Action: String { case hit, stand, double, split, surrender }

struct Hand: Identifiable, Codable, Hashable {
	var id = UUID()
	var cards: [Card] = []
	var bet: Int = 10
	var sideBet: Int = 0
	var state: HandState = .playing
	var isSplitChild: Bool = false
	
	var seat: Int = 0              // which seat this hand belongs to
	var groupID: UUID = UUID()     // split group identifier
	
	var isPair: Bool { cards.count == 2 && cards[0].faceValue() == cards[1].faceValue() }
	var isSoft: Bool { total.soft }
	
	var total: (hard: Int, soft: Bool) {
		var sum = 0
		var aces = 0
		for c in cards {
			if c.rank == .ace { aces += 1; sum += 11 } else {
				sum += c.faceValue()
			}
		}
		while sum > 21 && aces > 0 { sum -= 10; aces -= 1 } // demote Ace from 11 to 1
		let soft = cards.contains { $0.rank == .ace } && sum <= 21 && aces > 0
		return (sum, soft)
	}
	
	var isBlackjack: Bool { !isSplitChild && cards.count == 2 && total.hard == 21 }
	var isBusted: Bool { total.hard > 21 }
}

// MARK: - Card Counting (Hi-Lo)
@Observable
final class Counter {
	var running: Int = 0
	var trueCount: Double = 0
	
	func reset() {
		running = 0
		trueCount = 0
	}
	
	func apply(card: Card, decksRemaining: Double) {
		// Hi-Lo: 2–6 = +1, 7–9 = 0, 10–A = -1
		let v = card.faceValue()
		if (2...6).contains(v) { running += 1 }
		else if v == 10 || card.rank == .ace { running -= 1 }
		// Update true count (avoid div by 0)
		trueCount = decksRemaining > 0 ? Double(running) / decksRemaining : Double(running)
	}
}
