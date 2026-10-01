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
    version = "0.0.1",
    title = "A better crest exchange",
    date = "2026-10-01",
    new = {
      "Exchange window: opens to the right of Vaskarn's list in Silvermoon",
      "Collapse: shrink the window to a small tab beside his list",
      "Your tiers: balance, room under the cap, crests in unopened packs",
      "Trade up or down: pick the tier you want, then what to spend",
      "Plans: want Myth from Hero and Champion? One plan, step by step",
      "Plans count the crest packs already in your bags",
      "One button runs a plan: buy, close the vendor, open, next step",
      "Your Interact key presses that button and talks to Vaskarn",
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
