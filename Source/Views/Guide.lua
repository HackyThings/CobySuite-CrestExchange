-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Guide: the feature guide (the suite's standard
-- setup, as Recollect's)
--
-- CobySuite.UI.CreateGuideWindow, built at load so opening it in combat
-- creates nothing. Short sections in the order a player meets them at
-- Vaskarn. Opened by /ce guide (tutorial), the exchange window's "?", the
-- settings window's Guide button, and on a fresh install's first login
-- (What's New calls Guide.Show).
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Guide = {}
Views.Guide = Guide

local U = CobySuite_CobysCrestExchange.Utilities

local function Key(text) return U.WrapColor(U.Colors.HELP_COMMAND, text) end

local T = CobySuite_CobysCrestExchange.UI.GuideText

Guide.SECTIONS = {
  { key = "exchange", title = "Exchanging crests", atlas = "common-icon-rotateright",
    summary = "Pick the tier you want, then how many.",
    body = { T.Bullets({
        "Talk to Vaskarn in Silvermoon and this window opens beside his list.",
        "The ladder shows your five tiers, Myth on top. The big number is what you hold.",
        "Each row fills as you earn toward the cap that limits it, with a fainter band for crests in unopened packs. Reaching the cap shows a green check and " .. Views.Text.Max() .. "; unopened packs can fill the row without reaching it.",
        "Click the tier you want more of, then type how many. Every route is priced for that amount.",
        "Routes: trade up from the tier below, a plan from the lower tiers, or trade down from the tier above.",
        "A route that works is picked and highlighted, plan first, then trade up. Click another to use it instead.",
        "Trading down is never picked for you, and Review warns you before it gives up a higher tier.",
        "Review lists what you spend and receive. Confirm starts the exchange. Exchanges can't be refunded.",
    }) },
    try = { { "/ce", "Open or close the exchange window" } } },
  { key = "amount", title = "Choosing an amount", atlas = "common-icon-plus",
    summary = "Exactly what you ask for, or Max.",
    body = { T.Bullets({
        "Type how many crests you want to receive. Packs hold a set number, so an in-between amount offers the two nearest choices.",
        "Max fills in the most you can receive now. Its tooltip names what limits it.",
        "Keep at least, under Before you spend, sets crests to hold back per tier. Max and every exchange respect it.",
    }) } },
  { key = "opening", title = "Opening packs", atlas = "common-icon-checkmark",
    summary = "One press per pack.",
    body = { T.Bullets({
        "One button in the same place runs the exchange.",
        "It closes Vaskarn's window, opens one pack per press, and buys a plan's next step.",
        "A pack used while a vendor window is open is sold, so the button closes it first. Pressing quickly is safe.",
        "Packs already in your bags get an Open packs banner on the first page, to open them without buying.",
        "Your Interact key also presses the button while this window is open and expanded. Use a key without Shift, Ctrl, Alt or Meta.",
        "It never works in combat. When a plan needs Vaskarn again, the same key talks to him.",
        "On the Interact key settings page, choose whether the key presses the button and whether the walk back may turn on Enable Interact Key.",
    }) } },
  { key = "plans", title = "Several tiers at once", atlas = "common-icon-rotateleft",
    summary = "Want Myth, have Hero and Champion? One plan does it.",
    body = { T.Bullets({
        "Pick a tier, type how many, then choose Plan from lower tiers. It's picked for you unless you chose another working route.",
        "Adjust shows the whole plan on the ladder: which trades run, in what order, and every balance before and after.",
        "Each lower tier has a Spend box. Unchecked, crests made there on the way are used, but that tier's balance and unopened packs stay untouched.",
        "Crest packs already in your bags count: the plan opens them as a step and buys only what's still needed.",
        "Confirm starts the first step. When the next step needs Vaskarn, talk to him again and the button reads Buy step and its number.",
        "A progress bar shows how far the plan has come.",
    }) } },
  { key = "caps", title = "Room and caps", atlas = "common-icon-forwardarrow",
    summary = "Why an exchange can be held back.",
    body = { T.Bullets({
        "Crest tiers can have a weekly or season cap. Room is how many more you can receive.",
        "Packs you already have count against the room. A pack is only bought when all its crests fit.",
        "Open packs soon: crests you earn elsewhere use the same room, and a pack that no longer fits waits in your bags.",
        "A tier with no room left reads " .. Views.Text.Max() .. ": the window names the cap, with numbers, and what still works.",
        "Weekly allowances return at the weekly reset. Season caps usually go up with each weekly reset.",
    }) } },
  { key = "locked", title = "Locked trades", atlas = "common-icon-redx",
    summary = "What each trade needs.",
    body = { T.Bullets({
        "Trading up needs the achievement of the tier you spend, earned on this character. Hero into Myth needs Hero of the Mist.",
        "The achievement counts the highest item level each gear slot has reached, so one low slot holds it back.",
        "Trading down needs Vaskarn's quest Upgrade Practicum.",
        "Trade requirements, on the first page, lists every trade and what it needs.",
    }) } },
  { key = "stopping", title = "Stopping and coming back", atlas = "common-icon-undo",
    summary = "Nothing is bought twice.",
    body = { T.Bullets({
        "Stop, combat, closing Vaskarn's window or a reload pause the buying. Closing only this window lets a confirmed purchase carry on.",
        "Back at Vaskarn, the window shows what you received, what's still in packs and what's left to buy.",
        "Review remaining asks you to confirm again before more is bought. A plan stopped between steps resumes with Buy step.",
        "Crests you spend in the meantime never make it buy more.",
        "A slow purchase shows Waiting to see the last purchase. The window moves on by itself, and nothing more is bought until then.",
        "After a reload or logout mid-purchase, compare the rows with your bags and press Check again.",
    }) },
    try = { { "/ce dump", "Show a report of what the addon sees, ready to copy with Ctrl+C, for a bug report" } } },
  { key = "settings", title = "Settings and help", atlas = "common-icon-backarrow",
    summary = "Where the window sits, and where to find this guide.",
    body = { T.Bullets({
        "Settings cover what talking to Vaskarn brings up (window, tab or nothing), your Interact key, and where the window docks.",
        "The gear on the exchange window opens them too. Changes apply when you press Apply.",
        "What's New lists what changed in each version, and opens by itself after an update.",
    }) },
    try = {
      { "/ce settings", "Open or close the settings" },
      { "/ce guide", "Open this guide" },
      { "/ce changelog", "What changed in each version" },
      { "/ce help", "Every command" },
    } },
}

local window = CobySuite_CobysCrestExchange.UI.CreateGuideWindow({
  name = "CobysCrestExchangeGuideWindow",
  title = CobySuite_CobysCrestExchange.Utilities.WrapColor(CobysCrestExchange.BRAND_COLOR, "Coby's Crest Exchange") .. " Guide",
  icon = CobysCrestExchange.ICON,
  intro = "New here? Start with the first section. Click any heading to open or close it.",
  footer = "Open this guide any time with " .. Key("/ce guide"),
  sections = Guide.SECTIONS,
  persist = { svTable = function() return COBYS_CREST_EXCHANGE_WINDOW_STATE end, key = "guideWindow" },
})

function Guide.Toggle() window:Toggle() end

-- The first section open, as a fresh install's first login shows it
function Guide.Show() window:OpenSection(Guide.SECTIONS[1].key) end
