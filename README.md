# Coby's Crest Exchange

<p align="center">
  <img src="https://raw.githubusercontent.com/HackyThings/CobySuite-CrestExchange/main/.publish-meta/icon/cobys-crest-exchange-224.jpg" width="160" alt="Coby's Crest Exchange">
</p>

A better crest exchange at Vaskarn in WoW Midnight (12.1): see what you can convert, pick an amount, and convert in a few clicks.

You need 40 more Myth crests. You have some Hero, a pile of Champion, a couple of packs you forgot to open, and a cap you are not quite sure about. Vaskarn's list sells crest packs and leaves the maths to you. Coby's Crest Exchange opens beside his list, asks how many crests you want, shows what each way of getting them costs, works out a plan across your lower tiers, and then runs the whole thing from one button.

## The Problem

Vaskarn's exchange is a merchant list. Every trade is a crest pack you buy and then open, one pack at a time, so getting a set number of crests means counting packs, checking each tier's cap, and remembering which trades your character has unlocked. His list doesn't show how much room each tier has left under its cap, and a trade your character hasn't unlocked simply isn't there. A pack you use with his window still open is sold back instead of opened. And if you want Myth but only hold Hero and Champion, the whole chain of trades is yours to work out.

## How It Works

1. **Talk to Vaskarn in Silvermoon.** The exchange window opens to the right of his list. The crest ladder shows your five tiers stacked from Myth down to Adventurer: balance, room left under the cap, and crests waiting in unopened packs. Packs already in your bags get an Open packs banner, so you can open them without buying anything. The button next to the settings gear folds the window into a small tab beside his list; click the tab to bring it back. It remembers which you prefer.
2. **Click the tier you want more of, and type how many.** Max fills in the most you can receive right now, and its tooltip says what limits it: your crests, the cap, your bags, or the amount you chose to keep. Packs hold a set number of crests, so an amount in between offers the two nearest choices; nothing is rounded for you.
3. **Pick a way to get them.** Every route is priced for that amount:
   - **Trade up** from the tier below, three for one.
   - **Use every lower tier**, a plan across several tiers. Adjust shows it on the ladder, with a Spend box on each lower tier: unchecked, that tier's own balance and its unopened packs are left alone.
   - **Trade down** from the tier above, one for one. It is listed last, never chosen for you, and warned about before you confirm.

   A route that works is picked for you, trading up first. The path under the routes shows what each tier gives and gets.
4. **Review and confirm.** One page lists what you spend, what you receive, and the balances that change once the packs open, with a reminder that exchanges can't be refunded. Confirm sits away from where you pressed Review and only works after a short moment, so a double click can't buy by accident. Confirm buys the packs.
5. **Press the one button.** It sits in the same place for the whole exchange and always does the next thing: it closes Vaskarn's window, then opens one pack per press. The game needs a press for every pack, and pressing quickly is safe. A plan shows its steps on the ladder with a progress bar. When the next step needs Vaskarn again, talk to him and the same button buys it.
6. **Stop any time.** Stop, combat, closing Vaskarn's window while packs are being bought, or logging out pauses the buying. Closing only the exchange window doesn't: the purchase you confirmed carries on. Back at Vaskarn you see what you received, what's still in packs and what's left to buy; Review remaining asks you to confirm again before anything more is bought. A plan stopped between steps picks up with its Buy step button.

More it handles:

- **Your Interact key runs it.** While an exchange runs, the key you use to interact with targets presses the button too. When a plan needs Vaskarn again, the same key talks to him: the game's Enable Interact Key option is switched on for that moment if it was off, then put back. Never in combat, and it can be turned off in the settings.
- **Packs already in your bags count.** A plan opens them as one of its steps and buys only what's still needed. To open them on their own, use the Open packs banner.
- **Cap-aware buying.** Packs you hold count against the cap, and a pack is only bought when all of its crests fit. When a tier is at its cap, the window says which cap, with the numbers, instead of a vague "not available".
- **Keep a reserve.** Keep at least, under Before you spend, sets an amount per tier that Max and every exchange leave alone.
- **Nothing is bought twice.** Each purchase is checked against your crests and bags before anything else happens. If the game is slow to show a purchase, the window waits for it and moves on by itself when it lands.
- **Locked trades explained.** Each locked trade says what it needs, and Why are trades locked? lists them all: the achievement for trading up (and which gear slots are too low for it) or Vaskarn's quest for trading down.
- **Before you spend.** How many upgrade ranks your equipped items have left per track, your lowest item levels, and your reserves.
- **Plan away from Vaskarn.** `/ce` shows your balances and room anywhere, with the trades you saw on your last visit.

## Install

**CurseForge:** https://www.curseforge.com/wow/addons/cobys-crest-exchange

**Manual:** Drop the `CobysCrestExchange` folder into your `Interface/AddOns/`. No dependencies.

## Slash Commands

```
/ce                   Open or close the exchange window
/ce show              Open or close the exchange window
/ce settings          Open the settings window (also /ce config, /ce options)
/ce guide             Open or close the feature guide (also /ce tutorial)
/ce changelog         What changed in each version (also /ce whatsnew, /ce news, /ce change)
/ce dump              Show a report of what the addon sees, selected for Ctrl+C (for bug reports)
/ce debug             Toggle the debug log window
/ce version           Print the addon version
/ce help              Command list
```

`/crestex` and `/crestexchange` work the same as `/ce`. The addon is also in the minimap's addon menu: click for the exchange window, right-click for settings.

