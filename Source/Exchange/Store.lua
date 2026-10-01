-------------------------------------------------------------------------------
-- CobysCrestExchange Store: the COBYS_CREST_EXCHANGE_DATA SavedVariable
--
--   COBYS_CREST_EXCHANGE_DATA = {
--     schema = 1,
--     chars = { [playerGUID] = { name, seenAt, seasons = { [seasonKey] = {
--       reserves = { [currencyID] = n },   -- "keep at least" per source tier
--       autoOpen = bool,                   -- the review's opening choice
--       offers   = { seenAt, npcID, list = { { key, itemID, sourceCurrencyID,
--                    costPerUnit, yieldPerUnit } } },   -- for the away view
--       order    = { order = Order, ledger = Ledger } or nil,
--       plan     = a multi-tier plan between or during its steps, or nil,
--       history  = { { key, packs, spent, received, outcome, endedAt } },
--     } } } },
--     lastCapture = { at, text },
--   }
--
-- Never saved: merchant indices, secure button targets, permission to spend.
-- Everything read back is checked (finite whole numbers, known shapes); a
-- saved order that fails Ledger.Validate is dropped with a history note. A
-- schema newer than this build leaves the table untouched and the Store
-- read-only for the session.
-------------------------------------------------------------------------------

local Store = {}
CobysCrestExchange.Store = Store

local U = CobySuite_CobysCrestExchange.Utilities
local SCHEMA = 1
local MAX_CHARS = 50
local MAX_SEASONS = 3
local MAX_HISTORY = 10
local MAX_CAPTURE = 20000

local S = { data = nil, readOnly = false, charKey = nil, seasonKey = nil }

local function Whole(n)
  return U.IsFiniteNumber(n) and n >= 0 and n == math.floor(n)
end

