-------------------------------------------------------------------------------
-- CobysCrestExchange Merchant: who the vendor is and what they offer
--
-- Identify: the NPC ID from UnitGUID("npc") (C_CreatureInfo, with a GUID
-- parse as fallback), matched against the season's exchange vendors.
--
-- ReadAll + Classify: every merchant slot is read. An offer is recognized
-- only when its item is a known pack AND its price has the expected shape:
-- no gold, a single cost line in the product's source crest, one unit per
-- purchase. Anything else priced in a season crest is listed as unsupported
-- with the reason, so a new or changed pack is visible but never bought.
--
-- Indices: GetMerchantNumItems and BuyMerchantItem work on the list as the
-- merchant filter shows it, and Blizzard resets that filter every time the
-- window opens. So an index is never stored: ResolveIndex finds the offer
-- again by item ID and checks its signature right before each purchase. The
-- filter itself is never changed from here.
-------------------------------------------------------------------------------

local Merchant = {}
CobysCrestExchange.Merchant = Merchant

local Seams = CobysCrestExchange.Seams
local Seasons = CobysCrestExchange.Seasons
local U = CobySuite_CobysCrestExchange.Utilities

local MAX_COSTS = 3   -- MerchantFrame's MAX_ITEM_COST

local function Num(v)
  if Seams.IsSecret(v) or not U.IsFiniteNumber(v) then return nil end
  return v
end

-------------------------------------------------------------------------------
-- Identity
-------------------------------------------------------------------------------
local function ParseCreatureID(guid)
  if type(guid) ~= "string" then return nil end
  local kind = guid:match("^(%a+)%-")
  if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
  local id = select(6, strsplit("-", guid))
  return tonumber(id)
end
Merchant._ParseCreatureID = ParseCreatureID

-- { npcID, isExchange, vendorName, inInstance }
function Merchant.Identify(season)
  local guid = Seams.Call("NpcGUID")
  local npcID = guid and Seams.Call("CreatureID", guid)
  if not Num(npcID) then npcID = ParseCreatureID(guid) end
  local vendorName = season and npcID and season.vendorNPCs[npcID] or nil
  return {
    npcID = npcID,
    isExchange = vendorName ~= nil,
    vendorName = vendorName,
    inInstance = Seams.Call("InInstance") == true,
  }
end

