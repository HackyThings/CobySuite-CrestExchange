-------------------------------------------------------------------------------
-- CobysCrestExchange Seasons: the one table that changes each season
--
-- Everything the exchange needs that the game does not say through its API:
-- which currencies make up the crest ladder and in what order, which packs
-- the exchange vendor sells and what each one holds, which achievements and
-- quest unlock the trades, and the verified-behavior flags. Prices, per
-- purchase limits, balances and caps are always read live, never stored here.
--
-- The verification fields and the notes below record what the Vaskarn dump
-- confirmed: the season and the packs are marked verified; Adventurer of the
-- Mist's achievement ID remains marked candidate. A wrong item ID only makes an offer show as
-- unsupported, and a wrong achievement ID only loses the reason shown for a
-- locked trade; nothing is bought on the strength of this table alone, since
-- an offer must also match the live merchant's cost signature.
--
-- CAPABILITIES are the behaviors the in-game Exchange Check settles (named
-- by its tests in Tests/Suites/ExchangeCheckSuite.lua):
--   buyFromAddon       BuyMerchantItem works from our own button ("Buy one
--                      pack from an addon button")
--   chunkWithoutPress  a follow-up purchase works from a timer ("Buy from a
--                      timer after a press")
--   openAtVendor       using a pack by item ID opens it, not sells it, while
--                      a merchant window is open ("Open one pack at Vaskarn:
--                      opens or sells?", the sell test)
--   autoOpenAfterClose packs open from plain code after the vendor closes
--                      ("Open one pack from a timer, no press")
--   capRuleVerified    how packs meet the destination cap is known (the two
--                      "Currency and cap fields" reads, before and after); it
--                      only changes the wording from "may not open" to "won't
--                      open": a pack is always bought only when its whole
--                      yield fits
-------------------------------------------------------------------------------

local Seasons = {}
CobysCrestExchange.Seasons = Seasons

Seasons.CAPABILITIES = {
  buyFromAddon       = true,
  chunkWithoutPress  = true,
  openAtVendor       = false,
  autoOpenAfterClose = false,
  capRuleVerified    = false,
}

-- Tier keys in ladder order, lowest first
Seasons.TIER_ORDER = { "adventurer", "veteran", "champion", "hero", "myth" }

Seasons.LIST = {
  {
    key = "midnight-s2",
    label = "Mistcrests",
    interface = { min = 120100, max = 129999 },
    -- Verified from /ce dump at Vaskarn, 2026-09-30 (client 12.1.0.69933): the
    -- NPC, all five currencies (season caps of 800 for Adventurer to
    -- Champion and 700 for Hero and Myth, counted on total earned, no weekly
    -- cap), all eight packs (up to 50 per purchase), and three of the four
    -- unlock achievements
    verification = "verified",
    vendorNPCs = { [239676] = "Vaskarn" },
    tiers = {
      { key = "adventurer", label = "Adventurer", currencyID = 3442, quality = 1 },
      { key = "veteran",    label = "Veteran",    currencyID = 3443, quality = 2 },
      { key = "champion",   label = "Champion",   currencyID = 3444, quality = 3 },
      { key = "hero",       label = "Hero",       currencyID = 3445, quality = 4 },
      { key = "myth",       label = "Myth",       currencyID = 3446, quality = 5 },
    },
    -- kind "up" trades three of a tier for one of the next (30 for a pack of
    -- 10); "down" trades one for one into the tier below (10 for a pack of 10).
    -- countsTowardEarningLimit and requiresOpeningHeadroom stay true (the
    -- conservative policy).
    products = {
      -- Verified at Vaskarn 2026-09-30 (the first in-game visit): each 30 of its
      -- source crest for a pack of 10, NPC 239676, source currencies 3442 to 3445
      { key = "up-veteran",  itemID = 269867, kind = "up", from = "adventurer", to = "veteran",  yield = 10, verification = "verified" },
      { key = "up-champion", itemID = 269864, kind = "up", from = "veteran",    to = "champion", yield = 10, verification = "verified" },
      { key = "up-hero",     itemID = 269865, kind = "up", from = "champion",   to = "hero",     yield = 10, verification = "verified" },
      { key = "up-myth",     itemID = 269866, kind = "up", from = "hero",       to = "myth",     yield = 10, verification = "verified" },
      -- Verified from the same dump: each 10 of the tier above for a pack of 10
      { key = "down-adventurer", itemID = 269856, kind = "down", from = "veteran",  to = "adventurer", yield = 10, verification = "verified" },
      { key = "down-veteran",    itemID = 269859, kind = "down", from = "champion", to = "veteran",    yield = 10, verification = "verified" },
      { key = "down-champion",   itemID = 269857, kind = "down", from = "hero",     to = "champion",   yield = 10, verification = "verified" },
      { key = "down-hero",       itemID = 269858, kind = "down", from = "myth",     to = "hero",       yield = 10, verification = "verified" },
    },
    -- Trading up INTO a tier needs the "of the Mist" achievement of the tier
    -- below: every gear slot's high watermark at that track's top item level.
    -- Verified by name in the dump: 62411 Veteran of the Mist, 62412
    -- Champion of the Mist, 62414 Hero of the Mist (62413 is not one of
    -- them). Adventurer of the Mist's ID is a guess: a wrong one only means
    -- no reason is shown for a locked Adventurer to Veteran trade.
    unlocks = {
      veteran  = { achievementID = 62410, threshold = 282, verification = "candidate" },
      champion = { achievementID = 62411, threshold = 295 },
      hero     = { achievementID = 62412, threshold = 308 },
      myth     = { achievementID = 62414, threshold = 321 },
    },
    -- Trading down needs Vaskarn's quest
    practicum = { questID = 96635, need = 50 },
  },
}

-- Fill the defaults every product shares, once, at load
for _, season in ipairs(Seasons.LIST) do
  for _, product in ipairs(season.products) do
    if product.countsTowardEarningLimit == nil then product.countsTowardEarningLimit = true end
    if product.requiresOpeningHeadroom == nil then product.requiresOpeningHeadroom = true end
    product.verification = product.verification or "candidate"
  end
end

-------------------------------------------------------------------------------
-- Lookups (pure)
-------------------------------------------------------------------------------
function Seasons.Tier(season, tierKey)
  for index, tier in ipairs(season.tiers) do
    if tier.key == tierKey then return tier, index end
  end
end

function Seasons.TierIndex(season, tierKey)
  local _, index = Seasons.Tier(season, tierKey)
  return index
end

function Seasons.TierByCurrency(season, currencyID)
  for _, tier in ipairs(season.tiers) do
    if tier.currencyID == currencyID then return tier end
  end
end

function Seasons.ProductByKey(season, key)
  for _, product in ipairs(season.products) do
    if product.key == key then return product end
  end
end

function Seasons.ProductByItem(season, itemID)
  if not itemID then return nil end
  for _, product in ipairs(season.products) do
    if product.itemID == itemID then return product end
  end
end

-- The trades that end in tierKey: usually one up from below, one down from above
function Seasons.TradesInto(season, tierKey)
  local list = {}
  for _, product in ipairs(season.products) do
    if product.to == tierKey then list[#list + 1] = product end
  end
  table.sort(list, function(a, b) return a.kind == "up" and b.kind ~= "up" end)
  return list
end

-- Is this currency one of the season's crests?
function Seasons.IsCrestCurrency(season, currencyID)
  return Seasons.TierByCurrency(season, currencyID) ~= nil
end

-- The season in force for this client, or nil (read-only diagnostics then).
-- interfaceVersion comes from Seams (GetBuildInfo's fourth return).
function Seasons.Active(interfaceVersion)
  if type(interfaceVersion) ~= "number" then return nil end
  for _, season in ipairs(Seasons.LIST) do
    local range = season.interface
    if interfaceVersion >= range.min and interfaceVersion <= range.max then
      return season
    end
  end
end
