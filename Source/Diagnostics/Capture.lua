-------------------------------------------------------------------------------
-- CobysCrestExchange Capture: /ce dump, a read-only diagnostic report
--
-- Ships with the addon: a player can copy it into a bug report, and the
-- first visit to Vaskarn settles the season table's unknowns from it (every
-- merchant slot with its costs, the currencies and their cap fields, packs in
-- the bags, achievements, the Practicum quest, watermarks, the session). For
-- each crest-priced offer the season table does not recognize, it prints a
-- ready product line.
--
-- It only reads. It never buys, opens, changes the merchant filter or
-- targets anything.
-------------------------------------------------------------------------------

local Capture = {}
CobysCrestExchange.Capture = Capture

local Seams = CobysCrestExchange.Seams
local Seasons = CobysCrestExchange.Seasons
local Merchant = CobysCrestExchange.Merchant
local Currency = CobysCrestExchange.Currency
local Inventory = CobysCrestExchange.Inventory
local Eligibility = CobysCrestExchange.Eligibility

local function V(value)
  if value == nil then return "nil" end
  if Seams.IsSecret(value) then return "secret" end
  return tostring(value)
end

local function Section(lines, title)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "== " .. title .. " =="
end

local function Header(lines, season)
  local version, build = Seams.Call("Build")
  lines[#lines + 1] = "Coby's Crest Exchange diagnostics"
  lines[#lines + 1] = string.format("Addon %s | client %s (%s) | interface %s | locale %s | time %s",
    V(CobysCrestExchange.VERSION), V(version), V(build), V(Seams.Call("Interface")), V(Seams.Call("Locale")),
    V(Seams.Call("Time")))
  lines[#lines + 1] = "Season: " .. (season and (season.key .. " (" .. season.verification .. ")") or "unknown")
  local caps = {}
  for key, value in pairs(Seasons.CAPABILITIES) do caps[#caps + 1] = key .. "=" .. tostring(value) end
  table.sort(caps)
  lines[#lines + 1] = "Capabilities: " .. table.concat(caps, " ")
end

local function CostText(costs)
  local parts = {}
  for _, cost in ipairs(costs or {}) do
    parts[#parts + 1] = string.format("%s %s x%s", cost.kind, V(cost.id), V(cost.amount))
  end
  return #parts > 0 and table.concat(parts, ", ") or "none"
end

local function MerchantSection(lines, season)
  Section(lines, "Merchant")
  local id = Merchant.Identify(season)
  lines[#lines + 1] = string.format("Shown %s | npc %s | exchange %s (%s) | instance %s | filter %s (all = %s)",
    V(Seams.Call("MerchantShown")), V(id.npcID), V(id.isExchange), V(id.vendorName), V(id.inInstance),
    V(Seams.Call("Filter")), V(Seams.Call("FilterAllValue")))
  if not Seams.Call("MerchantShown") then
    lines[#lines + 1] = "(open a merchant window to list its slots)"
    return
  end
  local slots = Merchant.ReadAll()
  for _, slot in ipairs(slots) do
    lines[#lines + 1] = string.format("[%d] item %s %q | price %s | stack %s | avail %s | maxStack %s | buyable %s | refundable %s | sells currency %s | costs: %s%s",
      slot.index, V(slot.itemID), tostring(slot.name or "?"), V(slot.price), V(slot.stackCount), V(slot.numAvailable),
      V(slot.maxStack), V(slot.isPurchasable), V(slot.refundable), V(slot.currencyIDSold), CostText(slot.costs),
      slot.complete and "" or " | INCOMPLETE")
  end
  if not season then return end
  local offers, unsupported = Merchant.Classify(slots, season)
  for key, offer in pairs(offers) do
    lines[#lines + 1] = string.format("Recognized %s: item %d, %d x currency %d for %d crests | signature %s",
      key, offer.itemID, offer.costPerUnit, offer.sourceCurrencyID, offer.yieldPerUnit, offer.signature)
  end
  for _, u in ipairs(unsupported) do
    lines[#lines + 1] = string.format("Unsupported [%d] item %s %q: %s | costs: %s", u.index, V(u.itemID),
      tostring(u.name or "?"), u.reason, CostText(u.costs))
    local cost = u.costs and u.costs[1]
    local fromTier = cost and cost.id and Seasons.TierByCurrency(season, cost.id)
    if u.reason == "unknown item" and fromTier then
      lines[#lines + 1] = string.format('  candidate: { key = "?", itemID = %s, kind = "?", from = "%s", to = "?", yield = 10 },  -- costs %s x currency %s',
        V(u.itemID), fromTier.key, V(cost.amount), V(cost.id))
    end
  end
end

local function CurrencySection(lines, season)
  Section(lines, "Currencies")
  for _, tier in ipairs(season.tiers) do
    local c = Currency.Read(tier.currencyID)
    local room = Currency.Room(c)
    lines[#lines + 1] = string.format("%s %d %q: ok %s | qty %s | max %s | useTotalEarned %s | totalEarned %s | perWeek %s | maxWeekly %s | earnedWeek %s | room %s (%s)",
      tier.label, tier.currencyID, tostring(c.name or "?"), V(c.ok), V(c.quantity), V(c.maxQuantity), V(c.useTotalEarned),
      V(c.totalEarned), V(c.canEarnPerWeek), V(c.maxWeekly), V(c.earnedThisWeek), V(room.raw), room.kind)
  end
end

local function PackSection(lines, season)
  Section(lines, "Packs in bags")
  for _, product in ipairs(season.products) do
    if product.itemID then
      local rows = Inventory.Describe(product.itemID)
      local detail = {}
      for _, r in ipairs(rows) do
        detail[#detail + 1] = string.format("%d/%d x%s%s%s%s", r.bag, r.slot, V(r.count), r.locked and " locked" or "",
          r.hasLoot and " loot" or "", r.bound and " bound" or "")
      end
      lines[#lines + 1] = string.format("%s item %d: count %s | bind %s | %s", product.key, product.itemID,
        V(Seams.Call("ItemCount", product.itemID)), V(Seams.Call("ItemBindType", product.itemID)),
        #detail > 0 and table.concat(detail, ", ") or "none")
    else
      lines[#lines + 1] = product.key .. ": item ID unknown"
    end
  end
end

local function UnlockSection(lines, season)
  Section(lines, "Unlocks")
  for _, tierKey in ipairs(Seasons.TIER_ORDER) do
    local unlock = season.unlocks[tierKey]
    if unlock then
      local name, completed, earnedByMe = Seams.Call("AchievementInfo", unlock.achievementID)
      lines[#lines + 1] = string.format("Into %s: achievement %d %q completed %s earnedByMe %s threshold %d",
        tierKey, unlock.achievementID, tostring(name or "?"), V(completed), V(earnedByMe), unlock.threshold)
    end
  end
  if season.practicum then
    local q = season.practicum
    local objectives = Seams.Call("QuestObjectives", q.questID)
    local parts = {}
    if type(objectives) == "table" then
      for _, o in ipairs(objectives) do
        parts[#parts + 1] = string.format("%q %s/%s", tostring(o.text or "?"), V(o.numFulfilled), V(o.numRequired))
      end
    end
    lines[#lines + 1] = string.format("Practicum quest %d: done %s | in log %s | %s", q.questID,
      V(Seams.Call("QuestDone", q.questID)), V(Seams.Call("QuestInLog", q.questID)), table.concat(parts, "; "))
  end
  local rows = Eligibility.Watermarks(nil)
  local parts = {}
  for _, r in ipairs(rows) do parts[#parts + 1] = string.format("%s %s/%s", r.slot, V(r.char), V(r.account)) end
  lines[#lines + 1] = "Watermarks (character/account): " .. table.concat(parts, ", ")
end

local function SessionSection(lines)
  Section(lines, "Session")
  local Session = CobysCrestExchange.Session
  local view = Session and Session.View() or {}
  lines[#lines + 1] = string.format("State %s | notice %s | reason %s | needsPress %s | advisorOnly %s | auto %s",
    V(view.state), V(view.notice), V(view.reason), V(view.needsPress), V(view.advisorOnly), V(view.auto))
  local o, l = view.order, view.ledger
  if o and l then
    lines[#lines + 1] = string.format("Order %s %s item %s: approved %d, cost %d, yield %d | bought %d spent %d opened %d received %d quota %d | attempt %s",
      o.kind, o.key, V(o.itemID), o.approvedPacks, o.cost, o.yield, l.purchased, l.spent, l.opened, l.received,
      l.openQuota or 0, l.attempt and (l.attempt.packs .. " packs") or "none")
  end
end

local function NeighbourSection(lines)
  local names = { "CrestXmutePanel" }
  local shown = {}
  for _, name in ipairs(names) do
    local frame = _G[name]
    if frame and frame.IsShown and frame:IsShown() then shown[#shown + 1] = name end
  end
  lines[#lines + 1] = "Neighbor panels shown: " .. (#shown > 0 and table.concat(shown, ", ") or "none")
end

function Capture.Build()
  local season = CobysCrestExchange.Observer.Season()
  local lines = {}
  local steps = { Header, MerchantSection }
  for _, step in ipairs(steps) do step(lines, season) end
  if season then
    CurrencySection(lines, season)
    PackSection(lines, season)
    UnlockSection(lines, season)
  end
  SessionSection(lines)
  NeighbourSection(lines)
  return table.concat(lines, "\n")
end

function Capture.Show()
  local ok, text = pcall(Capture.Build)
  if not ok then text = "The report could not be built: " .. tostring(text) end
  CobysCrestExchange.Store.SaveCapture(text)
  CobysCrestExchange.Debug.Log("DIAG", "Diagnostics captured (%d characters)", #text)
  local window = CobysCrestExchange.DebugWindow
  if window then
    window:Show()
    window:ShowCopyBox(text)
  end
  return text
end
