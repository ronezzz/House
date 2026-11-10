//
//  Models.swift
//  House
//
//  Created by Adam Roney on 8/8/25.
//

import SwiftUI

enum Suit: String, CaseIterable, Codable { case clubs, diamonds, hearts, spades }

enum Rank: Int, CaseIterable, Codable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen = 12, king = 13
    case ace = 14
    
    var label: String {
        switch self {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return String(rawValue) // 2...10
        }
    }
}

public struct Card: Identifiable, Hashable, Codable {
    let suit: Suit
    let rank: Rank
	public var id = UUID()
    
    func faceValue() -> Int {
        switch self.rank {
        case .ace: return 11
        case .jack, .queen, .king: return 10
        default: return self.rank.rawValue
        }
    }
}

struct Shoe: Codable {
    private(set) var cards: [Card] = []
    private(set) var initialCardCount: Int = 0
    
    init(decks: Int, shuffleTimes: Int = 6) {
        var temp: [Card] = []
        for _ in 0..<max(1, decks) {
            for s in Suit.allCases {
                // Standard 52-card mapping: four tens + J/Q/K as 10
                temp.append(contentsOf: [
                    Card(suit: s, rank: .ace),
                    Card(suit: s, rank: .two),
                    Card(suit: s, rank: .three),
                    Card(suit: s, rank: .four),
                    Card(suit: s, rank: .five),
                    Card(suit: s, rank: .six),
                    Card(suit: s, rank: .seven),
                    Card(suit: s, rank: .eight),
                    Card(suit: s, rank: .nine),
                    Card(suit: s, rank: Rank(rawValue: 10)!), // 10
                    Card(suit: s, rank: .jack),
                    Card(suit: s, rank: .queen),
                    Card(suit: s, rank: .king)
                ])
            }
        }
        // Fisher-Yates multiple shuffles
        cards = temp
        initialCardCount = cards.count
        for _ in 0..<max(0, shuffleTimes) { cards.shuffle() }
    }
    
    /// Cards are consumed in the supplied order, for deterministic scenarios and tests.
    init(drawOrder: [Card]) {
        cards = Array(drawOrder.reversed())
        initialCardCount = cards.count
    }

    mutating func draw() -> Card? { cards.popLast() }
    var penetration: Double { 1.0 - Double(cards.count)/Double(max(initialCardCount, 1)) }
}

// MARK: - Bankroll

@Observable
final class Bankroll {
    var balance: Int
    init(balance: Int) { self.balance = balance }
    
    func credit(_ amount: Int) { balance += amount }
    func debit(_ amount: Int) { balance -= amount }
}
