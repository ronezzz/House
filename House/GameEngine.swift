//
//  GameEngine.swift
//  House
//
//  Created by Adam Roney on 8/8/25.
//


import SwiftUI
import Observation

@Observable
@MainActor
final class GameEngine {
	var rules: BlackjackRules
	var bankroll: Bankroll
	var counter: Counter = Counter()

	// Table State
	var shoe: Shoe
	var dealer: Hand = Hand(cards: [])
	var hands: [Hand] = [Hand(cards: [])]
	var activeHandIndex: Int?

	// For animation/UI
	var message: String = "Place your bets"
	var roundOver: Bool = true
	/// Dealer hole card visibility (false while players act; true when dealer starts)
	var revealDealerHole: Bool = false
	/// Round announcements (per-hand outcomes, payouts)
	var announcements: [String] = []

	/// UI hint: when dealer begins, spread cards before flipping the hole card
	var dealerShouldSpread: Bool = false

	/// Optional hook for the UI to let the engine await the end of a shoe→hand slide
	/// The UI should call the continuation once the matchedGeometryEffect slide completes
	var awaitUICardSlide: ((UUID) async -> Void)?

	/// Optional hook for the UI to let the engine await the dealer spread animation
	var awaitUIDealerSpread: (() async -> Void)?
	private var dealerResolving = false
	private var holeCounted = false
    private var originalBets: [UUID: Int] = [:]
	var animationsEnabled = true

	init(rules: BlackjackRules = .init(), initialBankroll: Int = 1000, shoe: Shoe? = nil) {
		self.rules = rules
		self.bankroll = Bankroll(balance: initialBankroll)
		self.shoe = shoe ?? Shoe(decks: rules.decks)
	}

	private var decksRemaining: Double {
		max(0.0, Double(shoe.cards.count) / 52.0)
	}

	// Centralized draw that also updates the Hi-Lo counter
	private func drawCard(visible: Bool = true) -> Card? {
		if let c = shoe.draw() { // mutate shoe, then count
			if visible { counter.apply(card: c, decksRemaining: decksRemaining) }
			return c
		}
		return nil
	}

	// MARK: Betting
	func setBet(_ amount: Int, sideBet: Int = 0, forHand index: Int = 0) {
		guard roundOver, index >= 0, index < 7 else { return }
		if index >= hands.count { hands.append(contentsOf: (hands.count...index).map { _ in Hand() }) }
		originalBets[hands[index].groupID] = nil
        hands[index].bet = max(1, amount)
		hands[index].sideBet = rules.allowSideBets && sideBet > 0 ? min(max(sideBet, rules.sideBetMinimum), max(0, rules.sideBetMaximum)) : 0
	}

	func addHand() { guard roundOver, hands.count < 7 else { return }; hands.append(Hand(cards: [], bet: hands.first?.bet ?? 10)) }
	func removeLastHand() { guard roundOver, hands.count > 1 else { return }; hands.removeLast() }

	// MARK: Deal
	func deal() async { await startRound(animated: false) }

    private func startRound(animated: Bool) async {
        guard roundOver, !dealerResolving, !hands.isEmpty else { return }
        // Split children collapse back to the original betting spots next round.
        var groups = Set<UUID>()
        hands = hands.filter { groups.insert($0.groupID).inserted }
        for i in hands.indices {
            if let bet = originalBets[hands[i].groupID] { hands[i].bet = bet }
        }
        originalBets.removeAll()
        for i in hands.indices {
            if !rules.allowSideBets { hands[i].sideBet = 0 }
        }
        guard hands.allSatisfy({ $0.bet > 0 && $0.sideBet >= 0 }) else { return }
        let debit = hands.reduce(0) { $0 + $1.bet + $1.sideBet }
        guard bankroll.balance >= debit else { message = "Insufficient bankroll"; return }
        // Replenish between rounds, never secretly replace cards in a live hand.
        if shoe.penetration >= 0.75 || shoe.cards.count < (hands.count + 1) * 2 {
            newShoe()
        }
        bankroll.debit(debit)
        roundOver = false
        activeHandIndex = nil
        dealer = Hand(cards: [])
        dealerShouldSpread = false
        revealDealerHole = false
        holeCounted = false
        announcements.removeAll()
        for i in hands.indices {
            hands[i].cards = []; hands[i].state = .playing
            hands[i].isSplitChild = false; hands[i].groupID = UUID()
            originalBets[hands[i].groupID] = hands[i].bet
        }
        for pass in 0..<2 {
            for i in hands.indices {
                if let card = drawCard() {
                    hands[i].cards.append(card)
                    if animated { await pauseForCard(card.id) }
                }
            }
            if let card = drawCard(visible: pass == 0) {
                dealer.cards.append(card)
                if animated { await pauseForCard(card.id) }
            }
        }
        // Side wagers are settled on the original two cards, before any split.
        for i in hands.indices { paySideBetsIfAny(for: i) }
        resolveNaturalsIfAny()
        if !roundOver {
            activeHandIndex = firstPlayableHandIndex()
            message = statusLine()
        }
    }

