# Changelog

All notable changes to Coby's Crest Exchange are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), version numbering follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
