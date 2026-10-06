-------------------------------------------------------------------------------
-- CobysCrestExchange Inventory: recognized packs in the bags
--
-- Counts come from C_Item.GetItemCount (bags only). Slot walks cover the
-- backpack and the four bag slots; the reagent bag holds reagents only, so a
-- crest pack never lands there. Bag space for new packs counts free slots
-- times the pack's stack size plus the room left in partial stacks.
-------------------------------------------------------------------------------

local Inventory = {}
CobysCrestExchange.Inventory = Inventory

local Seams = CobysCrestExchange.Seams
local U = CobySuite_CobysCrestExchange.Utilities

local function Whole(n)
  return U.IsFiniteNumber(n) and n >= 0
end

-- { [productKey] = count } for every product (0 when its item ID is not known yet)
function Inventory.Counts(season)
  local counts = {}
  for _, product in ipairs(season.products) do
    local n = product.itemID and Seams.Call("ItemCount", product.itemID) or 0
    counts[product.key] = Whole(n) and n or 0
  end
  return counts
end

local function EachSlot(visit)
  local first, last = Seams.Call("BagRange")
  first, last = first or 0, last or 4
  for bag = first, last do
    local slots = Seams.Call("NumSlots", bag) or 0
    for slot = 1, slots do
      local info = Seams.Call("SlotInfo", bag, slot)
      if visit(bag, slot, info) then return end
    end
  end
end

-- The first unlocked slot holding itemID: bag, slot; or nil, "locked" / "none"
function Inventory.FindSlot(itemID)
  local foundBag, foundSlot, sawLocked
  EachSlot(function(bag, slot, info)
    if type(info) == "table" and info.itemID == itemID then
      if info.isLocked then
        sawLocked = true
      else
        foundBag, foundSlot = bag, slot
        return true
      end
    end
  end)
  if foundBag then return foundBag, foundSlot end
  return nil, sawLocked and "locked" or "none"
end

-- Every slot holding itemID, for the diagnostics report
function Inventory.Describe(itemID)
  local rows = {}
  EachSlot(function(bag, slot, info)
    if type(info) == "table" and info.itemID == itemID then
      rows[#rows + 1] = { bag = bag, slot = slot, count = info.stackCount, locked = info.isLocked == true,
        hasLoot = info.hasLoot == true, bound = info.isBound == true }
    end
  end)
  return rows
end

-- How many more packs of itemID the bags can take
function Inventory.PackSpace(itemID)
  local stack = Seams.Call("ItemStackSize", itemID)
  if not Whole(stack) or stack < 1 then stack = 1 end
  local space = 0
  local first, last = Seams.Call("BagRange")
  first, last = first or 0, last or 4
  for bag = first, last do
    local free = Seams.Call("FreeSlots", bag)
    if Whole(free) then space = space + free * stack end
  end
  if stack > 1 then
    EachSlot(function(_, _, info)
      if type(info) == "table" and info.itemID == itemID and Whole(info.stackCount) then
        space = space + math.max(0, stack - info.stackCount)
      end
    end)
  end
  return space
end