    private func revealHole() {
        if !holeCounted, dealer.cards.count > 1 {
            counter.apply(card: dealer.cards[1], decksRemaining: decksRemaining)
            holeCounted = true
        }
        revealDealerHole = true
    }

    private func pauseForCard(_ id: UUID) async {
        guard animationsEnabled else { return }
        if let wait = awaitUICardSlide { await wait(id) }
        else { try? await Task.sleep(nanoseconds: 350_000_000) }
    }

	private func firstPlayableHandIndex() -> Int? {
		hands.firstIndex { $0.state == .playing }
	}

	private func resolveNaturalsIfAny() {
		let dealerBJ = dealer.isBlackjack
		for i in hands.indices {
			if dealerBJ && !hands[i].isBlackjack {
                settle(.lose(Double(hands[i].bet)), handIndex: i)
            } else if hands[i].isBlackjack {
				if dealerBJ {
					// push
					bankroll.credit(hands[i].bet)
					hands[i].state = .resolved
					announcements.append("Hand \(i+1): Push")
				} else {
					// blackjack payout (net win is just the payout)
					let payout = payoutForBlackjack(bet: hands[i].bet)
					bankroll.credit(hands[i].bet + Int(payout))
					hands[i].state = .blackjack
					announcements.append("Hand \(i+1): Blackjack +\(Int(payout))")
				}
			}
		}

		if hands.allSatisfy({ $0.state != .playing }) {
			revealHole()
			resolveOutcomes()
			withAnimation {
				revealDealerHole = true
				roundOver = true
			}
			message = "Round complete"
		}
	}

	private func payoutForBlackjack(bet: Int) -> Double {
		Double(bet) * Double(rules.blackjackPayout.num) / Double(max(1, rules.blackjackPayout.den))
	}

	// MARK: Actions
	func availableActions(for index: Int) -> [Action] {
		guard !roundOver,
			  index == activeHandIndex,
			  hands.indices.contains(index) else { return [] }

		let h = hands[index]
		// Must have initial two cards to act
		guard h.cards.count >= 2,
			  h.state == .playing else { return [] }

		let lockedAces = h.isSplitChild && h.cards.first?.rank == .ace && !rules.hitSplitAces
        var acts: [Action] = lockedAces ? [.stand] : [.hit, .stand]

		if !lockedAces && rules.doubleAllowed && h.cards.count == 2 && bankroll.balance >= h.bet && (!h.isSplitChild || rules.doubleAfterSplit) {
			if rules.doubleOn.isEmpty || rules.doubleOn.contains(h.total.hard) { acts.append(.double) }
		}
		if h.isPair && bankroll.balance >= h.bet && canSplit(handIndex: index) { acts.append(.split) }
		if rules.surrenderAllowed && h.cards.count == 2 && !h.isSplitChild { acts.append(.surrender) }
		return acts
	}

	private func canSplit(handIndex: Int) -> Bool {
		let h = hands[handIndex]
		guard h.isPair else { return false }
        if h.isSplitChild && h.cards[0].rank == .ace && !rules.resplitAces { return false }
		if rules.noSplitLimit { return true }
		// count current hands in this split group
		let groupCount = hands.filter { $0.groupID == h.groupID }.count
		// you may split up to N times => max hands = N + 1
		let maxHands = rules.splitsAllowed + 1
		return groupCount < maxHands
	}

	func hit() { performAction(.hit) }
	func stand() { performAction(.stand) }
	func doubleDown() { performAction(.double) }
	func split() { performAction(.split) }
	func surrender() { performAction(.surrender) }

