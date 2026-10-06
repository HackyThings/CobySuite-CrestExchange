# Coby's Crest Exchange

<p align="center">
  <img src="https://raw.githubusercontent.com/HackyThings/CobySuite-CrestExchange/main/.publish-meta/icon/cobys-crest-exchange-224.jpg" width="160" alt="Coby's Crest Exchange">
</p>

A better crest exchange at Vaskarn in Silvermoon (WoW Midnight 12.1). Choose how many crests you want, see what each way of getting them costs, and let one button run the buying and opening.

## Features

- Every way of getting your crests, priced for the amount you choose.
- Plans across your lower tiers, with crest packs already in your bags counted.
- Your balance and a cap meter per tier: how full each cap is, the crests waiting in unopened packs, and a MAX mark at a cap.
- A reserve per tier that Max and every exchange leave alone.
- Locked trades explained, down to the gear slot.
- Your Interact key can run the whole exchange.

## Quick Start

1. Talk to Vaskarn and click the tier you want more of.
2. Type an amount, or press Max, then pick a route.
3. Press Review, check the cost, then Confirm.
4. Press the exchange button: it closes Vaskarn's window and opens each pack. When a plan needs him again, talk to him and keep going.

Stop, combat, or closing Vaskarn's window pauses the buying; nothing more is bought until you confirm again.

## Install

**CurseForge:** https://www.curseforge.com/wow/addons/cobys-crest-exchange

**Manual:** Drop the `CobysCrestExchange` folder into your `Interface/AddOns/`. No dependencies.

## Slash Commands

```
/ce                   Open or close the exchange window (also /ce show)
/ce settings          Open or close the settings window (also config, options)
/ce guide             Open or close the feature guide (also tutorial)
/ce changelog         Open or close the changelog: what changed in each version (also change, whatsnew, news)
/ce debug             Open or close the debug log window
/ce dump              Show a report of what the addon sees, selected for Ctrl+C (for bug reports)
/ce version           Print the addon version
/ce help              Show this help
```

`/crestex` and `/crestexchange` work the same as `/ce`. The addon is also in the AddOns menu by the minimap: click for the exchange window, right-click for settings.

## License

GPL-2.0. See [LICENSE](LICENSE).

## Issues / Feedback

Found a bug? Copy `/ce dump`, then run `/ce debug` and press **Copy Last 250**, and send both with a line about what you were doing. The log holds the addon version, your WoW build and your settings.

- **Email:** hackythings@gmail.com
- **BugSack errors:** whisper them to **Figment-Illidan** in game.
- **CurseForge:** comment on the [project page](https://www.curseforge.com/projects/1720538) for questions and feedback.
- **GitHub:** [open an issue](https://github.com/HackyThings/CobySuite-CrestExchange/issues) for bugs you can reproduce.
