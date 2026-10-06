-------------------------------------------------------------------------------
-- CobysCrestExchange Observer: one event frame, one observation snapshot
--
-- Game data events mark the snapshot stale; a coalesced rebuild (0.1 s) reads
-- the merchant (only at an exchange vendor), every crest currency, the packs
-- in the bags and bag space, then fires ObservationsChanged(obs). Each
-- snapshot carries a version number.
--
--   obs = { version, at, season, inCombat,
--     merchant = { open, isExchange, npcID, vendorName, inInstance, filterAll,
--                  slotCount, offers = { [key] = Offer }, unsupported, readAt },
--     tiers = { [tierKey] = { tier, index, currency, room, packs, packedCrests } },
--     packs = { [productKey] = count }, packSpace = { [productKey] = n },
--     lastSeen = Store offers (for the away view) }
--
-- Loot, error, combat and blocked-action events are also forwarded to Session
-- (Session.OnGameEvent) with their payloads.
-------------------------------------------------------------------------------

local Observer = {}
CobysCrestExchange.Observer = Observer

local Seams = CobysCrestExchange.Seams
local Merchant = CobysCrestExchange.Merchant
local Currency = CobysCrestExchange.Currency
local Inventory = CobysCrestExchange.Inventory
local Store = CobysCrestExchange.Store
local U = CobySuite_CobysCrestExchange.Utilities

local S = {
  season = nil,
  version = 0,
  obs = nil,
  merchant = { open = false, isExchange = false, offers = {}, unsupported = {}, slotCount = 0 },
  frame = nil,
}

local DATA_EVENTS = {
  "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_FILTER_ITEM_UPDATE", "MERCHANT_CLOSED",
  "CURRENCY_DISPLAY_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "PLAYER_ENTERING_WORLD",
  "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "PLAYER_EQUIPMENT_CHANGED",
}
local SESSION_EVENTS = {
  "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "UI_ERROR_MESSAGE",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}

local function Fire(event, ...)
  CobysCrestExchange.EventBus:Fire(event, ...)
end

-------------------------------------------------------------------------------
-- Building the snapshot
-------------------------------------------------------------------------------
local function ReadMerchant(season)
  local m = S.merchant
  if not (m.open and m.isExchange and season) then
    m.offers, m.unsupported, m.slotCount = {}, {}, 0
    return
  end
  local slots = Merchant.ReadAll()
  m.offers, m.unsupported = Merchant.Classify(slots, season)
  m.slotCount = #slots
  m.filterAll = Merchant.FilterIsAll()
  m.readAt = Seams.Call("Now")
  local list = {}
  for key, offer in pairs(m.offers) do
    list[#list + 1] = { key = key, itemID = offer.itemID, sourceCurrencyID = offer.sourceCurrencyID,
      costPerUnit = offer.costPerUnit, yieldPerUnit = offer.yieldPerUnit }
  end
  if #list > 0 then Store.SaveOffers(list, m.npcID) end
end

local function ReadTiers(season, packs)
  local tiers = {}
  for index, tier in ipairs(season.tiers) do
    local currency = Currency.Read(tier.currencyID)
    local packed, count = 0, 0
    for _, product in ipairs(season.products) do
      if product.to == tier.key then
        local n = packs[product.key] or 0
        count = count + n
        if product.countsTowardEarningLimit ~= false then packed = packed + n * product.yield end
      end
    end
    tiers[tier.key] = { tier = tier, index = index, currency = currency, room = Currency.Room(currency),
      packs = count, packedCrests = packed }
  end
  return tiers
end

function Observer.Rebuild()
  local season = S.season
  S.version = S.version + 1
  local obs = { version = S.version, at = Seams.Call("Now") or 0, season = season,
    inCombat = Seams.Call("InCombat") == true, merchant = S.merchant, tiers = {}, packs = {}, packSpace = {} }
  if season then
    ReadMerchant(season)
    obs.packs = Inventory.Counts(season)
    for _, product in ipairs(season.products) do
      if product.itemID then obs.packSpace[product.key] = Inventory.PackSpace(product.itemID) end
    end
    obs.tiers = ReadTiers(season, obs.packs)
    obs.lastSeen = Store.GetOffers()
  end
  S.obs = obs
  Fire(CobysCrestExchange.Events.ObservationsChanged, obs)
  return obs
end

local coalesced = U.Coalesce(0.1, function() Observer.Rebuild() end)

function Observer.Invalidate()
  coalesced:Call()
end

function Observer.Current()
  return S.obs or Observer.Rebuild()
end

function Observer.Season()
  return S.season
end

-------------------------------------------------------------------------------
-- Merchant lifecycle
-------------------------------------------------------------------------------
local function OnMerchantShow()
  local id = Merchant.Identify(S.season)
  local m = S.merchant
  m.open, m.npcID, m.vendorName, m.inInstance = true, id.npcID, id.vendorName, id.inInstance
  m.isExchange = id.isExchange and not id.inInstance
  CobysCrestExchange.Debug.Log("MERCHANT", "Merchant shown: npc %s, exchange %s", tostring(id.npcID), tostring(m.isExchange))
  coalesced:Cancel()
  Observer.Rebuild()
  Fire(CobysCrestExchange.Events.MerchantChanged, m.isExchange and "exchange" or "other", m.npcID)
end

local function OnMerchantClosed()
  local m = S.merchant
  if not m.open then return end
  m.open, m.isExchange = false, false
  CobysCrestExchange.Debug.Log("MERCHANT", "Merchant closed")
  coalesced:Cancel()
  Observer.Rebuild()
  Fire(CobysCrestExchange.Events.MerchantChanged, "closed", m.npcID)
end

local function OnEvent(_, event, ...)
  if event == "MERCHANT_SHOW" then
    OnMerchantShow()
  elseif event == "MERCHANT_CLOSED" then
    OnMerchantClosed()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if S.merchant.open and not Seams.Call("MerchantShown") then OnMerchantClosed() end
    Observer.Invalidate()
  else
    local Session = CobysCrestExchange.Session
    if Session and Session.WantsGameEvent(event) then Session.OnGameEvent(event, ...) end
    Observer.Invalidate()
  end
end

-- Called once at login, after the season is known
function Observer.Start(season)
  S.season = season
  if S.frame then return end
  S.frame = CreateFrame("Frame")
  for _, event in ipairs(DATA_EVENTS) do S.frame:RegisterEvent(event) end
  for _, event in ipairs(SESSION_EVENTS) do S.frame:RegisterEvent(event) end
  S.frame:SetScript("OnEvent", OnEvent)
  if Seams.Call("MerchantShown") then OnMerchantShow() else Observer.Rebuild() end
end

-- Tests only
Observer._test = {
  SetSeason = function(season) local previous = S.season; S.season = season; return previous end,
  SetMerchant = function(state)
    local previous = S.merchant
    S.merchant = state
    return function() S.merchant = previous end
  end,
}
