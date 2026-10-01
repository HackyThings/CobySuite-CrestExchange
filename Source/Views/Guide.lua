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

Guide.SECTIONS = {
  { key = "exchange", title = "Exchanging crests", atlas = "common-icon-rotateright",
    summary = "Pick the tier you want, then how many.",
    body = {
      "Talk to Vaskarn in Silvermoon and this window opens beside his list. The ladder shows your five tiers, Myth on top: balance, room under the cap, and crests in unopened packs.",
      "Click the tier you want more of, then type how many. Every way of getting them is priced for that amount: trading up from the tier below, a plan that uses every lower tier, or trading down from the tier above.",
      "One that works is picked and highlighted, trading up when it can; click another to use it instead. Trading down is never picked for you: it's listed last, and Review warns you before it gives up a higher tier. The path under them shows what each tier gives and gets.",
      "Review lists what you spend and receive and the balances that change. Confirm starts the exchange; exchanges can't be refunded.",
    },
    try = { { "/ce", "Open or close the exchange window" } } },
  { key = "amount", title = "Choosing an amount", atlas = "common-icon-plus",
    summary = "Exactly what you ask for, or Max.",
    body = {
      "Type how many crests you want to receive. Packs hold a set number, so an amount in between offers the two nearest choices.",
      "Max fills in the most you can receive right now. Its tooltip says what limits it: your crests, the cap, your bags, or the amount you chose to keep.",
      "Keep at least, under Before you spend, sets a reserve per tier that Max and every exchange respect.",
    } },
  { key = "plans", title = "Several tiers at once", atlas = "common-icon-rotateleft",
    summary = "Want Myth, have Hero and Champion? One plan does it.",
    body = {
      "Pick a tier, type how many, and choose Use every lower tier (when trading up can't reach the amount, it's picked for you, unless you already chose another route that works). Adjust shows the whole plan on the ladder: which trades run, in what order, and every balance before and after.",
      "Each lower tier has a Spend box. Unchecked, crests made there on the way are used, but your own balance and that tier's unopened packs are left alone.",
      "Crest packs already in your bags count: the plan opens them as one of its steps and buys only what's still needed.",
      "Confirm starts the first step, which may open packs you already have. The one button closes Vaskarn's window and opens one pack per press. When the next step needs him, talk to Vaskarn again and the same button reads Buy step and its number. A progress bar shows how far the plan has come.",
    } },
  { key = "caps", title = "Room and caps", atlas = "common-icon-forwardarrow",
    summary = "Why an exchange can be held back.",
    body = {
      "Crest tiers can have a weekly or season cap. Room is how many more you can receive.",
      "Packs you already have count against the room, and a pack is only bought when all of its crests fit. Open them soon: crests you earn elsewhere use the same room, and a pack that no longer fits waits in your bags.",
      "When a tier is full, the window says which cap it hit, with the numbers, and what still works. A weekly allowance comes back at the weekly reset; season caps usually go up with each weekly reset.",
    } },
  { key = "opening", title = "Opening packs", atlas = "common-icon-checkmark",
    summary = "One press per pack.",
    body = {
      "One button in the same place runs the whole exchange: it closes Vaskarn's window, opens one pack per press, and buys a plan's next step when you're back at Vaskarn.",
      "A pack used while a vendor's window is open is sold, so the button closes the window first and only opens packs once it's closed. Pressing it quickly is safe.",
      "Packs already in your bags get an Open packs banner on the first page, to open them without buying anything.",
      "Your Interact key (the Interact with target key binding) presses the button too, so one key runs it all, while this window is open and expanded. When a plan needs Vaskarn again, walk up to him and press the same key to talk to him. Only a key without Shift, Ctrl, Alt or Meta works this way, never in combat. If the game's Enable Interact Key option is off, it's switched on while a plan waits for Vaskarn and put back afterwards. Turn all of this off in the settings.",
    } },
  { key = "locked", title = "Locked trades", atlas = "common-icon-redx",
    summary = "What each trade needs.",
    body = {
      "Trading up needs the achievement of the tier you spend, earned on this character: Hero into Myth needs Hero of the Mist. It counts the highest item level each gear slot has reached, so one low slot holds it back.",
      "Trading down needs Vaskarn's quest Upgrade Practicum.",
      "Why are trades locked? on the first page lists every trade and what it needs.",
    } },
  { key = "stopping", title = "Stopping and coming back", atlas = "common-icon-undo",
    summary = "Nothing is bought twice.",
    body = {
      "Stop, combat, closing Vaskarn's window or a reload pause the buying; closing only this window lets a confirmed purchase carry on. When you're back at Vaskarn the window shows what you received, what's still in packs and what's left to buy.",
      "Review remaining asks you to confirm again before anything more is bought; a plan stopped between steps picks up with its Buy step button. Crests you spend in the meantime never make it buy more.",
      "Each purchase is checked against your crests and bags. If the game is slow to show one, the window waits (Waiting to see the last purchase) and moves on by itself when it lands; nothing more is bought until it does. After a reload or logout in the middle of a purchase, compare the rows with your bags and press Check again.",
    },
    try = { { "/ce dump", "Show a report of what the addon sees, ready to copy with Ctrl+C, for a bug report" } } },
  { key = "settings", title = "Settings and help", atlas = "common-icon-backarrow",
    summary = "Where the window sits, and where to find this guide.",
    body = {
      "Settings: whether the window opens at Vaskarn, whether your Interact key runs the exchange, and where the window docks beside his list. The gear on the exchange window opens them too.",
      "What's New lists what changed in each version, and opens by itself after an update.",
    },
    try = {
      { "/ce settings", "Open the settings" },
      { "/ce guide", "Open this guide" },
      { "/ce changelog", "What changed in each version" },
      { "/ce help", "Every command" },
    } },
}

local window = CobySuite_CobysCrestExchange.UI.CreateGuideWindow({
  name = "CobysCrestExchangeGuideWindow",
  title = "Coby's Crest Exchange Guide",
  icon = CobysCrestExchange.ICON,
  intro = "New here? Start with Exchanging crests; the rest is there when you want it.",
  footer = "Open this guide any time with " .. Key("/ce guide"),
  sections = Guide.SECTIONS,
  persist = { svTable = function() return COBYS_CREST_EXCHANGE_WINDOW_STATE end, key = "guideWindow" },
})
Guide.window = window

function Guide.Toggle() window:Toggle() end

-- The first section open, as a fresh install's first login shows it
function Guide.Show() window:OpenSection(Guide.SECTIONS[1].key) end
