# Changelog

All notable changes to Coby's Crest Exchange are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), version numbering follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.3] - 2026-10-06

### Added

- Until your first exchange, the first page shows the whole flow in one line: click a tier, say how many, check the cost on Review, then buy and open the packs.
- Opening a single exchange's packs shows a progress bar ("Opened 1 of 2 packs").
- A tier at its cap shows a green check and the word MAX in a column of its own, with "Held" under the count. MAX still says when the cap usually rises.

### Changed

- Each tier on the first page is now a cap meter: the row fills in the crest's color as you earn toward the cap that limits it ("Season earned: 45/300", "Week earned: 120/300" or "Held: 120/400"), and a fainter band shows crests waiting in unopened packs. Its tooltip lists every cap that applies and what frees it.
- Cap messages tell a cap on what you hold (spend some to make room) from a weekly or season cap (wait for it to rise).
- Receipts show what you received and spent per tier as tiles with each crest's icon, plus any packs left unopened, and say how to open those.
- The "Trade up 30 for 10" lines between tiers are gone (the Get page prices every trade); a locked trade still says why in red.
- "Use every lower tier" is now "Plan from lower tiers", and "Why are trades locked?" is now "Trade requirements": it lists every trade, open or locked, and explains which gear slots hold a locked one back.
- Review explains what comes after Confirm: whether Vaskarn is needed again between steps, and how many packs open in all. A big plan shows fewer step cards at once so nothing runs under Confirm.
- When nothing can be traded up, the Get page points to each route's reason and, when one is available, how to reach a trade down; Max is greyed out when it would give nothing.
- When every route is closed, the Get page says why: locked, not seen at Vaskarn yet, or a pack this version can't buy.
- A plan stopped early is titled "Plan ended" with its goal, not as if the goal was reached.
- Paused at Vaskarn, the page says what Review remaining and Open purchased packs do. Discarding while a purchase is unconfirmed warns that the purchase may still arrive.
- **Settings:** the Cancel button is now **Undo edits**, with the same job: it drops changes you have not applied.
- Many smaller look and wording improvements across the windows.

### Fixed

- The unopened-packs note on the Get page counts the packs its Open packs button opens.
- Several smaller bug fixes.

## [0.0.2] - 2026-10-01

### Added
- Walking back to Vaskarn: you can now stop the addon from turning on the game's Enable Interact Key for you.

### Changed
- Settings redesigned in three pages (Exchange, Interact key, Window) with picture tiles.
- When visiting Vaskarn is its own setting: full window, small tab, or stay closed. Folding the window no longer changes it, and your earlier choice carries over.
- Where it docks: Prefer right, Prefer left, Automatic or Saved position.
- Use every lower tier is picked first when it works for your amount. Trade down is never picked for you.
- Opening packs you already had ends with "Packs opened" and no Spent line.
- Paused away from Vaskarn, the window says to talk to him to buy the rest.
- Copy buttons now say to press Ctrl+C.
- Get page: the routes stay grayed out until you type an amount, and amount boxes take digits only.
- Review shows each crest's icon, its balance after opening, and a tooltip.
- Locked trades list your gear slots in a table, with the item level each one needs.
- Trade labels read the same everywhere ("Trade up 30 for 10"), using the last prices seen when you're away from Vaskarn.
- The Discard this order? confirmation shows the addon's icon.
- `/ce debug` logs more about each purchase and pack opening.

### Fixed
- A finished plan's receipt totals every step, not just the last.
- "End exchange here" is grayed out while a pack is opening.
- The Get page's unopened-packs note and a plan's next-step message no longer get cut off.
- "Wait for the last pack to finish opening" no longer lingers after the pack is done.
- Before you spend no longer leaves an empty gap under Your upgrade tracks.
- A plan stops before buying a step whose price changed; discard it and plan again.
- An unrelated game error during a purchase is no longer read as Vaskarn refusing it.
- A plan review interrupted by combat or closing Vaskarn's window no longer carries into the next review.
- Use every lower tier now respects a tier's Keep at least amount, even when that tier isn't spent.
- With saved data from a newer version of the addon, nothing is bought or written until you update.
- A plan priced from your last visit says so and waits for live prices before review.

## [0.0.1] - 2026-10-01

### Added
- The exchange window: talk to Vaskarn in Silvermoon and it opens to the right of his list (or collapsed to a small tab there, if you prefer), showing all five Mistcrest tiers with your balance, the room left under the cap, and crests waiting in unopened packs.
- Trading up and down from one place: pick the tier you want, then the trade that gives it, with what it spends and gives before anything is bought.
- Plans across several tiers: "I want 60 Myth" can use your Hero and trade Champion up to Hero on the way. The ladder previews every step and balance, a Spend box per tier keeps any tier untouched, and crest packs already in your bags count: they're opened as part of the plan, and only what's still needed is bought. One button in the same place runs it all (buy the step, close Vaskarn's window, open each pack, then the next step), with a progress bar of the steps.
- The crest ladder: your tiers as tiles with their icons, the trades between them animated as you preview and run an exchange.
- Exact amounts: pick a tier and type how many crests to receive, and every way of getting them is priced for that amount with one that works picked for you; or press Max, whose tooltip says what limits it (your crests, the cap, your bags, or your reserve). An amount between packs offers the two nearest choices.
- "Keep at least" per tier, respected by Max and every exchange.
- A preview of both balances before and after the packs open, and one confirmation per exchange, with its own warning for a trade down.
- Cap protection: packs you already hold count against the cap, and a pack is only bought when all of its crests fit. Open packs soon after buying, since crests earned elsewhere use the same room.
- Your Interact key runs an exchange: it presses the exchange button (buy, close the vendor, open each pack), and when a plan needs Vaskarn again it talks to him, switching the game's Enable Interact Key setting on for that moment if it was off. Never in combat; "Use my Interact key" in the settings turns it off.
- Open next pack: one press per pack, in a button that never moves. A pack used while a vendor's window is open would be sold, so the button closes the window first and opens nothing until it's closed.
- Stopping and coming back: Stop, combat, closing Vaskarn's window or logging out pauses an exchange (closing only the exchange window lets a confirmed purchase carry on), and back at Vaskarn you see what you received, what's still in packs and what's left; nothing more is bought until you confirm again.
- Locked trades explained: the achievement a trade up needs (with the gear slots that are too low for it) or the Upgrade Practicum quest for trading down.
- "Before you spend": ranks left per upgrade track, your lowest gear item levels, and your reserves.
- `/ce` anywhere shows your crests and room, with the trades seen on your last visit.
- `/ce dump` opens a report of Vaskarn's list, your crests and the exchange in progress, selected for Ctrl+C, for bug reports.
- A feature guide (`/ce guide`, the "?" on the window, or the Guide button in the settings), shown on your first login, and an entry in the minimap's addon menu.
- What's New (`/ce changelog`): what changed in each version, shown after an update.
- Settings: Show at Vaskarn, Position (right of his list by default, or left, or where you drag it), and Reset position.