-------------------------------------------------------------------------------
-- Reading slots
-------------------------------------------------------------------------------
local function ReadCosts(index)
  local count = Num(Seams.Call("CostCount", index)) or 0
  local costs, complete = {}, true
  for c = 1, math.min(count, MAX_COSTS) do
    local _, value, link, currencyName = Seams.Call("CostItem", index, c)
    value = Num(value)
    if not value then
      complete = false
    elseif type(link) == "string" then
      local currencyID = Seams.Call("CurrencyIDFromLink", link) or tonumber(link:match("currency:(%d+)"))
      if currencyName or currencyID then
        costs[#costs + 1] = { kind = "currency", id = currencyID, amount = value }
      else
        costs[#costs + 1] = { kind = "item", id = tonumber(link:match("item:(%d+)")), amount = value }
      end
    else
      complete = false
    end
  end
  return costs, complete
end

function Merchant.ReadSlot(index)
  local itemID = Num(Seams.Call("ItemID", index))
  local info = Seams.Call("ItemInfo", index)
  if type(info) ~= "table" then return { index = index, itemID = itemID, complete = false, costs = {} } end
  local costs, complete = ReadCosts(index)
  local slot = {
    index = index,
    itemID = itemID,
    name = not Seams.IsSecret(info.name) and info.name or nil,
    price = Num(info.price) or 0,
    stackCount = Num(info.stackCount) or 1,
    numAvailable = Num(info.numAvailable) or -1,
    isPurchasable = info.isPurchasable ~= false,
    currencyIDSold = Num(info.currencyID),
    maxStack = Num(Seams.Call("MaxStack", index)) or 1,
    refundable = Seams.Call("Refundable", index) == true,
    costs = costs,
    complete = complete and itemID ~= nil,
  }
  return slot
end

function Merchant.ReadAll()
  local slots = {}
  local count = Num(Seams.Call("NumItems")) or 0
  for index = 1, count do slots[index] = Merchant.ReadSlot(index) end
  return slots
end

-------------------------------------------------------------------------------
-- Classifying offers
-------------------------------------------------------------------------------
function Merchant.Signature(slot)
  local parts = {}
  for _, cost in ipairs(slot.costs or {}) do
    parts[#parts + 1] = (cost.kind == "currency" and "c" or "i") .. tostring(cost.id) .. "x" .. tostring(cost.amount)
  end
  table.sort(parts)
  return "g" .. tostring(slot.price) .. "|s" .. tostring(slot.stackCount) .. "|" .. table.concat(parts, ",")
end

local function CrestCost(season, slot)
  for _, cost in ipairs(slot.costs or {}) do
    if cost.kind == "currency" and cost.id and Seasons.IsCrestCurrency(season, cost.id) then return cost end
  end
end

-- Why a known pack's slot does not have the expected price shape, or nil
local function ShapeProblem(season, product, slot)
  if not Seasons.IsTrade(product) then return "not one of his trades" end
  if slot.price ~= 0 then return "has a gold price" end
  if slot.stackCount ~= 1 then return "sells in bundles" end
  if slot.currencyIDSold then return "sells a currency" end
  if #slot.costs ~= 1 then return "has several costs" end
  local cost = slot.costs[1]
  local fromTier = Seasons.Tier(season, product.from)
  if cost.kind ~= "currency" or not fromTier or cost.id ~= fromTier.currencyID then return "costs another currency" end
  if cost.amount <= 0 then return "has no price" end
end

local function MakeOffer(product, slot)
  return {
    key = product.key,
    product = product,
    itemID = slot.itemID,
    index = slot.index,
    sourceCurrencyID = slot.costs[1].id,
    costPerUnit = slot.costs[1].amount,
    yieldPerUnit = product.yield,
    maxStack = math.max(1, slot.maxStack or 1),
    numAvailable = slot.numAvailable,
    isPurchasable = slot.isPurchasable,
    refundable = slot.refundable,
    name = slot.name,
    signature = Merchant.Signature(slot),
  }
end

-- offers { [key] = Offer }, unsupported { { index, itemID, name, costs, reason } }
function Merchant.Classify(slots, season)
  local offers, unsupported = {}, {}
  for _, slot in ipairs(slots) do
    local product = Seasons.ProductByItem(season, slot.itemID)
    local crest = CrestCost(season, slot)
    local reason
    if not slot.complete then
      if product or crest then reason = "unreadable" end
    elseif product then
      reason = ShapeProblem(season, product, slot)
      if not reason and offers[product.key] then reason = "duplicate" end
      if not reason then offers[product.key] = MakeOffer(product, slot) end
    elseif crest then
      reason = "unknown item"
    end
    if reason then
      unsupported[#unsupported + 1] = { index = slot.index, itemID = slot.itemID, name = slot.name,
        costs = slot.costs, reason = reason, product = product }
    end
  end
  return offers, unsupported
end

-------------------------------------------------------------------------------
-- Before each purchase
-------------------------------------------------------------------------------
-- The offer's current index, or nil and "missing" / "changed" / "ambiguous"
function Merchant.ResolveIndex(offer)
  local count = Num(Seams.Call("NumItems")) or 0
  local found
  for index = 1, count do
    if Seams.Call("ItemID", index) == offer.itemID then
      if found then return nil, "ambiguous" end
      found = index
    end
  end
  if not found then return nil, "missing" end
  local slot = Merchant.ReadSlot(found)
  if not slot.complete or Merchant.Signature(slot) ~= offer.signature then return nil, "changed" end
  return found, nil, slot
end

-- True when the merchant list shows everything (a hidden offer can't be blamed on the filter)
function Merchant.FilterIsAll()
  local filter = Seams.Call("Filter")
  local all = Seams.Call("FilterAllValue")
  if filter == nil or all == nil then return true end
  return filter == all
end
