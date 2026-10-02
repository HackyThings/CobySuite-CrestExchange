-------------------------------------------------------------------------------
-- CobysCrestExchange Eligibility: why a trade is missing
--
-- The live merchant list is the authority: an offer that is there is
-- available, whatever a shipped threshold says. A missing trade gets a
-- reason only when one is established:
--   trade up    the "of the Mist" achievement of the tier spent is not
--               earned by this character (completed and wasEarnedByMe), with
--               the gear watermarks by redundancy slot and the game's own
--               incomplete criteria
--   trade down  Vaskarn's Upgrade Practicum quest is not done, with its
--               objective progress
--   otherwise   "not offered", with a hint when the merchant filter is not
--               showing everything
-- Balance never locks a trade; it only makes Max zero.
-------------------------------------------------------------------------------

local Eligibility = {}
CobysCrestExchange.Eligibility = Eligibility

local Seams = CobysCrestExchange.Seams
local U = CobySuite_CobysCrestExchange.Utilities

local function Num(v)
  if Seams.IsSecret(v) or not U.IsFiniteNumber(v) then return nil end
  return v
end

-- Redundancy slots checked for the unlock, lowest first after sorting
local SLOT_ORDER = { "Head", "Neck", "Shoulder", "Cloak", "Chest", "Wrist", "Hand", "Waist", "Legs", "Feet",
  "Finger", "Trinket", "Twohand", "MainhandWeapon", "OnehandWeapon", "OnehandWeaponSecond", "Offhand" }
local WEAPON_SLOTS = { Twohand = true, MainhandWeapon = true, OnehandWeapon = true, OnehandWeaponSecond = true, Offhand = true }

-- The best weapon item level reached: a two-hander, or the lower of the
-- best main-hand and off-hand, whichever is higher (a character that never
-- used a category reads near 0 there, so the unused set must not count)
local function WeaponBest(byName, field)
  local function At(name) local r = byName[name]; return r and r[field] or 0 end
  local pair = math.min(math.max(At("MainhandWeapon"), At("OnehandWeapon")), math.max(At("Offhand"), At("OnehandWeaponSecond")))
  return math.max(At("Twohand"), pair)
end

-- rows { { slot, char, account, ok, weapon } }, weaponsOk, known, weapons
-- (weapons = { char, account }: the best weapon set, see WeaponBest)
function Eligibility.Watermarks(threshold)
  local enum = Seams.Call("RedundancySlots")
  local rows, byName = {}, {}
  if type(enum) ~= "table" then return rows, nil, false end
  for _, name in ipairs(SLOT_ORDER) do
    local value = enum[name]
    if value ~= nil then
      local char, account = Seams.Call("Watermark", value)
      char, account = Num(char), Num(account)
      local row = { slot = name, char = char, account = account, weapon = WEAPON_SLOTS[name] == true,
        ok = char ~= nil and threshold ~= nil and char >= threshold }
      rows[#rows + 1] = row
      byName[name] = row
    end
  end
  local function At(name) local r = byName[name]; return r and r.char or 0 end
  local weaponsOk
  if threshold then
    weaponsOk = At("Twohand") >= threshold
      or (math.max(At("MainhandWeapon"), At("OnehandWeapon")) >= threshold
        and math.max(At("Offhand"), At("OnehandWeaponSecond")) >= threshold)
  end
  table.sort(rows, function(a, b) return (a.char or -1) < (b.char or -1) end)
  local weapons = { char = WeaponBest(byName, "char"), account = WeaponBest(byName, "account") }
  return rows, weaponsOk, true, weapons
end

local function AchievementReason(unlock)
  local name, completed, earnedByMe = Seams.Call("AchievementInfo", unlock.achievementID)
  if name == nil then return nil, "unknown" end
  if completed and earnedByMe then return nil, "earned" end
  local criteria = {}
  local count = Num(Seams.Call("CriteriaCount", unlock.achievementID)) or 0
  for i = 1, math.min(count, 30) do
    local text, done = Seams.Call("CriteriaInfo", unlock.achievementID, i)
    if type(text) == "string" and text ~= "" and not done then criteria[#criteria + 1] = text end
  end
  local rows, weaponsOk, _, weapons = Eligibility.Watermarks(unlock.threshold)
  return {
    kind = "achievement", id = unlock.achievementID, name = name,
    completed = completed == true, earnedByMe = earnedByMe == true,
    threshold = unlock.threshold, watermarks = rows, weaponsOk = weaponsOk, weapons = weapons, criteria = criteria,
  }
end

local function PracticumReason(practicum)
  if Seams.Call("QuestDone", practicum.questID) then return nil end
  local have, need
  local objectives = Seams.Call("QuestObjectives", practicum.questID)
  if type(objectives) == "table" then
    for _, objective in ipairs(objectives) do
      if type(objective) == "table" and Num(objective.numRequired) and objective.numRequired > 0 then
        have, need = Num(objective.numFulfilled), objective.numRequired
        break
      end
    end
  end
  return { kind = "practicum", questID = practicum.questID, inLog = Seams.Call("QuestInLog", practicum.questID) == true,
    have = have, need = need or practicum.need }
end

-- { state = "available"|"locked"|"not_offered"|"unsupported"|"away", reasons = {...} }
function Eligibility.ForTrade(season, product, obs)
  local merchant = obs and obs.merchant
  if merchant and merchant.isExchange and merchant.offers and merchant.offers[product.key] then
    return { state = "available", reasons = {} }
  end
  local reasons = {}
  if product.kind == "up" then
    local unlock = season.unlocks and season.unlocks[product.to]
    if unlock then
      local reason, status = AchievementReason(unlock)
      if reason then
        reasons[#reasons + 1] = reason
        return { state = "locked", reasons = reasons }
      end
      if status == "unknown" then reasons[#reasons + 1] = { kind = "unknown_achievement", id = unlock.achievementID } end
    end
  elseif product.kind == "down" and season.practicum then
    local reason = PracticumReason(season.practicum)
    if reason then
      reasons[#reasons + 1] = reason
      return { state = "locked", reasons = reasons }
    end
  end
  if merchant and merchant.isExchange then
    if not product.itemID then
      -- He may well sell it: an unrecognized pack priced in this trade's
      -- source crest is listed as unsupported, and it can't be bought here
      local from = season.tiers and Eligibility.TierCurrency(season, product.from)
      for _, u in ipairs(merchant.unsupported or {}) do
        local cost = u.costs and u.costs[1]
        if u.reason == "unknown item" and cost and cost.id == from then
          reasons[#reasons + 1] = { kind = "unknown_item", sold = true, itemID = u.itemID }
          return { state = "unsupported", reasons = reasons }
        end
      end
      reasons[#reasons + 1] = { kind = "unknown_item" }
    end
    if merchant.filterAll == false then reasons[#reasons + 1] = { kind = "filter" } end
    return { state = "not_offered", reasons = reasons }
  end
  return { state = "away", reasons = reasons }
end

function Eligibility.TierCurrency(season, tierKey)
  for _, tier in ipairs(season.tiers) do
    if tier.key == tierKey then return tier.currencyID end
  end
end

-- Every trade of the season with its state, for "Why are trades locked?"
function Eligibility.All(season, obs)
  local list = {}
  for _, product in ipairs(season.products) do
    list[#list + 1] = { product = product, result = Eligibility.ForTrade(season, product, obs) }
  end
  return list
end
