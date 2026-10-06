-------------------------------------------------------------------------------
-- Data.Changelog: the in-game changelog (Views/WhatsNew.lua, /ce changelog),
-- one entry per version, newest first. Shown after an update with every
-- version newer than the one the player last ran opened.
--
-- An entry: version (the TOC's), title (a few words), date ("2026-10-02"
-- once released; nil shows "Beta"), optional icon (default
-- CobysCrestExchange.ICON), and the lists new, changed and fixed, each a
-- line a player reads (the CHANGELOG.md style: what changed for them, no
-- internals), short enough to fit on one line: "Feature: what it does",
-- the part before the first ": " shown in blue, and {/ce} for a command in
-- gold. Keep it in step with CHANGELOG.md: /release adds the entry.
-------------------------------------------------------------------------------
CobysCrestExchange.Data = CobysCrestExchange.Data or {}

CobysCrestExchange.Data.Changelog = {
  {
    version = "0.0.3",
    title = "Cap meters and MAX",
    date = "2026-10-06",
    new = {
      "First page: the whole flow in one line until your first exchange",
      "Opening packs: a progress bar",
      "MAX: a green check and MAX on a tier at its cap",
    },
    changed = {
      "Cap meters: each tier fills toward its cap",
      "Receipts: tiles per tier with each crest's icon",
      "Plan from lower tiers, and Trade requirements for locked trades",
      "Review: says what comes after Confirm",
      "Get page: says why a route is closed",
      "Settings: Cancel is now Undo edits",
      "Many smaller look and wording improvements",
    },
    fixed = {
      "Unopened packs note counts what Open packs opens",
      "Several smaller bug fixes",
    },
  },
  {
    version = "0.0.2",
    title = "Settings and docking",
    date = "2026-10-01",
    new = {
      "Interact key: you can stop the addon turning on Enable Interact Key for you",
    },
    changed = {
      "Settings: three pages (Exchange, Interact key, Window) with picture tiles",
      "Show at Vaskarn: full window, small tab or stay closed, separate from folding",
      "Docking: Prefer right, Prefer left, Automatic or Saved position",
      "Get: the lowest tiers are used first when they cover your amount",
      "Opening packs you already had ends with Packs opened and no Spent line",
      "Review: each crest's icon, its balance after opening, and a tooltip",
      "Locked trades: your gear slots in a table with the item level each needs",
      "Trade labels read the same everywhere, using last seen prices away from Vaskarn",
      "Copy buttons say to press Ctrl+C",
    },
    fixed = {
      "Receipt: a finished plan totals every step, not just the last",
      "End exchange here: grayed out while a pack is opening",
      "Messages no longer cut off on the Get page and in a plan's next step",
      "Wait for the last pack: no longer lingers after the pack opens",
      "Plans stop before a step whose price changed, so you can plan again",
      "Plans priced from your last visit wait for live prices before review",
      "Keep at least: respected even by a tier that isn't spent",
      "Unrelated game errors during a purchase no longer read as Vaskarn refusing it",
      "Combat or closing Vaskarn's window mid-review no longer carries into the next one",
      "Saved data from a newer version: nothing is bought or written until you update",
    },
  },
  {
    version = "0.0.1",
    title = "A better crest exchange",
    date = "2026-10-01",
    new = {
      "Exchange window: opens to the right of Vaskarn's list in Silvermoon",
      "Collapse: shrink the window to a small tab beside his list",
      "Your tiers: balance, room under the cap, crests in unopened packs",
      "Trade up or down: pick the tier you want, then what to spend",
      "Plans: want Myth from Hero and Champion? One plan, step by step",
      "Plans: count the crest packs already in your bags",
      "One button runs a plan: buy, close the vendor, open, next step",
      "Interact key: presses that button and talks to Vaskarn",
      "Ladder: every tier as a tile, trades flowing between them as you plan",
      "Exact amounts: type how many, or Max, which says what limits it",
      "Keep at least: a reserve per tier that every exchange respects",
      "Preview: both balances before and after the packs open",
      "One confirmation per exchange, with a warning for trading down",
      "Cap protection: buys a pack only when all its crests fit",
      "Open next pack: one press per pack, safe to press quickly",
      "Stop and come back: see what's bought, open and left to buy",
      "Locked trades: what each one needs, down to the gear slot",
      "Before you spend: ranks left per upgrade track",
      "Planning: {/ce} anywhere shows your crests and room",
      "Reports: {/ce dump} shows what the addon sees, ready for Ctrl+C",
    },
  },
}