	private func performAction(_ action: Action) {
		guard let idx = activeHandIndex, hands.indices.contains(idx) else { return }
		var h = hands[idx]
		guard availableActions(for: idx).contains(action) else { return }

		switch action {
			case .hit:
				if let c = drawCard() { h.cards.append(c) }
				if h.isBusted {
					h.state = .busted
					announcements.append("Hand \(idx+1): Bust -\(h.bet)")
					hands[idx] = h
					advanceToNextHandOrDealer()
					break
				}
				hands[idx] = h
			case .stand:
				h.state = .stood
				hands[idx] = h
				advanceToNextHandOrDealer()
			case .double:
				// Requires enough bankroll for an additional bet equal to base bet
				guard bankroll.balance >= h.bet else { message = "Not enough balance to double"; return }
				bankroll.debit(h.bet)
				h.bet *= 2
				if let c = drawCard() { h.cards.append(c) }
				h.state = h.isBusted ? .busted : .doubled
				hands[idx] = h
				advanceToNextHandOrDealer()
			case .split:
				guard canSplit(handIndex: idx) else { return }
				let first = h.cards[0]
				let second = h.cards[1]
				// Need an extra bet for the new hand
				guard bankroll.balance >= h.bet else { message = "Not enough balance to split"; return }
				bankroll.debit(h.bet)

				// Replace current hand with first card + draw
				var left = Hand(cards: [first], bet: h.bet, sideBet: h.sideBet, state: .playing, isSplitChild: true)
				left.seat = h.seat
				left.groupID = h.groupID
				if let c1 = drawCard() { left.cards.append(c1) }

				// Insert new hand with second card + draw (same seat, same group)
				var right = Hand(cards: [second], bet: h.bet, sideBet: h.sideBet, state: .playing, isSplitChild: true)
				right.seat = h.seat
				right.groupID = h.groupID
				if let c2 = drawCard() { right.cards.append(c2) }


				hands[idx] = left
				hands.insert(right, at: idx + 1)

				// Special rules for split aces
				if first.rank == .ace && second.rank == .ace {

					if !rules.hitSplitAces {
						if !canSplit(handIndex: idx) { hands[idx].state = .stood }
                        if !canSplit(handIndex: idx + 1) { hands[idx + 1].state = .stood }
                        if hands[idx].state != .playing { advanceToNextHandOrDealer() }
					}
				}
			case .surrender:
				guard rules.surrenderAllowed && h.cards.count == 2 else { return }
				h.state = .surrendered
				// Return half the bet
				bankroll.credit(h.bet / 2)
				hands[idx] = h
				advanceToNextHandOrDealer()
		}

		message = statusLine()
	}

	private func advanceToNextHandOrDealer() {
		// Move to next active hand
		let next = hands.indices.dropFirst((activeHandIndex ?? -1) + 1).first { hands[$0].state == .playing }
		if let n = next { activeHandIndex = n; message = "Action on Hand \(n+1)"; return }
		// No more player hands to act -> dealer plays
		activeHandIndex = nil
		Task { await self.dealerPlayAndResolveAnimated() }
	}

	private func finishDealerIfNeeded() {
		// If every hand is resolved via naturals or surrender, we may skip, but safe to compute.
		// Dealer draws on hard total < 17; on soft 17 depends on rules.
		while true {
			let total = dealer.total.hard
			if total < 17 { if let c = drawCard() { dealer.cards.append(c) } else { break } ; continue }
			if total == 17 && dealer.total.soft && rules.hitSoft17 { if let c = drawCard() { dealer.cards.append(c) } else { break }; continue }
			break
		}
	}

	private func resolveOutcomes() {
		// Side bets were already settled at the initial deal.

		let dealerTotal = dealer.total.hard
		let dealerBust = dealerTotal > 21
		for i in hands.indices {
			var h = hands[i]
			guard h.state != .resolved && h.state != .blackjack && h.state != .surrendered else { continue }
			if h.isBusted { // already debited
				h.state = .resolved
				hands[i] = h
				continue
			}
			let pt = h.total.hard
			var outcome: Outcome
			if dealerBust {
				outcome = .win(Double(h.bet))
			} else if pt > dealerTotal {
				outcome = .win(Double(h.bet))
			} else if pt == dealerTotal {
				outcome = .push
			} else {
				outcome = .lose(Double(h.bet))
			}
			settle(outcome, handIndex: i)
		}
	}

	private func settle(_ outcome: Outcome, handIndex: Int) {
		switch outcome {
			case .win(let amt):
				bankroll.credit(Int(amt * 2)) // return bet + win
				announcements.append("Hand \(handIndex+1): Win +\(Int(amt))")
			case .push:
				bankroll.credit(hands[handIndex].bet) // return bet only
				announcements.append("Hand \(handIndex+1): Push")
			case .lose:
				announcements.append("Hand \(handIndex+1): Lose -\(hands[handIndex].bet)")
		}
		hands[handIndex].state = .resolved
	}

