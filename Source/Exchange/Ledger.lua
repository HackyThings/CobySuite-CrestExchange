-------------------------------------------------------------------------------
-- CobysCrestExchange Ledger: an order and what verifiably happened (pure)
--
-- An order means "receive N more crests of a tier from one source". Its
-- approved purchase allowance is fixed when the player confirms, and what is
-- left to buy is always
--     remaining = approved packs - verified purchases
-- never "target balance - current balance". So spending, moving or losing
-- crests after a stop can never authorize replacement purchases. Crests
-- earned from play never count toward an order either.
--
--   Order  = { id, kind = "exchange"|"open_existing", season, key, itemID,
--              direction, sourceCurrencyID, destCurrencyID, yield, cost,
--              reserve, signature, npcID, approvedPacks, autoOpen, createdAt }
--   Ledger = { orderId, purchased, spent, opened, received, openQuota,
--              attempt = { kind = "buy", packs, sentAt, base = { packs, source } },
--              openAttempt = { packs, dest } while an open is in flight,
--              status = "active"|"paused"|"uncertain"|"complete" }
-------------------------------------------------------------------------------

local Ledger = {}
CobysCrestExchange.Ledger = Ledger

local U = CobySuite_CobysCrestExchange.Utilities

local function Whole(n)
  return U.IsFiniteNumber(n) and n >= 0 and n == math.floor(n)
end

local counter = 0
function Ledger.NewOrder(q, fields)
  counter = counter + 1
  local now = fields.now or 0
  return {
    id = string.format("%d-%d", now, counter),
    kind = fields.kind or "exchange",
    season = fields.season,
    key = q.key,
    itemID = q.itemID,
    direction = q.direction,
    sourceCurrencyID = q.offer and q.offer.sourceCurrencyID or fields.sourceCurrencyID,
    destCurrencyID = fields.destCurrencyID,
    yield = q.yield,
    cost = q.cost or 0,
    reserve = q.reserve or 0,
    signature = q.signature,
    npcID = fields.npcID,
    approvedPacks = q.packs or 0,
    autoOpen = fields.autoOpen == true,
    createdAt = now,
  }
end

function Ledger.New(order, openQuota)
  return { orderId = order.id, purchased = 0, spent = 0, opened = 0, received = 0,
    openQuota = openQuota or 0, status = "active" }
end

function Ledger.Remaining(order, ledger)
  if order.kind == "open_existing" then return 0 end
  return math.max(0, order.approvedPacks - ledger.purchased)
end

-- Packs this order may still open
function Ledger.OpenQuota(order, ledger)
  local allowed = order.kind == "open_existing" and ledger.openQuota or ledger.purchased
  return math.max(0, allowed - ledger.opened)
end

function Ledger.BeginAttempt(ledger, packs, base, now)
  ledger.attempt = { kind = "buy", packs = packs, sentAt = now or 0,
    base = { packs = base.packs or 0, source = base.source or 0 } }
end

function Ledger.ResolveBought(ledger, packs, spent)
  ledger.purchased = ledger.purchased + packs
  ledger.spent = ledger.spent + spent
  ledger.attempt = nil
end

function Ledger.ResolveNotBought(ledger)
  ledger.attempt = nil
end

function Ledger.RecordOpen(ledger, crests)
  ledger.opened = ledger.opened + 1
  ledger.received = ledger.received + (crests or 0)
end

-- Re-approving an order can only lower what is left: the new allowance is what
-- was bought plus the newly approved packs, never more than was left before
function Ledger.Reapprove(order, ledger, newPacks)
  local remaining = Ledger.Remaining(order, ledger)
  newPacks = math.min(newPacks, remaining)
  order.approvedPacks = ledger.purchased + newPacks
  return newPacks
end

-- For the unfinished view; bagCount is how many of the order's packs are in the bags now
function Ledger.Summary(order, ledger, bagCount, balanceNow)
  local quota = Ledger.OpenQuota(order, ledger)
  local remaining = Ledger.Remaining(order, ledger)
  return {
    goal = order.approvedPacks * (order.yield or 0),
    received = ledger.received,
    stillInPacks = math.min(quota, bagCount or 0),
    notBoughtPacks = remaining,
    notBought = remaining * (order.yield or 0),
    notBoughtCost = remaining * (order.cost or 0),
    missingPacks = math.max(0, quota - (bagCount or 0)),
    balanceNow = balanceNow,
  }
end

local ORDER_WHOLE = { "approvedPacks", "yield", "cost", "reserve" }
local LEDGER_WHOLE = { "purchased", "spent", "opened", "received", "openQuota" }

-- ok, order, ledger (cleaned copies) for a saved record
function Ledger.Validate(order, ledger)
  if type(order) ~= "table" or type(ledger) ~= "table" then return false end
  if type(order.id) ~= "string" or type(order.key) ~= "string" or not Whole(order.itemID) then return false end
  if order.kind ~= "exchange" and order.kind ~= "open_existing" then return false end
  for _, field in ipairs(ORDER_WHOLE) do
    if not Whole(order[field]) then return false end
  end
  if order.yield <= 0 then return false end
  for _, field in ipairs(LEDGER_WHOLE) do
    if ledger[field] ~= nil and not Whole(ledger[field]) then return false end
  end
  local cleanOrder = {}
  for k, v in pairs(order) do cleanOrder[k] = v end
  local cleanLedger = {
    orderId = order.id, purchased = ledger.purchased or 0, spent = ledger.spent or 0,
    opened = ledger.opened or 0, received = ledger.received or 0, openQuota = ledger.openQuota or 0,
    status = type(ledger.status) == "string" and ledger.status or "paused",
  }
  if cleanLedger.purchased > order.approvedPacks and order.kind == "exchange" then return false end
  local a = ledger.attempt
  if type(a) == "table" and Whole(a.packs) and type(a.base) == "table" and Whole(a.base.packs) and Whole(a.base.source) then
    cleanLedger.attempt = { kind = "buy", packs = a.packs, sentAt = Whole(a.sentAt) and a.sentAt or 0,
      base = { packs = a.base.packs, source = a.base.source } }
  elseif a ~= nil then
    return false
  end
  local o = ledger.openAttempt
  if type(o) == "table" and Whole(o.packs) and Whole(o.dest) then
    cleanLedger.openAttempt = { packs = o.packs, dest = o.dest }
  elseif o ~= nil then
    return false
  end
  return true, cleanOrder, cleanLedger
end
