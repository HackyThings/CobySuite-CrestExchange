-------------------------------------------------------------------------------
-- CobysCrestExchange Buyer: one purchase chunk at a time, for Session
--
-- NextChunk re-checks everything immediately before a purchase: combat, the
-- same exchange vendor, the offer found again by item ID with an unchanged
-- signature and price, then sizes the chunk as the smallest of the order's
-- remaining allowance, the merchant's per-purchase limit, the balance after
-- the reserve, uncommitted room (whole packs only), bag space and stock. A
-- larger Max than at approval can never raise a chunk above the remaining
-- allowance.
--
-- Classify reads what happened from bag and currency deltas against the
-- baseline Session saved before sending: complete (exactly the packs and the
-- spend expected), none (nothing moved), or partial / overshoot (anything
-- else, which Session treats as uncertain; crests earned from play during
-- the wait land here too, which is the safe outcome).
-------------------------------------------------------------------------------

local Buyer = {}
CobysCrestExchange.Buyer = Buyer

local Seams = CobysCrestExchange.Seams
local Merchant = CobysCrestExchange.Merchant
local Currency = CobysCrestExchange.Currency
local Ledger = CobysCrestExchange.Ledger
local INF = math.huge

local function Balance(obs, currencyID)
  for _, t in pairs(obs.tiers or {}) do
    if t.tier.currencyID == currencyID then return t.currency.ok and t.currency.quantity or nil, t end
  end
end

-- { index, qty, base } or nil, reason
function Buyer.NextChunk(order, ledger, obs, unsettled)
  if obs.inCombat then return nil, "combat" end
  local m = obs.merchant
  if not (m and m.open and m.isExchange) then return nil, "merchant_closed" end
  if order.npcID and m.npcID ~= order.npcID then return nil, "other_vendor" end
  local remaining = Ledger.Remaining(order, ledger)
  if remaining <= 0 then return nil, "done" end

  local index, why, slot = Merchant.ResolveIndex({ itemID = order.itemID, signature = order.signature })
  if not index then return nil, "offer_" .. why end
  local cost = slot.costs[1] and slot.costs[1].amount
  if cost ~= order.cost then return nil, "offer_changed" end

  local held = Balance(obs, order.sourceCurrencyID)
  local _, dstTier = Balance(obs, order.destCurrencyID)
  if not held or not dstTier then return nil, "unknown_balance" end
  local byBalance = math.floor(math.max(0, held - (order.reserve or 0)) / cost)
  local uncommitted = Currency.Uncommitted(dstTier.room, dstTier.packedCrests, unsettled and unsettled[dstTier.tier.key] or 0)
  if uncommitted == nil then return nil, "unknown_room" end
  local byRoom = uncommitted == INF and INF or math.floor(uncommitted / order.yield)
  local space = obs.packSpace and obs.packSpace[order.key] or INF
  local stock = (slot.numAvailable and slot.numAvailable >= 0) and slot.numAvailable or INF
  local qty = math.min(remaining, math.max(1, slot.maxStack or 1), byBalance, byRoom, space, stock)
  if qty < 1 then
    if byRoom < 1 then return nil, "capped" end
    if byBalance < 1 then return nil, "balance" end
    if space < 1 then return nil, "bags" end
    return nil, "stock"
  end
  local packsNow = obs.packs and obs.packs[order.key] or 0
  return { index = index, qty = qty, base = { packs = packsNow, source = held } }
end

function Buyer.Send(index, qty)
  return Seams.Call("Buy", index, qty)
end

-- "complete" | "none" | "partial" | "overshoot" | "unknown"
function Buyer.Classify(order, attempt, obs)
  local held = Balance(obs, order.sourceCurrencyID)
  local packsNow = obs.packs and obs.packs[order.key]
  if held == nil or packsNow == nil then return "unknown", 0, 0 end
  local dp = packsNow - attempt.base.packs
  local ds = attempt.base.source - held
  if dp == attempt.packs and ds == attempt.packs * order.cost then return "complete", dp, ds end
  if dp == 0 and ds == 0 then return "none", 0, 0 end
  if dp > attempt.packs or ds > attempt.packs * order.cost then return "overshoot", dp, ds end
  return "partial", dp, ds
end
