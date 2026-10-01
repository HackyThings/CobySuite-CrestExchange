-------------------------------------------------------------------------------
-- CobysCrestExchange Quote: what an exchange would spend and give (pure)
--
-- Quote.Build(obs, sel, opts)
--   sel  = { productKey, crests }            crests = how many to receive
--   opts = { reserve, unsettled = { [tierKey] = crests }, capPacks, planning }
--
-- Max packs is the smallest of these limits, and the quote names the one
-- that binds (limiter), so the Max button's tooltip can say why:
--   purchasable  the merchant marks the offer unavailable
--   balance      source crests after the reserve, divided by the price
--                ("reserve" when the reserve is what cut it)
--   room         uncommitted destination room divided by the pack's yield
--                (the full-yield policy); unknown room allows nothing
--   stock        the merchant's limited stock, when it has one
--   bags         space for more packs
--   resume       what is left of a paused order's approved amount
--
-- An amount that is not a whole number of packs is never rounded silently:
-- status "rounding" offers the pack amount below and above (the one above
-- only when it fits Max).
-------------------------------------------------------------------------------

local Quote = {}
CobysCrestExchange.Quote = Quote

local Seasons = CobysCrestExchange.Seasons
local Currency = CobysCrestExchange.Currency
local INF = math.huge

-- Ties go to the most basic cause: a tier at its cap is the reason even when
-- Vaskarn also greys the trade out (he does once the cap is reached)
local TIE_ORDER = { "unknown_room", "room", "purchasable", "reserve", "balance", "stock", "bags", "resume" }

-- The offer to quote: the live one at the vendor, else the last one seen there
local function FindOffer(obs, productKey, planning)
  local live = obs.merchant and obs.merchant.isExchange and obs.merchant.offers and obs.merchant.offers[productKey]
  if live and not planning then return live, false end
  if live then return live, true end
  local seen = obs.lastSeen and obs.lastSeen.list
  if seen then
    for _, entry in ipairs(seen) do
      if entry.key == productKey then
        return { key = entry.key, itemID = entry.itemID, sourceCurrencyID = entry.sourceCurrencyID,
          costPerUnit = entry.costPerUnit, yieldPerUnit = entry.yieldPerUnit, maxStack = 1, numAvailable = -1,
          isPurchasable = true, refundable = false, signature = "seen" }, true
      end
    end
  end
  return nil, true
end

local function Limits(obs, offer, src, dst, opts, productKey)
  local limits = {}
  local cost, yield = offer.costPerUnit, offer.yieldPerUnit
  if offer.isPurchasable == false then limits.purchasable = 0 end
  local held = src.currency.ok and src.currency.quantity or 0
  local reserve = opts.reserve or 0
  local afterReserve = math.floor(math.max(0, held - reserve) / cost)
  if reserve > 0 and math.floor(held / cost) > afterReserve then
    limits.reserve = afterReserve
  else
    limits.balance = afterReserve
  end
  local unsettled = opts.unsettled and opts.unsettled[dst.tier.key] or 0
  local uncommitted = Currency.Uncommitted(dst.room, dst.packedCrests, unsettled)
  if uncommitted == nil then
    limits.unknown_room = 0
  elseif uncommitted ~= INF then
    limits.room = math.floor(uncommitted / yield)
  end
  if type(offer.numAvailable) == "number" and offer.numAvailable >= 0 then limits.stock = offer.numAvailable end
  local space = obs.packSpace and obs.packSpace[productKey]
  if space then limits.bags = space end
  if opts.capPacks then limits.resume = opts.capPacks end
  return limits, uncommitted
end

local function Smallest(limits)
  local best, name = INF, nil
  for _, key in ipairs(TIE_ORDER) do
    local value = limits[key]
    if value ~= nil and value < best then best, name = value, key end
  end
  if best == INF then best = 0 end
  return math.max(0, best), name
end

local function AmountStatus(crests, yield, maxPacks)
  if crests == nil then return "empty" end
  if type(crests) ~= "number" or crests ~= math.floor(crests) or crests <= 0 then return "invalid" end
  if crests % yield ~= 0 then
    local down = math.floor(crests / yield) * yield
    local up = math.ceil(crests / yield) * yield
    return "rounding", { down = down > 0 and down or nil, up = (up / yield <= maxPacks) and up or nil }
  end
  if crests / yield > maxPacks then return "too_many" end
  return "ok"
end

