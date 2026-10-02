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

local UNKNOWN = "?"

function Text.Count(n)
  if n == nil then return UNKNOWN end
  if n == math.huge then return "no limit" end
  if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
  return tostring(n)
end

function Text.Plural(n, one, many)
  return (n == 1) and one or many
end

function Text.Packs(n)
  return Text.Count(n) .. " " .. Text.Plural(n, "pack", "packs")
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

local LIMIT_KIND = { season = "this season's cap", weekly = "this week's cap" }
function Text.LimitKind(kind) return LIMIT_KIND[kind] or kind end

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
  capped = "These crests are at their cap, so buying stopped before a pack could be wasted.",
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
  merchant_open = "A pack used with a vendor's window open is sold, so the button closes the window first.",
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
-- 800 earned"), and when it usually rises; nil without a cap
local function CapWords(t)
  local room, c = t.room, t.currency
  if room.kind == "weekly" then
    return string.format("this week's cap: %s of %s earned this week", Text.Count(c.earnedThisWeek), Text.Count(c.maxWeekly)),
      "It starts again with the weekly reset."
  end
  if room.kind == "season" then
    if c.useTotalEarned then
      return string.format("its season cap: %s of %s earned", Text.Count(c.totalEarned), Text.Count(c.maxQuantity)),
        "Season caps usually go up with each weekly reset."
    end
    return string.format("its cap: %s of %s held", Text.Count(c.quantity), Text.Count(c.maxQuantity)),
      "Spending some makes room again."
  end
end

-- Two kinds of room: raw room is what the cap still allows (it decides
-- whether a held pack can open); buying room is raw room less the crests
-- already waiting in unopened packs (it decides whether more can be bought)
local function Rooms(t)
  local raw = t.room.raw
  if raw == nil or raw == math.huge then return raw, raw end
  return raw, math.max(0, raw - (t.packedCrests or 0))
end

-- Whether a held pack of `yield` crests can open now (raw room)
function Text.CanOpen(t, yield)
  if not (t and t.room) then return false end
  local raw = Rooms(t)
  return raw ~= nil and raw >= (yield or 1)
end

-- How many of the tier's unopened packs fit the raw room now, of how many
function Text.Openable(t, yield)
  local packs = t and t.packs or 0
  if not (t and t.room) or t.room.raw == nil then return 0, packs end
  if t.room.raw == math.huge then return packs, packs end
  return math.min(packs, math.floor(t.room.raw / (yield or 1))), packs
end

-- "both of your 2 unopened Champion packs" / "1 of your 2 ..." in words
local function OpenableWords(season, tierKey, t, yield)
  local fit, packs = Text.Openable(t, yield)
  local name = Text.Tier(season, tierKey)
  if fit >= packs then
    return string.format("your %s unopened %s %s can all open", Text.Count(packs), name, Text.Plural(packs, "pack", "packs"))
  end
  return string.format("%s of your %s unopened %s packs can open now and the rest wait", Text.Count(fit), Text.Count(packs), name)
end
Text.OpenableWords = OpenableWords

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
    return string.format("%s is at %s. No more can be received until it rises. %s", name, words, rises)
  end
  if packed > 0 and free < (yield or 1) then
    if raw >= (yield or 1) then
      return string.format("%s has room for %s more under %s, and your unopened %s packs already hold %s of it: %s, but nothing more can be bought until the cap rises.",
        name, Text.Count(raw), words, name, Text.Count(packed), OpenableWords(season, tierKey, t, yield))
    end
    return string.format("%s has room for only %s more under %s, less than one pack (%s): your unopened %s packs wait until the cap rises. %s",
      name, Text.Count(raw), words, Text.Count(yield), name, rises)
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
  local words = CapWords(t)
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

-- Why a trade can give nothing right now, short enough for its route's line.
-- obs (optional) gives the cap's numbers.
function Text.WhyNone(season, q, obs)
  if (q.limiter == "balance" or q.limiter == "reserve") and q.sourceBefore then
    local keep = q.limiter == "reserve" and (" after keeping " .. Text.Count(q.reserve)) or ""
    return string.format("Not enough %s: you have %s, a pack costs %s%s", Text.Tier(season, q.sourceTier),
      Text.Count(q.sourceBefore), Text.Count(q.cost), keep)
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
  balance = "not enough crests in the tiers you allowed",
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

-- A trade down in words: what you give up, for what, one for one, for good
function Text.DownWarning(season, from, to, spend, receive)
  return string.format("Trading down: you give up %s, a higher tier, for %s, one for one. It can't be refunded.",
    Text.Crests(season, from, spend), Text.Crests(season, to, receive))
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
