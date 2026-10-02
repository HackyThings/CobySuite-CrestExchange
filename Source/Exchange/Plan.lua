-------------------------------------------------------------------------------
-- CobysCrestExchange Plan: "I want X more of a tier" across several tiers
--
-- Plan.Build(obs, targetKey, crests, opts) works out a chain of trade-ups
-- that ends in the target tier. It uses the tier just below first, and when
-- that is short, makes up the difference by trading up from the tier below
-- it, and so on down the ladder. Each step is a whole number of packs, so a
-- lower step can leave a few crests over; the preview says so.
--
--   opts = { spend = { [tierKey] = true }   tiers whose existing crests may
--                                            be spent (others are passed
--                                            through: crests made there are
--                                            used, the balance is kept)
--            reserves = { [currencyID] = n }, unsettled = { [tierKey] = n } }
--
-- Every step must be offered (live at the vendor, or last seen there when
-- planning), and its packs must fit the destination's uncommitted room
-- whole (the conservative cap policy, as for a single trade). Max is the
-- largest target that passes, with what stopped it named.
--
-- Packs already in the bags count (Cobanyte, 2026-09-30): the target tier's
-- unopened packs reduce what is bought, and the packs of a tier the plan may
-- spend add to that tier's crests. Each becomes an open step,
--   { kind = "open", key, itemID, to, packs, yield, cost = 0, spend = 0 }
-- placed just before the trade that spends those crests (the target's last).
-- An open step needs no vendor and buys nothing.
--
-- Steps come out in the order they run: the lowest trade first. Session
-- runs them one after another: buy, open every pack, then the next step.
-------------------------------------------------------------------------------

local Plan = {}
CobysCrestExchange.Plan = Plan

local Seasons = CobysCrestExchange.Seasons
local Currency = CobysCrestExchange.Currency
local INF = math.huge
local MAX_PACKS = 500

-- The live offer at the vendor, else the last one seen there
local function Offer(obs, key)
  local m = obs.merchant
  local live = m and m.isExchange and m.offers and m.offers[key]
  if live then return live, false end
  for _, entry in ipairs(obs.lastSeen and obs.lastSeen.list or {}) do
    if entry.key == key then
      return { key = entry.key, itemID = entry.itemID, sourceCurrencyID = entry.sourceCurrencyID,
        costPerUnit = entry.costPerUnit, yieldPerUnit = entry.yieldPerUnit, signature = "seen", numAvailable = -1 }, true
    end
  end
end

local function UpInto(season, tierKey)
  for _, product in ipairs(season.products) do
    if product.kind == "up" and product.to == tierKey then return product end
  end
end

-- The unopened packs in the bags that give a tier's crests, by product
local function Held(obs, season, tierKey)
  local list, crests = {}, 0
  for _, product in ipairs(season.products) do
    local count = product.to == tierKey and obs.packs and obs.packs[product.key] or 0
    if count > 0 then
      local yield = product.yield or 10
      list[#list + 1] = { key = product.key, itemID = product.itemID, count = count, yield = yield }
      crests = crests + count * yield
    end
  end
  return list, crests
end

-- Open steps for `need` crests from held packs (fewest packs that cover it)
local function OpenSteps(held, need, tierKey)
  local steps, got = {}, 0
  for _, h in ipairs(held) do
    if got >= need then break end
    local n = math.min(h.count, math.ceil((need - got) / h.yield))
    if n > 0 then
      steps[#steps + 1] = { kind = "open", key = h.key, itemID = h.itemID, to = tierKey, packs = n, yield = h.yield,
        cost = 0, spend = 0 }
      got = got + n * h.yield
    end
  end
  return steps, got
end

-- What may be spent from a tier's existing balance
local function Spendable(obs, tier, opts)
  if not (opts.spend and opts.spend[tier.key]) then return 0 end
  local t = obs.tiers[tier.key]
  if not (t and t.currency.ok) then return 0 end
  local reserve = opts.reserves and opts.reserves[tier.currencyID] or 0
  return math.max(0, t.currency.quantity - reserve)
end

-- What a tier's reserve is short by: crests opened there fill this first
local function Deficit(obs, tier, opts)
  local t = obs.tiers[tier.key]
  if not (t and t.currency.ok) then return 0 end
  local reserve = opts.reserves and opts.reserves[tier.currencyID] or 0
  return math.max(0, reserve - t.currency.quantity)
end

-- Packs opened into a tier must fit its raw room, as the opener requires
-- (Opener.MayOpen); unknown room fits nothing
local function OpensFit(obs, tierKey, crests)
  if crests <= 0 then return true end
  local t = obs.tiers[tierKey]
  local raw = t and t.room and t.room.raw
  if raw == nil then return false, "unknown_room" end
  if raw ~= INF and crests > raw then return false, "room" end
  return true
end

-- The chain for `packs` packs of the target: steps (lowest first) or nil and why
function Plan.Chain(obs, season, targetIndex, packs, opts)
  local steps, planning = {}, false
  local needCrests
  -- The target's own packs come first off what is bought; they open last
  local top = season.tiers[targetIndex]
  local topProduct = UpInto(season, top.key)
  local topOffer = topProduct and Offer(obs, topProduct.key)
  local topYield = topOffer and topOffer.yieldPerUnit or (topProduct and topProduct.yield) or 10
  local heldTop = Held(obs, season, top.key)
  local opens = OpenSteps(heldTop, packs * topYield, top.key)
  local fromHeld = 0
  for _, o in ipairs(opens) do fromHeld = fromHeld + o.packs * o.yield end
  local fits, why = OpensFit(obs, top.key, fromHeld)
  if not fits then return nil, why, top.key end
  packs = math.max(0, packs - math.floor(fromHeld / topYield))
  if packs == 0 then return opens, nil, nil, false end
  for k = targetIndex, 2, -1 do
    local toTier, fromTier = season.tiers[k], season.tiers[k - 1]
    local product = UpInto(season, toTier.key)
    -- Both returns: "product and Offer(...)" would keep only the first, and
    -- seen (an offer from the last visit) would never mark the plan
    local offer, seen
    if product then offer, seen = Offer(obs, product.key) end
    if not offer then return nil, "unavailable", toTier.key end
    planning = planning or seen
    local yield, cost = offer.yieldPerUnit, offer.costPerUnit
    local n = (k == targetIndex) and packs or math.ceil(needCrests / yield)
    local dst = obs.tiers[toTier.key]
    local unsettled = opts.unsettled and opts.unsettled[toTier.key] or 0
    local room = dst and Currency.Uncommitted(dst.room, dst.packedCrests, unsettled)
    if room == nil then return nil, "unknown_room", toTier.key end
    if room ~= INF and n * yield > room then return nil, "room", toTier.key end
    if offer.numAvailable and offer.numAvailable >= 0 and n > offer.numAvailable then return nil, "stock", toTier.key end
    -- Each step's packs are bought when it starts, so each must fit the bags on its own
    local space = obs.packSpace and obs.packSpace[product.key]
    if space and n > space then return nil, "bags", toTier.key end
    table.insert(steps, 1, { key = product.key, from = fromTier.key, to = toTier.key, packs = n, cost = cost,
      yield = yield, spend = n * cost, itemID = offer.itemID, signature = offer.signature })
    local req = n * cost
    local avail = Spendable(obs, fromTier, opts)
    local short = 0   -- what the tier's reserve still lacks after its own packs
    if avail < req and opts.spend and opts.spend[fromTier.key] then
      -- This tier's own packs make up what its balance lacks, opened first;
      -- what they give fills the tier's reserve before it can be spent
      local deficit = Deficit(obs, fromTier, opts)
      local more, got = OpenSteps((Held(obs, season, fromTier.key)), req - avail + deficit, fromTier.key)
      if got > 0 then
        local ok, whyNot = OpensFit(obs, fromTier.key, got)
        if not ok then return nil, whyNot, fromTier.key end
        for i = #more, 1, -1 do table.insert(steps, 1, more[i]) end
      end
      avail = avail + math.max(0, got - deficit)
      short = math.max(0, deficit - got)
    elseif avail < req then
      -- A tier passed through (not spent) is still held to its reserve when
      -- the step runs, so what the reserve lacks is made too
      short = Deficit(obs, fromTier, opts)
    end
    if avail >= req then
      for _, o in ipairs(opens) do steps[#steps + 1] = o end
      return steps, nil, nil, planning
    end
    if k - 1 < 2 then return nil, "balance", fromTier.key end
    needCrests = req - avail + short
  end
  return nil, "balance"
end

local function Totals(obs, season, steps)
  local before, after = {}, {}
  for _, tier in ipairs(season.tiers) do
    local t = obs.tiers[tier.key]
    before[tier.key] = t and t.currency.ok and t.currency.quantity or nil
    after[tier.key] = before[tier.key]
  end
  local spend = {}
  for _, step in ipairs(steps) do
    if step.from and after[step.from] then after[step.from] = after[step.from] - step.spend end
    if after[step.to] then after[step.to] = after[step.to] + step.packs * step.yield end
  end
  for key, value in pairs(before) do
    if after[key] and after[key] < value then spend[key] = value - after[key] end
  end
  return before, after, spend
end

local function MaxPacks(obs, season, index, opts)
  local best, why, where = 0, nil, nil
  for p = 1, MAX_PACKS do
    local steps, reason, tierKey = Plan.Chain(obs, season, index, p, opts)
    if not steps then why, where = reason, tierKey; break end
    best = p
  end
  return best, why, where
end

-- The full preview for "receive `crests` more of targetKey"
function Plan.Build(obs, targetKey, crests, opts)
  opts = opts or {}
  local season = obs and obs.season
  if not season then return { status = "none" } end
  local index = Seasons.TierIndex(season, targetKey)
  if not index or index < 3 then return { status = "none" } end
  local top = UpInto(season, targetKey)
  local topOffer = top and Offer(obs, top.key)
  local yield = topOffer and topOffer.yieldPerUnit or (top and top.yield) or 10
  local maxPacks, limiter, limitTier = MaxPacks(obs, season, index, opts)
  local plan = { target = targetKey, yield = yield, maxPacks = maxPacks, maxCrests = maxPacks * yield,
    limiter = limiter, limitTier = limitTier, crests = crests, steps = {}, opts = opts }
  if crests == nil then plan.status = "empty"; return plan end
  if type(crests) ~= "number" or crests <= 0 or crests ~= math.floor(crests) then plan.status = "invalid"; return plan end
  if crests % yield ~= 0 then
    local down, up = math.floor(crests / yield) * yield, math.ceil(crests / yield) * yield
    plan.status = "rounding"
    plan.rounding = { down = down > 0 and down or nil, up = (up / yield <= maxPacks) and up or nil }
    return plan
  end
  local packs = crests / yield
  local steps, why, whereTier, planning = Plan.Chain(obs, season, index, packs, opts)
  if not steps then
    plan.status, plan.limiter, plan.limitTier = "too_many", why, whereTier
    return plan
  end
  plan.status, plan.steps, plan.planning = "ok", steps, planning
  plan.before, plan.after, plan.spendBy = Totals(obs, season, steps)
  local parts = { targetKey, crests }
  for _, s in ipairs(steps) do
    parts[#parts + 1] = (s.kind == "open" and "open:" or "") .. s.key .. "x" .. s.packs .. "@" .. s.cost .. ":" .. tostring(s.signature)
  end
  plan.fingerprint = table.concat(parts, "|")
  return plan
end

-- Whether a plan only opens packs already in the bags (no trade, no buying):
-- it needs neither Vaskarn nor the buying checks
function Plan.OpenOnly(plan)
  if type(plan) ~= "table" or type(plan.steps) ~= "table" or #plan.steps == 0 then return false end
  for _, step in ipairs(plan.steps) do
    if step.kind ~= "open" then return false end
  end
  return true
end

-- The Get page's chosen route. routes = { { key, kind ("trade" or "plan"),
-- open, ok, down, max } }: the player's pick (`picked`, a route key) while it
-- works (or while no amount is typed, `hasAmount` false), else the plan when
-- it works (Cobanyte, 2026-10-01: "Plan first", over a single trade up),
-- else the first route that works, else the open route that gives the most.
-- A trade down is never chosen for you: only your own click picks it.
function Plan.ChooseRoute(routes, picked, hasAmount)
  for _, r in ipairs(routes) do if r.key == picked and r.open and (r.ok or not hasAmount) then return r end end
  for _, r in ipairs(routes) do if r.ok and r.kind == "plan" then return r end end
  for _, r in ipairs(routes) do if r.ok and not r.down then return r end end
  local best
  for _, r in ipairs(routes) do
    if r.open and not r.down and (not best or (r.max or 0) > (best.max or 0)) then best = r end
  end
  return best
end

-- The tiers whose balance a plan into targetKey could spend: every tier below it
function Plan.SourceTiers(season, targetKey)
  local list = {}
  local index = Seasons.TierIndex(season, targetKey)
  for i = 1, (index or 1) - 1 do list[#list + 1] = season.tiers[i] end
  return list
end