local function Problems(obs, q, dst)
  local list = {}
  if q.limiter == "unknown_room" then list[#list + 1] = { kind = "unknown_room" } end
  if q.limiter == "room" and q.maxPacks == 0 then
    list[#list + 1] = { kind = "capped", room = q.uncommitted, yield = q.yield }
  end
  if (q.limiter == "balance" or q.limiter == "reserve") and q.maxPacks == 0 then
    list[#list + 1] = { kind = "balance", need = q.cost }
  end
  if (dst.packs or 0) > 0 then list[#list + 1] = { kind = "existing_packs", packs = dst.packs } end
  if q.planning then list[#list + 1] = { kind = "not_at_vendor" } end
  if obs.inCombat then list[#list + 1] = { kind = "combat" } end
  return list
end

function Quote.Build(obs, sel, opts)
  opts = opts or {}
  local season = obs and obs.season
  if not season or not sel or not sel.productKey then return { status = "none" } end
  local product = Seasons.ProductByKey(season, sel.productKey)
  if not product then return { status = "none" } end
  local offer, planning = FindOffer(obs, sel.productKey, opts.planning)
  if not offer then return { status = "unavailable", key = sel.productKey, product = product } end
  local src, dst = obs.tiers[product.from], obs.tiers[product.to]
  if not src or not dst then return { status = "none" } end

  local limits, uncommitted = Limits(obs, offer, src, dst, opts, sel.productKey)
  local maxPacks, limiter = Smallest(limits)
  local yield, cost = offer.yieldPerUnit, offer.costPerUnit
  local status, rounding = AmountStatus(sel.crests, yield, maxPacks)
  local packs = (status == "ok") and (sel.crests / yield) or 0
  local q = {
    status = status, rounding = rounding, key = sel.productKey, product = product, offer = offer,
    direction = product.kind, sourceTier = product.from, destTier = product.to, itemID = offer.itemID,
    yield = yield, cost = cost, packs = packs, crests = packs * yield, spend = packs * cost,
    maxPacks = maxPacks, maxCrests = maxPacks * yield, limiter = limiter, limits = limits,
    reserve = opts.reserve or 0, planning = planning, obsVersion = obs.version,
    sourceBefore = src.currency.ok and src.currency.quantity or nil,
    destBefore = dst.currency.ok and dst.currency.quantity or nil,
    roomRaw = dst.room.raw, roomKind = dst.room.kind, uncommitted = uncommitted,
    refundable = offer.refundable == true, signature = offer.signature,
  }
  q.sourceAfter = q.sourceBefore and (q.sourceBefore - q.spend) or nil
  q.destAfterOpen = q.destBefore and (q.destBefore + q.crests) or nil
  if uncommitted and uncommitted ~= INF then q.roomAfter = math.max(0, uncommitted - q.crests) end
  q.problems = Problems(obs, q, dst)
  q.fingerprint = table.concat({ q.key, packs, q.spend, q.crests, cost, tostring(offer.signature) }, "|")
  return q
end

-- A quote with no amount, for "up to N now" lines
function Quote.MaxFor(obs, productKey, opts)
  return Quote.Build(obs, { productKey = productKey }, opts)
end

-------------------------------------------------------------------------------
-- Controller: rebuilds the current quote and fires QuoteChanged
-------------------------------------------------------------------------------
local C = { selection = nil, quote = nil }
Quote.Controller = C

function C.Options(obs, product)
  local Session, Store = CobysCrestExchange.Session, CobysCrestExchange.Store
  local src = obs.season and Seasons.Tier(obs.season, product.from)
  return {
    reserve = src and Store.GetReserve(src.currencyID) or 0,
    unsettled = Session and Session.Unsettled(obs) or {},
    capPacks = C.selection and C.selection.capPacks or nil,
    planning = not (obs.merchant and obs.merchant.isExchange),
  }
end

function C.Refresh()
  local Observer = CobysCrestExchange.Observer
  local sel = C.selection
  if not sel or not sel.productKey then
    C.quote = nil
  else
    local obs = Observer.Current()
    local product = obs.season and Seasons.ProductByKey(obs.season, sel.productKey)
    C.quote = product and Quote.Build(obs, sel, C.Options(obs, product)) or nil
  end
  CobysCrestExchange.EventBus:Fire(CobysCrestExchange.Events.QuoteChanged, C.quote)
end

function C:ReceiveEvent(event, arg)
  local E = CobysCrestExchange.Events
  if event == E.SelectionChanged then
    C.selection = arg
  end
  C.Refresh()
end

function C.Current() return C.quote end

CobysCrestExchange.EventBus:Register(C, {
  CobysCrestExchange.Events.SelectionChanged,
  CobysCrestExchange.Events.ObservationsChanged,
  CobysCrestExchange.Events.PreferenceChanged,
})