## Guide and What's New

`/ce guide`, the "?" on the exchange window, or the **Guide** button in the settings window opens a short guide in the order you meet things at Vaskarn: exchanging crests, choosing an amount, plans, caps, opening packs, locked trades, stopping and coming back, and the settings. It opens by itself the first time you log in with the addon.

`/ce changelog` lists what changed in each version. After an update it opens by itself with every version since the one you last played.

## Settings

Open with `/ce settings`, the gear on the exchange window, the addon's entry in the minimap addon list, or the Open Settings button on its page under Options > AddOns. The settings are grouped into categories on the left. Changes take effect when you press Apply; Cancel or closing the window throws them away. Defaults asks first, then fills in every default, and nothing changes until you press Apply. Drag the window's bottom-right corner to make it bigger; it keeps that size.

**Exchange**
- Show at Vaskarn (default on): open the exchange window when you talk to him
- Use my Interact key (default on): your Interact key presses the exchange button, and talks to Vaskarn between a plan's steps

**Window**
- Position (default Right of the vendor): right or left of his list, whichever fits (Automatic), or wherever you drag it
- Reset position: forget where you dragged the window (this one acts at once, without Apply)

Reserves (Keep at least) live in the exchange window, under Before you spend.

## Troubleshooting

**A tier says it's at its cap, and nothing can be made.**

- Crest tiers can have a weekly or season cap, and the window names the one you hit with its numbers. Nothing more can be received into that tier until there is room again: a weekly allowance comes back at the weekly reset, and season caps usually go up with each weekly reset.
- Unopened packs of that tier still open if their crests fit, and the window says how many of them can.
- What still works is listed under the message, for example trading that tier up into the next one.

**A trade is locked.**

- A locked trade shows its reason in red; hover it for the details, or click it to see its requirements. Why are trades locked? on the first page lists every trade.
- Trading up needs the achievement of the tier you spend, earned on this character: Hero into Myth needs Hero of the Mist. It counts the highest item level each gear slot has reached, so one low slot holds it back, and the requirements page names that slot.
- Trading down needs Vaskarn's quest Upgrade Practicum.
- If a trade is unlocked but missing, check the filter on Vaskarn's list.

**Trade down is never picked for me.**

- That's on purpose. Trading down gives up a higher tier one for one and can't be refunded, so it is listed last and only used when you click it. Max counts it only while it's the chosen route, and Review spells out what you give up before you confirm.

**The window says "Waiting to see the last purchase".**

- A purchase shows up in two parts, the crests leaving and the packs arriving, and sometimes the game is slow with one of them. The window shows what has changed since the purchase and what was expected, and moves on by itself as soon as the purchase shows up. Nothing more is bought until it does.
- After a reload or logout in the middle of a purchase, compare the rows with your bags and press Check again. Discard order ends the exchange; whatever you have stays yours.

**The game didn't allow buying from the window.**

- The window says so and stops. Buy from Vaskarn's own list instead. If a Buy next pack button appears, the game needs a click for each further purchase; press it once per purchase.

**The button closed Vaskarn's window.**

- That's on purpose: a pack used while a vendor's window is open is sold, so the button closes the window before it opens anything. Talk to him again when a plan needs its next step.

**A pack won't open.**

- The message above the button says why: combat, a loot window to collect first, Vaskarn's window still open, or not enough room under the cap for all of the pack's crests. A pack that doesn't fit waits in your bags until there's room.

**My Interact key doesn't press the button.**

- Check that Interact with target has a key in the game's key bindings, and that Use my Interact key is on in `/ce settings`.
- Keep the exchange window open and expanded: the key only presses the button while the button is showing.
- Only a key without Shift, Ctrl, Alt or Meta is used. With a modifier in the binding, click the button with the mouse instead.
- The key never presses the button in combat.
- Between a plan's steps the key talks to Vaskarn instead, so the next step can be bought.

**Enable Interact Key turned itself on.**

- While a plan waits for you to talk to Vaskarn, the addon switches the game's Enable Interact Key option on if it was off, so your key can talk to him. It puts your setting back as soon as the plan moves on, when you close or fold the exchange window, and at logout. If you change that option yourself in the meantime, the addon leaves it as you set it. Turn off Use my Interact key to keep the addon away from it entirely.

## License

GPL-2.0. See [LICENSE](LICENSE).

## Issues / Feedback

For bug reports, the cleanest path is the diagnostics report and the debug log. The debug log is self-contained: it includes the addon version, your WoW build, a snapshot of every setting, and a timestamped event timeline.

**How to capture and send:**

1. Reproduce the issue, ideally at Vaskarn.
2. Run `/ce dump`: it opens a report of his list, your crests and the exchange in progress, already selected. Press Ctrl+C to copy it.
3. Run `/ce debug` and click **Copy Last 250** for the event timeline.
4. Email them to **hackythings@gmail.com** with a sentence about what you were doing.

**Other channels:**

- **BugSack errors:** whisper the report straight to **Figment-Illidan** in-game. BugSack copies the stack trace for you. Mention how to reproduce if you can.
- **CurseForge comments:** drop a note on the [project page](https://www.curseforge.com/wow/addons/cobys-crest-exchange). Best for general feedback and quick questions.
- **GitHub issues:** [open one here](https://github.com/HackyThings/CobySuite-CrestExchange/issues). Best for reproducible bugs and feature proposals where back-and-forth helps. Attach the dump or debug-log paste here too if it's relevant.
