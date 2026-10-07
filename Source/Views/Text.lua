-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Text: shared wording for the window
--
-- Number formatting, tier colors and the sentences more than one page uses,
-- so the pages only lay things out; a page keeps its own one-off labels.
-- All wording is our own.
-------------------------------------------------------------------------------

CobysCrestExchange.Views = CobysCrestExchange.Views or {}
local Views = CobysCrestExchange.Views
local Text = {}
Views.Text = Text

local U = CobySuite_CobysCrestExchange.Utilities
local Seasons = CobysCrestExchange.Seasons
local Currency = CobysCrestExchange.Currency

local UNKNOWN = "?"

-- MAX in one way everywhere (Task #284): the word in the overview's sage green,
-- and, where MAX is a status a player scans for, the check before it. The check
-- is inline atlas markup sized to the line (0 is the font's height, so lines
-- keep their height), tinted with the markup's own 0-255 red, green and blue
-- (atlas markup ignores color codes).
local SAGE = U.Colors.SAGE_GREEN
local SAGE_RGB = { math.floor(SAGE[1] * 255 + 0.5), math.floor(SAGE[2] * 255 + 0.5), math.floor(SAGE[3] * 255 + 0.5) }
local CHECK_ATLAS = "checkmark-minimal"

-- The word alone, for running sentences
function Text.Max()
  return U.WrapColor(SAGE, "MAX")
end

-- The check and the word, for a status line
function Text.MaxBadge()
  return string.format("|A:%s:0:0:0:0:%d:%d:%d|a %s", CHECK_ATLAS, SAGE_RGB[1], SAGE_RGB[2], SAGE_RGB[3], Text.Max())
end

-- Text in a color that survives colored words inside it: a nested "|r" ends the
-- whole color, so it is turned back on after each one
function Text.Tint(color, text)
  local hex = "|cFF" .. U.ColorToHex(color)
  return hex .. text:gsub("|r", "|r" .. hex) .. "|r"
end

function Text.Count(n)
  if n == nil then return UNKNOWN end
  if n == math.huge then return "no limit" end
  if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
  return tostring(n)
end

-- The review's step cards: how many of `steps` show on `cards` cards, and
-- whether Confirm may approve the plan. Every step must show: a plan with
-- more steps than cards can't be confirmed (never part of it hidden).
function Text.ReviewShown(steps, cards)
  return math.min(steps, cards), steps <= cards
end

-- How far the review's card list scrolls: the shown cards' height past the
-- height of the window onto them
function Text.ScrollMost(shown, cardHeight, viewHeight)
  return math.max(0, shown * cardHeight - viewHeight)
end

function Text.Plural(n, one, many)
  return (n == 1) and one or many
end

function Text.Packs(n)
  return Text.Count(n) .. " " .. Text.Plural(n, "pack", "packs")
end

-- A balance before and after ("200 to 140")
function Text.Change(before, after)
  return Text.Count(before) .. " to " .. Text.Count(after)
end

-- Tier colors follow the item quality colors of the tracks
function Text.TierColor(season, tierKey)
  local tier = season and Seasons.Tier(season, tierKey)
  local color = tier and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[tier.quality]
  if color and color.hex then return color.hex:gsub("^|c", ""):sub(3) end
  return "FFFFFF"
end

function Text.TierLabel(season, tierKey)
  local tier = season and Seasons.Tier(season, tierKey)
  return tier and tier.label or tostring(tierKey)
end

function Text.Tier(season, tierKey, suffix)
  local label = Text.TierLabel(season, tierKey) .. (suffix or "")
  return U.WrapColor(Text.TierColor(season, tierKey), label)
end

function Text.Crests(season, tierKey, n)
  return Text.Count(n) .. " " .. Text.Tier(season, tierKey)
end

function Text.Currency(season, tierKey)
  return Text.Tier(season, tierKey, " " .. (season and season.label or "crests"))
end

local LIMITER = {
  unknown_room = "The game isn't reporting how much room is left for this tier.",
  purchasable = "Vaskarn lists this trade but won't sell it right now (it is grayed out in his window).",
  room = "Room left for the crests you'd receive.",
  reserve = "The amount you chose to keep.",
  balance = "The crests you have to spend.",
  stock = "The vendor's stock.",
  bags = "Space in your bags for the packs.",
  resume = "What's left of the order you stopped.",
}
function Text.Limiter(key) return LIMITER[key] or "" end

function Text.Date(t)
  if not t or t == 0 then return UNKNOWN end
  return date("%b %d", t)
end

local SLOT_LABELS = {
  Head = "Head", Neck = "Neck", Shoulder = "Shoulders", Cloak = "Back", Chest = "Chest", Wrist = "Wrists",
  Hand = "Hands", Waist = "Waist", Legs = "Legs", Feet = "Feet", Finger = "Rings (both)",
  Trinket = "Trinkets (both)", Twohand = "Two-hand weapon", MainhandWeapon = "Main hand",
  OnehandWeapon = "One-hand weapon", OnehandWeaponSecond = "Second one-hand", Offhand = "Off hand",
}
function Text.Slot(name) return SLOT_LABELS[name] or name end

-- Session notices and pause reasons
local NOTICE = {
  changed = "Something changed. Review the exchange again.",
  stopping = "Stopping after the purchase in progress.",
  auto_stopped = "Automatic opening stopped. Press Open to continue.",
  open_no_effect = "That press didn't open a pack.",
  checked = "Checked.",
  still_unclear = "Checked again: the purchase is still unconfirmed.",
  open_odd = "A pack opened but its crests don't add up yet; it counts as opened.",
}
function Text.Notice(key, extra)
  if key == "game_message" then return extra or "The game refused that." end
  return NOTICE[key]
end

local PAUSE = {
  stopped = "Stopped.",
  combat = "Exchanges pause during combat.",
  merchant_closed = "Vaskarn's window closed.",
  other_vendor = "This isn't the vendor the order started at.",
  offer_missing = "Vaskarn isn't showing this trade right now. Check his merchant filter.",
  offer_changed = "The trade changed since you reviewed it.",
  offer_ambiguous = "Vaskarn lists this pack more than once, so nothing was bought.",
  unknown_balance = "The game isn't reporting your crest balance.",
  unknown_room = "The game isn't reporting how much room is left for this tier.",
  capped = "These crests are at " .. Text.MaxBadge() .. ", or too close for another pack, so buying stopped before a pack could be wasted.",
  balance = "Not enough crests left for another pack.",
  bags = "Your bags are full.",
  stock = "The vendor is out of stock.",
  blocked = "The game didn't allow buying from this window. Buy from Vaskarn's own list instead.",
  refused = "The game refused the purchase.",
  restored = "You stopped in the middle of this exchange.",
  more_to_buy = "The packs bought so far are open. The rest of this exchange is still to buy.",
  checked = "Checked.",
  arrived = "The last purchase showed up and is counted. Review the rest to keep buying.",
}
function Text.Pause(reason) return PAUSE[reason] or reason end

-------------------------------------------------------------------------------
-- An unproven purchase or open (the Progress page's "uncertain" mode): what
-- happened, what to look for, and what each button does
-------------------------------------------------------------------------------
local function ButtonName(name) return U.WrapColor(U.Colors.TEXT_GOLD, name) end

local BUTTON_LINES = {
  ButtonName("Check again") .. ": looks once more; it never buys anything.",
  ButtonName("Discard order") .. ": ends this exchange; what you have stays yours.",
  ButtonName("Copy details") .. ": a report, selected for Ctrl+C, to share if something looks wrong.",
}

local function WithButtons(lines)
  lines[#lines + 1] = ""
  for _, line in ipairs(BUTTON_LINES) do lines[#lines + 1] = line end
  return table.concat(lines, "\n")
end

-- check = Session.View().check: { result, packs, cost, packsSeen, spentSeen,
-- live }; packsSeen and spentSeen are the changes since the purchase was sent
-- (either may be negative: something else changed them), nil when unread
local CHECK_LEAD = {
  -- a restored attempt stays uncertain until Check again, even when it matches
  complete = "Your crest and pack changes match what this purchase should change.",
  none = "Your crests and packs haven't changed since the purchase was sent.",
  overshoot = "Your crests or packs changed by more than the purchase explains; something else may have changed them at the same moment.",
  unknown = "The game isn't reporting your crests or bags right now, so the purchase can't be checked.",
}

local function Lead(check)
  if check.result ~= "partial" then return CHECK_LEAD[check.result] or CHECK_LEAD.none end
  if check.spentSeen == check.cost and check.packsSeen < check.packs then
    return check.packs == 1 and "Your crests dropped by the purchase's price, but its pack isn't in your bags yet."
      or "Your crests dropped by the purchase's price, but not all of its packs are in your bags yet."
  end
  if check.packsSeen == check.packs and check.spentSeen < check.cost then
    return "The purchase's " .. Text.Plural(check.packs, "pack is", "packs are")
      .. " in your bags, but your crests haven't dropped by its full price yet."
  end
  return "Your crests and packs have changed, but not by exactly what the purchase should change."
end

-- "30 fewer", "no change", "15 more"; nil reads as "can't read"
local function Change(n, up, down)
  if n == nil then return "can't read" end
  if n == 0 then return "no change" end
  return Text.Count(math.abs(n)) .. " " .. (n > 0 and up or down)
end

-- The four rows: the purchase, and what has changed since it was sent
function Text.UncertainRows(season, product, check, ledger, order)
  return {
    { "Last purchase", Text.Packs(check.packs) .. " for " .. Text.Crests(season, product.from, check.cost) },
    { Text.TierLabel(season, product.from) .. " crests since",
      Change(check.spentSeen, "fewer", "more") .. " (expected " .. Text.Count(check.cost) .. " fewer)" },
    { Text.TierLabel(season, product.to) .. " packs since",
      Change(check.packsSeen, "more", "fewer") .. " (expected " .. Text.Count(check.packs) .. " more)" },
    { "This exchange", string.format("%s of %s confirmed", Text.Count(ledger.purchased), Text.Packs(order.approvedPacks)) },
  }
end

function Text.UncertainMessage(check, reason, notice)
  local lines = {}
  if notice then lines[#lines + 1] = notice end
  local lead = Lead(check)
  if reason == "restored" then lead = "You logged out or reloaded while a purchase was on its way. " .. lead end
  lines[#lines + 1] = lead
  lines[#lines + 1] = check.live
    and "It may still have gone through. Nothing more is bought until it's confirmed, and this page moves on by itself when it is."
    or "It may still have gone through. Nothing more is bought until it's confirmed: compare the rows above with your bags, then press Check again."
  return WithButtons(lines)
end

function Text.UncertainOpenMessage(notice)
  local lines = {}
  if notice then lines[#lines + 1] = notice end
  lines[#lines + 1] = "You logged out or reloaded while a pack was opening, so it isn't known whether it opened."
  lines[#lines + 1] = "Check again looks: a pack gone from your bags counts as opened; if none is gone, you go back to opening."
  return WithButtons(lines)
end

-- An uncertain purchase with nothing left to compare (Check again pauses it)
function Text.UncertainPlainMessage(notice)
  local lines = {}
  if notice then lines[#lines + 1] = notice end
  lines[#lines + 1] = "The last purchase can't be compared any more. Press Check again to move on."
  return WithButtons(lines)
end

local OPEN_BLOCK = {
  combat = "Leave combat to open packs.",
  merchant_open = "Close the vendor's window to open packs.",
  quota = "All packs from this exchange are open.",
  loot = "Collect the contents in the loot window first.",
  no_pack = "No pack from this exchange is in your bags.",
  locked = "That pack is busy. Try again in a moment.",
  capped = "This pack's crests don't fit under their cap right now, so it stays in your bags until there's room.",
  unknown_room = "The game isn't reporting how much room is left for this tier.",
  busy = "Wait for the last pack to finish opening.",
  no_order = "Nothing to open.",
}
function Text.OpenBlock(reason) return OPEN_BLOCK[reason] or "" end

-- One line for the collapsed tab's tooltip, or nil when nothing is under way
local TAB_STATUS = {
  BUYING = "Buying packs.", WAITING_FOR_PURCHASE = "Buying packs.",
  READY_TO_OPEN = "Packs ready to open.", WAITING_FOR_OPEN = "Opening a pack.", WAITING_FOR_LOOT = "Opening a pack.",
  PAUSED = "An exchange is waiting to be finished.", UNCERTAIN = "An exchange needs checking. Open the window and press Check again.",
  REVIEWING = "Waiting for your confirmation.",
}
TAB_STATUS.NEXT_STEP = "The next step of your plan is ready."

function Text.TabStatus(view)
  return view and TAB_STATUS[view.state] or nil
end

-- The cap a tier is under, in words with its numbers ("its season cap: 800 of
-- 800 earned"), and when it usually rises; nil without a cap. A reached cap
-- reads as MAX, the word the overview shows (Task #282): "MAX: 800 of 800
-- earned this season". badge puts the check before the word (a status line);
-- without it the word is colored alone (a running sentence).
local function CapWords(t, badge)
  local room, c = t.room, t.currency
  local reached = room.raw ~= nil and room.raw <= 0
  local max = (badge and Text.MaxBadge() or Text.Max()) .. ": "
  if room.kind == "weekly" then
    return string.format(reached and (max .. "%s of %s earned this week") or "this week's cap: %s of %s earned this week",
        Text.Count(c.earnedThisWeek), Text.Count(c.maxWeekly)),
      "It starts again with the weekly reset."
  end
  if room.kind == "season" then
    if c.useTotalEarned then
      return string.format(reached and (max .. "%s of %s earned this season") or "its season cap: %s of %s earned",
          Text.Count(c.totalEarned), Text.Count(c.maxQuantity)),
        "Season caps usually go up with each weekly reset."
    end
    return string.format(reached and (max .. "%s of %s held") or "its cap: %s of %s held",
        Text.Count(c.quantity), Text.Count(c.maxQuantity)),
      "Spending some makes room again."
  end
end

-- What gives a full cap room again, by its kind: a cap on what you hold
-- frees up when you spend, a weekly cap starts again at the reset, and an
-- earned season cap only rises
local function HeldCap(t)
  return t.room.kind == "season" and not t.currency.useTotalEarned
end

-- "...wait until <this>", by the cap's kind
local function WaitFor(t)
  if HeldCap(t) then return "you spend some" end
  if t.room.kind == "weekly" then return "the weekly reset" end
  return "the cap rises"
end
Text.WaitFor = WaitFor

-- Two kinds of room: raw room is what the cap still allows (it decides
-- whether a held pack can open); buying room is raw room less the crests
-- already waiting in unopened packs (it decides whether more can be bought)
local function Rooms(t)
  local raw = t.room.raw
  if raw == nil or raw == math.huge then return raw, raw end
  return raw, math.max(0, raw - (t.packedCrests or 0))
end

-- The sign for "no cap" in a meter line (Task #297: the season cap lifts the
-- week of October 20). It is the infinity sign, UTF-8 for U+221E; whether the
-- game's fonts draw it is settled by looking (the Verify scene of the
-- uncapped overview), and if they show a box this is the one line to change
-- to a word such as "no cap".
Text.UNCAPPED_MARK = "\226\136\158"

-- The cap that binds now as a meter for the overview's tiles (Task #247):
-- { frac, packed (the unopened crests' share, clipped to what's left), full,
-- used, limit, label ("Season earned", "Week earned", "Held") }, or nil
-- with unreadable numbers. A tier with no cap at all (Task #297) is a meter
-- with uncapped = true: the season's earned total over no limit, the bar
-- whole and calm (a share of no limit means nothing, and a full bar at the
-- capped tile's strength would read as MAX), no packs band, never full.
function Text.CapMeter(t)
  if not (t and t.room and t.currency) then return nil end
  local room, c = t.room, t.currency
  local used, limit, label
  if room.kind == "none" then
    if type(c.totalEarned) ~= "number" then return nil end
    return { frac = 1, packed = 0, full = false, uncapped = true, used = c.totalEarned, limit = math.huge,
      label = "Season earned" }
  elseif room.kind == "weekly" then
    used, limit, label = c.earnedThisWeek, c.maxWeekly, "Week earned"
  elseif room.kind == "season" then
    limit = c.maxQuantity
    if c.useTotalEarned then used, label = c.totalEarned, "Season earned" else used, label = c.quantity, "Held" end
  else
    return nil
  end
  if type(used) ~= "number" or type(limit) ~= "number" or limit <= 0 or room.raw == nil then return nil end
  local frac = math.max(0, math.min(1, used / limit))
  local packed = math.max(0, math.min(1 - frac, (t.packedCrests or 0) / limit))
  return { frac = frac, packed = packed, full = room.raw <= 0, used = used, limit = limit, label = label }
end

-- The meter's line under the tier's name, the same shape capped or not (Task
-- #269): "Season earned: 45/300", "Week earned: 120/300", "Held: 120/400". The
-- cap being reached shows as the status column's check and MAX, not in this line
function Text.MeterLine(m)
  return m.label .. ": " .. Text.Count(m.used) .. "/" .. (m.uncapped and Text.UNCAPPED_MARK or Text.Count(m.limit))
end

-- The tooltip's lines for a season cap the game has lifted (Task #297): the
-- earned total over the infinity sign, and a plain "No season cap now"; nothing
-- when the earned total isn't readable. Calls add(label, value) then note(text).
function Text.NoSeasonCapLines(t, add, note)
  local c = t and t.currency
  if not (c and c.ok and type(c.totalEarned) == "number") then return false end
  add("Season earned", Text.Count(c.totalEarned) .. "/" .. Text.UNCAPPED_MARK)
  note("No season cap now.")
  return true
end

-- The word beside a capped tile's check, so a full row reads at a glance (Task
-- #268, a still sage-green status since Task #269)
Text.MAX_BADGE = "MAX"

-- The caption under a tile's count: the balance you hold, set apart from the
-- season's earned figures in the line beside it
Text.HELD_CAPTION = "Held"

-- Whether a held pack of `yield` crests can open now (raw room)
function Text.CanOpen(t, yield)
  if not (t and t.room) then return false end
  local raw = Rooms(t)
  return raw ~= nil and raw >= (yield or 1)
end

-- How many of the tier's unopened packs fit the raw room now, of how many:
-- each kind of pack with its own yield when the tier lists them (a reward
-- pack holds more than a trade's), else every pack at `yield`
function Text.Openable(t, yield)
  local packs = t and t.packs or 0
  if not (t and t.room) or t.room.raw == nil then return 0, packs end
  if t.packList then
    local o = Currency.Openable(t.room, t.packList)
    return o.fitPacks, o.packs
  end
  if t.room.raw == math.huge then return packs, packs end
  return math.min(packs, math.floor(t.room.raw / (yield or 1))), packs
end

-- "your 2 unopened Champion packs can all open" / "1 of your 2 unopened Champion
-- packs can open now and the rest wait"
local function OpenableWords(season, tierKey, t, yield)
  local fit, packs = Text.Openable(t, yield)
  local name = Text.Tier(season, tierKey)
  if fit >= packs then
    return string.format("your %s unopened %s %s can all open", Text.Count(packs), name, Text.Plural(packs, "pack", "packs"))
  end
  return string.format("%s of your %s unopened %s packs can open now and the rest wait", Text.Count(fit), Text.Count(packs), name)
end

-- Whether no more can be bought into a tier now: buying room, after the
-- crests already waiting in unopened packs, is less than a pack
function Text.Capped(t, yield)
  if not (t and t.room) then return false end
  if t.room.raw == nil then return true end
  if t.room.raw == math.huge then return false end
  return t.room.raw - (t.packedCrests or 0) < (yield or 1)
end

-- Why a tier can't take more crests, in full: which cap, how full, what your
-- unopened packs already hold, and when it usually rises. t is the observed
-- tier (obs.tiers[key]); yield is one pack's crests.
function Text.CapSentence(season, tierKey, t, yield)
  local name = Text.Tier(season, tierKey)
  if not (t and t.room) or t.room.raw == nil then
    return string.format("The game isn't reporting %s's cap right now, so nothing is bought into it.", name)
  end
  local words, rises = CapWords(t)
  if not words then return string.format("%s has no cap right now.", name) end
  local raw, free = Rooms(t)
  local packed = t.packedCrests or 0
  if raw <= 0 then
    if HeldCap(t) then return string.format("%s is at %s. Spending some makes room for more.", name, words) end
    if t.room.kind == "weekly" then
      return string.format("%s is at %s. More can be received after the weekly reset.", name, words)
    end
    return string.format("%s is at %s. No more can be received until it rises. %s", name, words, rises)
  end
  if packed > 0 and free < (yield or 1) then
    if raw >= (yield or 1) then
      return string.format("%s has room for %s more under %s, and your unopened %s packs already hold %s of it: %s, but nothing more can be bought until %s.",
        name, Text.Count(raw), words, name, Text.Count(packed), OpenableWords(season, tierKey, t, yield), WaitFor(t))
    end
    return string.format("%s has room for only %s more under %s, less than one pack (%s): your unopened %s packs wait until %s.%s",
      name, Text.Count(raw), words, Text.Count(yield), name, WaitFor(t),
      (HeldCap(t) or t.room.kind == "weekly") and "" or (" " .. rises))
  end
  if yield and free < yield then
    return string.format("%s has room for only %s more under %s, and a pack holds %s. %s", name, Text.Count(free), words,
      Text.Count(yield), rises)
  end
  return string.format("%s has room for %s more under %s.", name, Text.Count(free), words)
end

-- The same, short enough for a route's line (it wraps to two lines)
function Text.CapShort(season, tierKey, t, yield)
  local name = Text.Tier(season, tierKey)
  if not (t and t.room) or t.room.raw == nil then return string.format("The game isn't reporting %s's cap", name) end
  local words = CapWords(t, true)
  if not words then return string.format("%s has no cap", name) end
  local raw, free = Rooms(t)
  local packed = t.packedCrests or 0
  if raw <= 0 then return string.format("%s is at %s", name, words) end
  if packed > 0 and free < (yield or 1) then
    return string.format("Your unopened %s packs already fill the last %s room under the cap", name, Text.Count(raw))
  end
  return string.format("Only %s room left for %s under the cap%s (a pack holds %s)", Text.Count(free), name,
    packed > 0 and " after your unopened packs" or "", Text.Count(yield))
end

-- "your Hero pack" / "your 2 Hero packs"
local function YourPacks(season, tierKey, n)
  if n == 1 then return "your " .. Text.Tier(season, tierKey) .. " pack" end
  return string.format("your %s %s packs", Text.Count(n), Text.Tier(season, tierKey))
end

local function Capital(text)
  return (text:gsub("^%l", string.upper))
end

-- What frees a tier's cap for packs that can't open now, as "until <this>"
local function UntilWords(season, tierKey, t)
  if not (t and t.room) or t.room.raw == nil then
    return string.format("while the game isn't reporting %s's cap", Text.Tier(season, tierKey))
  end
  return "until " .. WaitFor(t)
end

-- A trade short of crests whose source tier holds unopened packs (Task #292):
-- a trade never opens them, so say whether opening them first would pay for
-- it (the plan does that) or the cap keeps them shut, and what frees it.
-- nil when the source tier holds no packs.
local function ShortWithPacks(season, q, obs, base)
  local sp = q.sourcePacks
  if not (sp and sp.packs > 0) then return nil end
  local name = Text.Tier(season, q.sourceTier)
  if sp.fitPacks > 0 then
    local after = math.max(0, q.sourceBefore - (q.reserve or 0)) + sp.fitCrests
    if after >= q.cost then
      local plan = q.direction == "up" and (Seasons.TierIndex(season, q.destTier) or 0) >= 3
      return string.format("Not enough %s until %s %s (+%s): %s", name, YourPacks(season, q.sourceTier, sp.fitPacks),
        Text.Plural(sp.fitPacks, "opens", "open"), Text.Count(sp.fitCrests),
        string.format(plan and "Plan from lower tiers opens %s first" or "open %s first from the first page",
          Text.Plural(sp.fitPacks, "it", "them")))
    end
    return string.format("%s, even with %s from %s", base, Text.Count(sp.fitCrests), YourPacks(season, q.sourceTier, sp.fitPacks))
  end
  return string.format("%s. %s (+%s) %s %s", base, Capital(YourPacks(season, q.sourceTier, sp.packs)), Text.Count(sp.crests),
    Text.Plural(sp.packs, "waits", "wait"), UntilWords(season, q.sourceTier, obs and obs.tiers[q.sourceTier]))
end

-- Packs a plan would use but the cap keeps shut (Plan.Waiting's entry w), in
-- a sentence for the Get page: "Your Hero pack (20 Hero) can't open until the
-- cap rises, so it isn't counted."
function Text.WaitingLine(season, w, t)
  return string.format("%s (%s) can't open %s, so %s counted.", Capital(YourPacks(season, w.tier, w.packs)),
    Text.Crests(season, w.tier, w.crests), UntilWords(season, w.tier, t), w.packs == 1 and "it isn't" or "they aren't")
end

-- Why a trade can give nothing right now, short enough for its route's line.
-- obs (optional) gives the cap's numbers.
function Text.WhyNone(season, q, obs)
  if (q.limiter == "balance" or q.limiter == "reserve") and q.sourceBefore then
    local keep = q.limiter == "reserve" and (" after keeping " .. Text.Count(q.reserve)) or ""
    local base = string.format("Not enough %s: you have %s, a pack costs %s%s", Text.Tier(season, q.sourceTier),
      Text.Count(q.sourceBefore), Text.Count(q.cost), keep)
    return ShortWithPacks(season, q, obs, base) or base
  end
  if q.limiter == "room" or q.limiter == "unknown_room" then
    return Text.CapShort(season, q.destTier, obs and obs.tiers[q.destTier], q.yield)
  end
  if q.limiter == "bags" then return "No free bag space for the pack" end
  if q.limiter == "stock" then return "Vaskarn is out of these packs" end
  return Text.Limiter(q.limiter or "")
end

-- Why a plan can't make more: the reason and the tier it happened in
local PLAN_LIMITER = {
  balance = "not enough spendable crests in the lower tiers",
  room = "no room for more %s crests right now",
  unknown_room = "the game isn't reporting %s's cap",
  unavailable = "Vaskarn isn't offering the trade into %s",
  stock = "Vaskarn is out of %s packs",
  bags = "no bag space for the %s packs",
}
-- away: not at Vaskarn, where a trade not seen yet is unknown rather than missing.
-- obs (optional) gives the cap's numbers for a room limit.
function Text.PlanLimiter(plan, season, away, obs)
  if (plan.limiter == "room" or plan.limiter == "unknown_room") and obs and plan.limitTier then
    local t = obs.tiers[plan.limitTier]
    return Text.CapShort(season, plan.limitTier, t, plan.yield) .. "."
  end
  local text = PLAN_LIMITER[plan.limiter or ""] or "nothing more fits"
  if away and plan.limiter == "unavailable" then
    text = "this character hasn't seen the trade into %s at Vaskarn yet"
  end
  if text:find("%%s") then text = text:format(plan.limitTier and Text.Tier(season, plan.limitTier) or "that tier") end
  return text .. "."
end

-- The one button while the plan waits for Vaskarn, with the player's Interact
-- key; targeted: the key reaches him only once he is targeted (Enable
-- Interact Key is off and the addon may not turn it on)
function Text.TalkKey(name, targeted)
  if targeted then return string.format("Target Vaskarn, then press %s", name) end
  return string.format("Talk to Vaskarn: press %s", name)
end

-- One plan step in words: a trade, or the packs you already have opened
function Text.StepWords(season, step)
  if step.kind == "open" then
    return string.format("open your %s (%s)", Text.Packs(step.packs), Text.Crests(season, step.to, step.packs * step.yield))
  end
  return string.format("%s to %s", Text.Crests(season, step.from, step.spend or step.packs * step.cost),
    Text.Crests(season, step.to, step.packs * step.yield))
end

-- Why the next step of a plan couldn't start
function Text.StepBlocked(reason)
  local map = {
    merchant_closed = "Talk to Vaskarn to buy the next step.",
    offer_changed = "Vaskarn's price for the next step changed since you approved the plan, so nothing more is bought. Discard the order and plan again.",
    combat = "Leave combat to buy the next step.",
    balance = "Not enough crests for the next step: you may have spent some since the plan started.",
    reserve = "Your reserve leaves too few crests for the next step.",
    room = "The next step's crests don't fit under their cap right now: open the packs you have or wait for the cap to rise.",
    unknown_room = "The game isn't reporting the cap for the next step.",
    purchasable = "Vaskarn lists the next step's pack but won't sell it right now (grayed out in his window).",
    unavailable = "Vaskarn isn't offering the next step's trade right now.",
    bags = "Free some bag space for the next step's packs.",
    stock = "Vaskarn is out of the next step's packs.",
  }
  return map[reason] or "The next step can't start right now."
end

function Text.CappedLine(season, tierKey, yield, room)
  local verified = Seasons.CAPABILITIES.capRuleVerified
  return string.format("No room for another %s pack: one holds %s, and only %s room is left after your unopened packs. Buying is paused so you don't end up with a pack that %s.",
    Text.Tier(season, tierKey), Text.Count(yield), Text.Count(room), verified and "won't open" or "may not open")
end

-- A trade down in words: what you give up, for what, one for one, for good.
-- noRefund leaves out the refund sentence (Review says it in its banner)
function Text.DownWarning(season, from, to, spend, receive, noRefund)
  return string.format("Trading down: spend %s to receive %s, a lower tier.%s",
    Text.Crests(season, from, spend), Text.Crests(season, to, receive), noRefund and "" or " It can't be refunded.")
end

-- The same before an amount is set
function Text.DownGeneric(season, from)
  return string.format("Trading down gives up %s, a higher tier, one for one, and can't be refunded.", Text.Tier(season, from))
end

function Text.Direction(q, season)
  if q.direction == "down" then
    if (q.packs or 0) > 0 then return Text.DownWarning(season, q.sourceTier, q.destTier, q.spend, q.crests) end
    return Text.DownGeneric(season, q.sourceTier)
  end
end
