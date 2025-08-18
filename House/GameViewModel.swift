//
//  GameViewModel.swift
//  House
//
//  Created by Adam Roney on 8/8/25.
//


import SwiftUI
import Observation

@Observable
@MainActor
final class GameViewModel {
    var engine: GameEngine

    // UI Controls
    var baseBet: Int = 10
    var sideBet: Int = 0
    var showCount: Bool = true

    init() {
        // Load user prefs if any
        let savedBankroll = UserDefaults.standard.integer(forKey: "bankroll")
        let savedBet = UserDefaults.standard.integer(forKey: "baseBet")
        let savedShowCount = UserDefaults.standard.object(forKey: "showCount") as? Bool

        var rules = BlackjackRules()
        if let payout = UserDefaults.standard.string(forKey: "bjPayout"),
           payout == "6:5" {
            rules.blackjackPayout = .init(num: 6, den: 5)
        }

        engine = GameEngine(
            rules: rules,
            initialBankroll: savedBankroll > 0 ? savedBankroll : 1000
        )
        baseBet = max(savedBet, 10)
        showCount = savedShowCount ?? true
    }

    func persist() {
        UserDefaults.standard.set(engine.bankroll.balance, forKey: "bankroll")
        UserDefaults.standard.set(baseBet, forKey: "baseBet")
        let tag = "\(engine.rules.blackjackPayout.num):\(engine.rules.blackjackPayout.den)"
        UserDefaults.standard.set(tag, forKey: "bjPayout")
        UserDefaults.standard.set(showCount, forKey: "showCount")
    }
}
