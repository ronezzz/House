//
//  Rules.swift
//  House
//
//  Created by Adam Roney on 8/8/25.
//

import Foundation

struct BlackjackPayout: Codable, Equatable { var num: Int; var den: Int }

struct SideBetPayouts: Codable, Equatable {
    var perfectPairs: Double = 25.0 // suited pair
    var coloredPair: Double = 12.0
    var mixedPair: Double = 6.0
    var twentyOnePlusThreeStraightFlush: Double = 40.0
    var twentyOnePlusThreeTrips: Double = 30.0
    var twentyOnePlusThreeStraight: Double = 10.0
    var twentyOnePlusThreeFlush: Double = 5.0
}

struct BlackjackRules: Codable, Equatable {
    var decks: Int = 6
    var hitSoft17: Bool = true
    var blackjackPayout: BlackjackPayout = .init(num: 3, den: 2) // 3:2 or 6:5 etc

    var doubleAllowed: Bool = true
    var doubleOn: Set<Int> = [] // empty == any two cards; else totals allowed
    var doubleAfterSplit: Bool = true

    var splitsAllowed: Int = 3 // times you may split (resulting hands = splitsAllowed+1)
    var noSplitLimit: Bool = false
    var resplitAces: Bool = false
    var hitSplitAces: Bool = false
    
    var surrenderAllowed: Bool = false // late surrender

    var allowSideBets: Bool = true
    var sideBetMinimum: Int = 0
    var sideBetMaximum: Int = 100
    var sideBetPayouts: SideBetPayouts = .init()
}
