# House

A native SwiftUI blackjack practice table built by Adam Roney. Explore configurable table rules and Hi-Lo counting with a simulated bankroll. **No real-money wagers, deposits, or purchases.**

## Run

1. Open `House.xcodeproj` in Xcode (iOS deployment target: 18.2).
2. Select the **House** scheme and an installed iPhone simulator.
3. Run with ⌘R. No packages, API keys, or backend setup are needed.
4. Choose a chip bet, deal, and use the legal actions shown for the active hand. Settings are available between rounds.

Run tests with ⌘U, or replace the destination name with an installed simulator:

```sh
xcodebuild -project House.xcodeproj -scheme House \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## What is implemented

- A scrollable, adaptive practice table with dealer hole-card reveal, split-hand display, action controls, round results, and optional running/true count.
- Soft-ace scoring, naturals, busts, doubles, splits, surrender, and configurable dealer soft-17 behavior.
- Rule enforcement in the engine, not just disabled buttons. Dealer blackjack resolves before player actions; split 21 is not a natural.
- Hi-Lo counts only exposed cards. The shoe is replenished between rounds at the cut point, and an exhausted shoe cannot hang the dealer loop.
- Saved practice bankroll, bet, counting preference, and table rules using local UserDefaults. No analytics or network requests.
- Deterministic injected shoes and regression tests covering payouts, dealer behavior, counting, illegal actions, and side-wager handling.
- UI regression coverage for opening/dismissing settings and playing consecutive hands.

## Architecture

| Component | Responsibility |
| --- | --- |
| `GameEngine` | Main-actor observable round state, legal actions, settlement, and sequencing |
| `Hand`, `Card`, `Shoe` | Card identity, hand totals, deterministic draw order, and shoe accounting |
| `BlackjackRules` | Configurable table policy and payout values |
| `GameViewModel` | Local preferences and view-facing state |
| `HouseApp` / `TableView` | App entry and practice-table composition |
| `Views/` | Reusable cards, dealer reveal, and settings |

The deal and animated-deal APIs share one path so game rules do not diverge between tests and the UI. Tests can disable animation delays without changing settlement logic.

## Deliberate limits

This is a portfolio/practice app, not a casino product or a strategy recommendation system. The main screen currently offers one initial betting spot; splits create additional hands. There is no insurance, multiplayer, real-money play, or cloud synchronization. Chips are integers, so fractional payouts round down; the main UI uses multiples of 10 to avoid fractional ordinary blackjack payouts.

The engine retains an experimental **combined** side wager that can award both Perfect Pairs and 21+3 bonuses and returns the stake once if either wins. It is not a standard two-wager casino implementation and is not exposed as a wager control on the main screen. Tests document this behavior explicitly.

There is no packaged app icon yet. Simulator verification is separate from App Store distribution, signing, physical-device QA, and accessibility certification.

## Portfolio discussion

Useful topics to demonstrate with the code: state-machine boundaries, separating view availability from engine authorization, deterministic tests for randomized systems, hidden-information handling, avoiding duplicate async settlement, and documenting product limitations honestly. Improvements here do not imply acceptance by any hiring or evaluation platform.