local function PruneOldest(map, limit, stampField)
  local keys = {}
  for key, entry in pairs(map) do
    keys[#keys + 1] = { key = key, at = type(entry) == "table" and tonumber(entry[stampField]) or 0 }
  end
  if #keys <= limit then return end
  table.sort(keys, function(a, b) return (a.at or 0) > (b.at or 0) end)
  for i = limit + 1, #keys do map[keys[i].key] = nil end
end

local function CleanReserves(reserves)
  local clean = {}
  if type(reserves) == "table" then
    for currencyID, n in pairs(reserves) do
      if Whole(currencyID) and Whole(n) and n > 0 then clean[currencyID] = n end
    end
  end
  return clean
end

local function CleanOffers(offers)
  if type(offers) ~= "table" or type(offers.list) ~= "table" then return nil end
  local list = {}
  for _, o in ipairs(offers.list) do
    if type(o) == "table" and type(o.key) == "string" and Whole(o.itemID)
      and Whole(o.sourceCurrencyID) and Whole(o.costPerUnit) and o.costPerUnit > 0
      and Whole(o.yieldPerUnit) and o.yieldPerUnit > 0 then
      list[#list + 1] = { key = o.key, itemID = o.itemID, sourceCurrencyID = o.sourceCurrencyID,
        costPerUnit = o.costPerUnit, yieldPerUnit = o.yieldPerUnit }
    end
  end
  return { seenAt = Whole(offers.seenAt) and offers.seenAt or 0,
    npcID = Whole(offers.npcID) and offers.npcID or nil, list = list }
end

local function CleanHistory(history)
  local clean = {}
  if type(history) == "table" then
    for _, h in ipairs(history) do
      if type(h) == "table" and #clean < MAX_HISTORY then
        clean[#clean + 1] = {
          key = type(h.key) == "string" and h.key or "?",
          packs = Whole(h.packs) and h.packs or 0,
          spent = Whole(h.spent) and h.spent or 0,
          received = Whole(h.received) and h.received or 0,
          outcome = type(h.outcome) == "string" and h.outcome or "?",
          endedAt = Whole(h.endedAt) and h.endedAt or 0,
        }
      end
    end
  end
  return clean
end

local function CleanSeasonBucket(bucket)
  if type(bucket) ~= "table" then bucket = {} end
  local clean = {
    reserves = CleanReserves(bucket.reserves),
    autoOpen = bucket.autoOpen == true,
    offers = CleanOffers(bucket.offers),
    history = CleanHistory(bucket.history),
  }
  clean.plan = Store.ValidatePlan(bucket.plan)
  if type(bucket.order) == "table" then
    local Ledger = CobysCrestExchange.Ledger
    local ok, order, ledger = Ledger.Validate(bucket.order.order, bucket.order.ledger)
    if ok then
      clean.order = { order = order, ledger = ledger }
    else
      table.insert(clean.history, 1, { key = "?", packs = 0, spent = 0, received = 0,
        outcome = "unreadable", endedAt = 0 })
    end
  end
  return clean
end

local function CleanChar(char)
  if type(char) ~= "table" then return nil end
  local clean = { name = type(char.name) == "string" and char.name or "?",
    seenAt = Whole(char.seenAt) and char.seenAt or 0, seasons = {} }
  if type(char.seasons) == "table" then
    for seasonKey, bucket in pairs(char.seasons) do
      if type(seasonKey) == "string" then clean.seasons[seasonKey] = CleanSeasonBucket(bucket) end
    end
  end
  PruneOldest(clean.seasons, MAX_SEASONS, "seenAt")
  return clean
end

-- Returns the table to assign to the SavedVariable
function Store.Initialize(saved)
  S.readOnly = false
  if type(saved) == "table" and Whole(saved.schema) and saved.schema > SCHEMA then
    S.readOnly = true
    S.data = saved
    CobysCrestExchange.Debug.Warn("STORE", "Saved data schema %d is newer than %d: read-only", saved.schema, SCHEMA)
    return saved
  end
  local data = { schema = SCHEMA, chars = {} }
  if type(saved) == "table" then
    if type(saved.chars) == "table" then
      for guid, char in pairs(saved.chars) do
        if type(guid) == "string" then data.chars[guid] = CleanChar(char) end
      end
    end
    if type(saved.lastCapture) == "table" and type(saved.lastCapture.text) == "string" then
      data.lastCapture = { at = Whole(saved.lastCapture.at) and saved.lastCapture.at or 0,
        text = saved.lastCapture.text:sub(1, MAX_CAPTURE) }
    end
  end
  PruneOldest(data.chars, MAX_CHARS, "seenAt")
  S.data = data
  return data
end

-- At login: which character and season the buckets belong to
function Store.BindCharacter(seasonKey)
  local Seams = CobysCrestExchange.Seams
  S.charKey = Seams.Call("PlayerGUID")
  S.seasonKey = seasonKey
  if not S.data or not S.charKey or S.readOnly then return end
  local char = S.data.chars[S.charKey]
  if not char then
    char = { seasons = {} }
    S.data.chars[S.charKey] = char
  end
  char.name = Seams.Call("PlayerName") or char.name or "?"
  char.seenAt = Seams.Call("Time") or char.seenAt or 0
  PruneOldest(S.data.chars, MAX_CHARS, "seenAt")
end

function Store.IsReadOnly() return S.readOnly end

-- The current character's bucket for the active season, or nil before login
function Store.Bucket()
  if not S.data or not S.charKey or not S.seasonKey then return nil end
  local char = S.data.chars[S.charKey]
  if not char then return nil end
  local bucket = char.seasons[S.seasonKey]
  if not bucket then
    if S.readOnly then return nil end
    bucket = { reserves = {}, autoOpen = false, history = {} }
    char.seasons[S.seasonKey] = bucket
  end
  bucket.seenAt = char.seenAt
  return bucket
end

local function Writable()
  if S.readOnly then return nil end
  return Store.Bucket()
end

function Store.GetReserve(currencyID)
  local bucket = Store.Bucket()
  return bucket and bucket.reserves and bucket.reserves[currencyID] or 0
end

function Store.SetReserve(currencyID, amount)
  local bucket = Writable()
  if not bucket or not Whole(currencyID) then return false end
  if amount ~= nil and not Whole(amount) then return false end
  bucket.reserves = bucket.reserves or {}
  bucket.reserves[currencyID] = (amount and amount > 0) and amount or nil
  return true
end

function Store.GetAutoOpen()
  local bucket = Store.Bucket()
  return bucket ~= nil and bucket.autoOpen == true
end

function Store.SetAutoOpen(value)
  local bucket = Writable()
  if bucket then bucket.autoOpen = value == true end
end

function Store.SaveOffers(list, npcID)
  local bucket = Writable()
  if not bucket then return end
  bucket.offers = CleanOffers({ seenAt = CobysCrestExchange.Seams.Call("Time"), npcID = npcID, list = list })
end

function Store.GetOffers()
  local bucket = Store.Bucket()
  return bucket and bucket.offers or nil
end

function Store.SaveOrder(order, ledger)
  local bucket = Writable()
  if bucket then bucket.order = { order = order, ledger = ledger } end
end

function Store.GetOrder()
  local bucket = Store.Bucket()
  if bucket and bucket.order then return bucket.order.order, bucket.order.ledger end
end

-- Ends the saved order and keeps a short receipt in the history
function Store.ClearOrder(outcome)
  local bucket = Writable()
  if not bucket or not bucket.order then return end
  local order, ledger = bucket.order.order, bucket.order.ledger
  bucket.history = bucket.history or {}
  table.insert(bucket.history, 1, {
    key = order and order.key or "?",
    packs = ledger and ledger.purchased or 0,
    spent = ledger and ledger.spent or 0,
    received = ledger and ledger.received or 0,
    outcome = outcome or "done",
    endedAt = CobysCrestExchange.Seams.Call("Time") or 0,
  })
  while #bucket.history > MAX_HISTORY do table.remove(bucket.history) end
  bucket.order = nil
end

-- A saved plan, cleaned, or nil
function Store.ValidatePlan(plan)
  if type(plan) ~= "table" or type(plan.target) ~= "string" or not Whole(plan.crests) or type(plan.steps) ~= "table"
    or not Whole(plan.index) or plan.index < 1 or plan.index > #plan.steps then
    return nil
  end
  local steps = {}
  for i, s in ipairs(plan.steps) do
    if type(s) ~= "table" then return nil end
    local open = s.kind == "open"
    if type(s.key) ~= "string" or (not open and type(s.from) ~= "string") or type(s.to) ~= "string"
      or not Whole(s.packs) or s.packs < 1 or not Whole(s.cost) or not Whole(s.yield) or s.yield < 1 then
      return nil
    end
    steps[i] = { kind = open and "open" or nil, key = s.key, from = not open and s.from or nil, to = s.to,
      packs = s.packs, cost = s.cost, yield = s.yield, spend = s.packs * s.cost }
  end
  local keep = {}
  for k, v in pairs(type(plan.keep) == "table" and plan.keep or {}) do
    if type(k) == "string" and Whole(v) then keep[k] = v end
  end
  return { target = plan.target, crests = plan.crests, steps = steps, index = plan.index, keep = keep,
    autoOpen = plan.autoOpen == true }
end

function Store.SavePlan(plan)
  local bucket = Writable()
  if bucket then bucket.plan = plan end
end

function Store.GetPlan()
  local bucket = Store.Bucket()
  return bucket and Store.ValidatePlan(bucket.plan) or nil
end

function Store.ClearPlan()
  local bucket = Writable()
  if bucket then bucket.plan = nil end
end

function Store.GetHistory()
  local bucket = Store.Bucket()
  return bucket and bucket.history or {}
end

function Store.SaveCapture(text)
  if not S.data or S.readOnly or type(text) ~= "string" then return end
  S.data.lastCapture = { at = CobysCrestExchange.Seams.Call("Time") or 0, text = text:sub(1, MAX_CAPTURE) }
end

-- Tests only: swap the live table and binding, then put them back
Store._test = {
  Swap = function(data, charKey, seasonKey)
    local previous = { data = S.data, charKey = S.charKey, seasonKey = S.seasonKey, readOnly = S.readOnly }
    S.data, S.charKey, S.seasonKey, S.readOnly = data, charKey, seasonKey, false
    return function()
      S.data, S.charKey, S.seasonKey, S.readOnly = previous.data, previous.charKey, previous.seasonKey, previous.readOnly
    end
  end,
  Limits = { chars = MAX_CHARS, seasons = MAX_SEASONS, history = MAX_HISTORY, capture = MAX_CAPTURE },
}
