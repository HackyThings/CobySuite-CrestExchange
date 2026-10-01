-------------------------------------------------------------------------------
-- CobysCrestExchange Currency: balances and cap room (pure apart from Read)
--
-- Two limits can apply to a crest currency, and room is the smaller:
--   season  maxQuantity > 0: used = totalEarned when useTotalEarnedForMaxQty
--           (a season total that grows each week), else the balance;
--           room = maxQuantity - used (Blizzard's WillCurrencyRewardOverflow
--           does the same)
--   weekly  canEarnPerWeek and maxWeeklyQuantity > 0:
--           room = maxWeeklyQuantity - quantityEarnedThisWeek
-- A zero maximum means no limit. Missing or unreadable data means unknown,
-- never unlimited.
--
-- Raw room decides whether a pack already held can open (its yield against
-- actual room). Uncommitted room, raw minus crests already waiting in
-- unopened packs and in unsettled purchases or opens, decides how much more
-- to buy. The two are never subtracted twice.
-------------------------------------------------------------------------------

local Currency = {}
CobysCrestExchange.Currency = Currency

local U = CobySuite_CobysCrestExchange.Utilities
local Seams = CobysCrestExchange.Seams
local INF = math.huge

local function Num(value)
  if Seams.IsSecret(value) or not U.IsFiniteNumber(value) then return nil end
  return value
end

-- A plain copy of the fields we use, or { ok = false }
function Currency.Read(currencyID)
  local info = Seams.Call("CurrencyInfo", currencyID)
  if type(info) ~= "table" then return { ok = false, id = currencyID } end
  local quantity = Num(info.quantity)
  if quantity == nil then return { ok = false, id = currencyID } end
  local name = info.name
  if Seams.IsSecret(name) or type(name) ~= "string" then name = nil end
  return {
    ok = true,
    id = currencyID,
    name = name,
    icon = not Seams.IsSecret(info.iconFileID) and info.iconFileID or nil,
    quantity = quantity,
    maxQuantity = Num(info.maxQuantity) or 0,
    useTotalEarned = info.useTotalEarnedForMaxQty == true,
    totalEarned = Num(info.totalEarned),
    canEarnPerWeek = info.canEarnPerWeek == true,
    maxWeekly = Num(info.maxWeeklyQuantity) or 0,
    earnedThisWeek = Num(info.quantityEarnedThisWeek),
    discovered = info.discovered == true,
  }
end

-- { raw, kind = "season"|"weekly"|"none"|"unknown", season, weekly }
function Currency.Room(c)
  if type(c) ~= "table" or not c.ok then
    return { raw = nil, kind = "unknown" }
  end
  local season, weekly
  if c.maxQuantity > 0 then
    local used = c.useTotalEarned and c.totalEarned or c.quantity
    if used == nil then return { raw = nil, kind = "unknown" } end
    season = math.max(0, c.maxQuantity - used)
  end
  if c.canEarnPerWeek and c.maxWeekly > 0 then
    if c.earnedThisWeek == nil then return { raw = nil, kind = "unknown" } end
    weekly = math.max(0, c.maxWeekly - c.earnedThisWeek)
  end
  if season == nil and weekly == nil then
    return { raw = INF, kind = "none" }
  end
  if weekly ~= nil and (season == nil or weekly < season) then
    return { raw = weekly, kind = "weekly", season = season, weekly = weekly }
  end
  return { raw = season, kind = "season", season = season, weekly = weekly }
end

-- Room left for more buying: nil when unknown, math.huge when unlimited
function Currency.Uncommitted(room, packedCrests, unsettledCrests)
  if not room or room.raw == nil then return nil end
  if room.raw == INF then return INF end
  return math.max(0, room.raw - (packedCrests or 0) - (unsettledCrests or 0))
end

-- Would one pack of yield crests fit the raw room right now?
function Currency.PackFits(room, yield)
  if not room or room.raw == nil then return false end
  return room.raw >= yield
end
