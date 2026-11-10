import Testing
@testable import House

@MainActor
struct HouseTests {
    private func card(_ rank: Rank, _ suit: Suit = .clubs) -> Card { Card(suit: suit, rank: rank) }
    private func game(_ ranks: [Rank], rules: BlackjackRules = .init(), balance: Int = 1000) -> GameEngine {
        let engine = GameEngine(rules: rules, initialBankroll: balance,
                                shoe: Shoe(drawOrder: ranks.map { card($0) }))
        engine.animationsEnabled = false
        return engine
    }
    private func finish(_ engine: GameEngine) async {
        // Actions schedule the dealer on the main actor; invoke its idempotent public flow too.
        await engine.dealerPlayAndResolveAnimated()
        await Task.yield()
    }

    @Test func acesDemoteWithoutLosingSoftness() {
        let soft = Hand(cards: [card(.ace), card(.ace), card(.five)])
        #expect(soft.total.hard == 17)
        #expect(soft.isSoft)
        let hard = Hand(cards: soft.cards + [card(.ten)])
        #expect(hard.total.hard == 17)
        #expect(!hard.isSoft)
    }
    @Test func splitTwentyOneIsNotNatural() {
        #expect(!Hand(cards: [card(.ace), card(.king)], isSplitChild: true).isBlackjack)
    }
    @Test func shoeTracksActualPenetrationAndOrder() {
        var shoe = Shoe(drawOrder: [card(.two), card(.king)])
        #expect(shoe.penetration == 0)
        #expect(shoe.draw()?.rank == .two)
        #expect(shoe.penetration == 0.5)
        #expect(shoe.draw()?.rank == .king)
        #expect(shoe.draw() == nil)
        #expect(shoe.penetration == 1)
        #expect(Shoe(decks: 6).cards.count == 312)
    }
    @Test func dealerNaturalEndsRoundBeforeActions() async {
        let engine = game([.ten, .ace, .nine, .king])
        await engine.deal()
        #expect(engine.roundOver)
        #expect(engine.bankroll.balance == 990)
        #expect(engine.activeHandIndex == nil)
        #expect(engine.revealDealerHole)
        engine.doubleDown()
        #expect(engine.bankroll.balance == 990)
    }
    @Test func simultaneousNaturalsPush() async {
        let engine = game([.ace, .ace, .king, .king])
        await engine.deal()
        #expect(engine.bankroll.balance == 1000)
        #expect(engine.roundOver)
    }
    @Test func playerNaturalPaysThreeToTwo() async {
        let engine = game([.ace, .nine, .king, .seven])
        await engine.deal()
        #expect(engine.bankroll.balance == 1015)
        #expect(engine.dealer.cards.count == 2)
    }
    @Test func hiddenHoleCardIsNotCountedUntilReveal() async {
        let engine = game([.two, .ten, .three, .six, .two])
        await engine.deal()
        #expect(engine.counter.running == 1)
        engine.stand()
        await finish(engine)
        #expect(engine.counter.running == 3)
        let balance = engine.bankroll.balance
        await finish(engine)
        #expect(engine.counter.running == 3)
        #expect(engine.bankroll.balance == balance)
    }
    @Test func illegalDoubleCannotBypassRules() async {
        var rules = BlackjackRules(); rules.doubleAllowed = false
        let engine = game([.five, .ten, .six, .seven], rules: rules)
        await engine.deal()
        engine.doubleDown()
        #expect(engine.bankroll.balance == 990)
        #expect(engine.hands[0].cards.count == 2)
        #expect(!engine.availableActions(for: 0).contains(.double))
    }
    @Test func insufficientBankrollLeavesRoundUntouched() async {
        let engine = game([.five, .ten, .six, .seven], balance: 5)
        await engine.deal()
        #expect(engine.roundOver)
        #expect(engine.bankroll.balance == 5)
        #expect(engine.shoe.cards.count == 4)
    }
    @Test func doubleAfterSplitRestrictionIsEnforced() async {
        var rules = BlackjackRules(); rules.doubleAfterSplit = false
        let engine = game([.eight, .ten, .eight, .seven, .three, .two], rules: rules)
        await engine.deal(); engine.split()
        #expect(engine.hands.count == 2)
        #expect(!engine.availableActions(for: 0).contains(.double))
        engine.doubleDown()
        #expect(engine.bankroll.balance == 980)
    }
    @Test func sideBetUsesPokerRanksAndReturnsStakeOnce() async {
        let engine = game([.queen, .ace, .king, .seven])
        engine.setBet(10, sideBet: 2)
        await engine.deal()
        // Q-K-A of clubs is a straight flush: 80 profit + 2 stake, not a pair/trips.
        #expect(engine.bankroll.balance == 1070)
        #expect(engine.hands[0].sideBet == 0)
    }
    @Test func sideBetSettlesBeforeSplitAndIsNotDuplicated() async {
        let engine = game([.eight, .ten, .eight, .seven, .two, .three])
        engine.setBet(10, sideBet: 2)
        await engine.deal()
        // Suited pair (25:1) plus flush (5:1), combined wager returns stake once.
        #expect(engine.bankroll.balance == 1050)
        engine.split()
        #expect(engine.bankroll.balance == 1040)
        #expect(engine.hands.allSatisfy { $0.sideBet == 0 })
    }
    @Test func exhaustedDealerShoeTerminates() async {
        let engine = game([.ten, .two, .eight, .three])
        await engine.deal(); engine.stand(); await finish(engine)
        #expect(engine.roundOver)
        #expect(engine.bankroll.balance == 1010)
    }
    @Test func softSeventeenRuleControlsDealerDraw() async {
        var rules = BlackjackRules(); rules.hitSoft17 = false
        let stand = game([.ten, .ace, .eight, .six, .four], rules: rules)
        await stand.deal(); stand.stand(); await finish(stand)
        #expect(stand.dealer.cards.count == 2)
        #expect(stand.bankroll.balance == 1010)
        rules.hitSoft17 = true
        let hit = game([.ten, .ace, .eight, .six, .four], rules: rules)
        await hit.deal(); hit.stand(); await finish(hit)
        #expect(hit.dealer.cards.count == 3)
        #expect(hit.bankroll.balance == 990)
    }
    @Test func tableCannotResetOrReshuffleMidRound() async {
        let engine = game([.ten, .nine, .eight, .seven, .two])
        await engine.deal()
        let remaining = engine.shoe.cards.count
        engine.newShoe(); engine.resetTable()
        #expect(!engine.roundOver)
        #expect(engine.shoe.cards.count == remaining)
        #expect(engine.hands[0].cards.count == 2)
    }
    @Test func doubledBetResetsOnNextRound() async {
        let engine = game([.five, .ten, .six, .seven, .ten])
        await engine.deal(); engine.doubleDown(); await finish(engine)
        #expect(engine.hands[0].bet == 20)
        await engine.deal()
        #expect(engine.hands[0].bet == 10)
    }
    @Test func splitAcesCannotResplitWhenDisabled() async {
        var rules = BlackjackRules(); rules.hitSplitAces = true; rules.resplitAces = false
        let engine = game([.ace, .ten, .ace, .seven, .ace, .two], rules: rules)
        await engine.deal(); engine.split()
        #expect(!engine.availableActions(for: 0).contains(.split))
        engine.split()
        #expect(engine.hands.count == 2)
    }
    @Test func invalidBetIndexDoesNotCrashOrCreateHands() {
        let engine = game([.five, .ten, .six, .seven])
        engine.setBet(10, forHand: -1)
        engine.setBet(10, forHand: 99)
        #expect(engine.hands.count == 1)
    }

}