	// MARK: Side Bets (Perfect Pairs & 21+3 basic variants)
	private func paySideBetsIfAny(for index: Int) {
		guard rules.allowSideBets else { return }
		var h = hands[index]
		let bet = h.sideBet
		guard bet > 0, h.cards.count >= 2, dealer.cards.count >= 1 else { return }
		var credit = 0.0

		// Perfect Pairs (first two player cards only)
		let c1 = h.cards[0], c2 = h.cards[1]
		if c1.rank == c2.rank {
			if c1.suit == c2.suit {
				credit += Double(bet) * rules.sideBetPayouts.perfectPairs
			} else if (c1.suit == .hearts || c1.suit == .diamonds) == (c2.suit == .hearts || c2.suit == .diamonds) {
				credit += Double(bet) * rules.sideBetPayouts.coloredPair
			} else {
				credit += Double(bet) * rules.sideBetPayouts.mixedPair
			}
		}

		// 21+3 (player first two + dealer upcard)
		let up = dealer.cards[0]
		let trio = [c1, c2, up]
		if isStraightFlush(trio) { credit += Double(bet) * rules.sideBetPayouts.twentyOnePlusThreeStraightFlush }
		else if isTrips(trio) { credit += Double(bet) * rules.sideBetPayouts.twentyOnePlusThreeTrips }
		else if isStraight(trio) { credit += Double(bet) * rules.sideBetPayouts.twentyOnePlusThreeStraight }
		else if isFlush(trio) { credit += Double(bet) * rules.sideBetPayouts.twentyOnePlusThreeFlush }

		// This app uses one combined side wager: both bonuses may pay; stake returns once.
        if credit > 0 {
            bankroll.credit(Int(credit) + bet)
            announcements.append("Hand \(index + 1): Side bet +\(Int(credit))")
        }
		// side bet consumed
		h.sideBet = 0
		hands[index] = h
	}

	private func isFlush(_ cards: [Card]) -> Bool { Set(cards.map { $0.suit }).count == 1 }

	private func isTrips(_ cards: [Card]) -> Bool {
		let vals = cards.map({ $0.rank.rawValue })
		return Set(vals).count == 1
	}

	private func isStraight(_ cards: [Card]) -> Bool {
		let vals = cards.map({ $0.rank.rawValue }).sorted()
		// Poker ranks preserve J/Q/K; ace is high (14) or low (1).
		let aLow = vals.map { $0 == 14 ? 1 : $0 }.sorted()
		return isConsecutive(vals) || isConsecutive(aLow)
	}

	private func isStraightFlush(_ cards: [Card]) -> Bool { isFlush(cards) && isStraight(cards) }

	private func isConsecutive(_ arr: [Int]) -> Bool { arr[1] == arr[0] + 1 && arr[2] == arr[1] + 1 }

	// MARK: Helpers
	private func statusLine() -> String {
		if let idx = activeHandIndex { return "Action on Hand \(idx+1)" }
		return roundOver ? "Round complete" : "Dealer acting"
	}

	func newShoe() {
        guard roundOver, !dealerResolving else { return }
		shoe = Shoe(decks: rules.decks)
		dealerShouldSpread = false
		counter.reset()
	}

	func resetTable() {
        guard roundOver, !dealerResolving else { return }
		dealer = Hand(cards: [])
		dealerShouldSpread = false
		hands = [Hand(cards: [])]
		activeHandIndex = nil
		roundOver = true
		message = "Place your bets"
		newShoe()
		revealDealerHole = false
		announcements.removeAll()
	}

	// MARK: Dramatic animated flow
	func dealAnimated() async { await startRound(animated: true) }

	@MainActor
	func dealerPlayAndResolveAnimated() async {
		// No player hands left to act
		guard !roundOver, !dealerResolving, hands.allSatisfy({ $0.state != .playing }) else { return }
        dealerResolving = true
        defer { dealerResolving = false }

		// First: ask UI to spread dealer cards, then wait for UI to finish the spread
		dealerShouldSpread = true
		if !animationsEnabled {
            // Deterministic, delay-free tests.
        } else if let waitSpread = awaitUIDealerSpread {
			await waitSpread()
		} else {
			// Fallback: approximate the spread animation duration
			try? await Task.sleep(nanoseconds: 450_000_000)
		}
		// Now flip the hole card
		withAnimation { revealHole() }
        if animationsEnabled { try? await Task.sleep(nanoseconds: 650_000_000) } // allow flip to complete before hits

		// Draw stepwise with pauses so each card triggers a UI slide
		if hands.contains(where: { $0.state == .stood || $0.state == .doubled }) { await dealerDrawStepwise() }

		resolveOutcomes()
		roundOver = true
		message = "Round complete"
	}

	private func dealerDrawStepwise() async {
		// draw loop honoring S17/H17 with pauses
		while true {
			let total = dealer.total.hard
			let mustHitHard = total < 17
			let mustHitSoft17 = total == 17 && dealer.total.soft && rules.hitSoft17

			guard mustHitHard || mustHitSoft17 else { break }

			if let c = drawCard() {
				dealer.cards.append(c)
				await pauseForCard(c.id)
			} else { break }
		}
	}
}
