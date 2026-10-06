-------------------------------------------------------------------------------
-- CobysCrestExchange Gear: facts about the equipped items, nothing assumed
--
-- For "Before you spend": per upgrade track, how many equipped items are on
-- it and how many ranks they have left (C_Item.GetItemUpgradeInfo). This is
-- not a crest cost: discounts, watermarks and the item itself change what a
-- rank costs, and the addon never labels crests as spare from it. Equipped
-- items whose upgrade info has no readable track are counted separately, never
-- as zero need.
-------------------------------------------------------------------------------

local Gear = {}
CobysCrestExchange.Gear = Gear

local Seams = CobysCrestExchange.Seams
local U = CobySuite_CobysCrestExchange.Utilities

-- Inventory slots 1 to 17, skipping the shirt (4)
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

local function Num(v)
  if Seams.IsSecret(v) or not U.IsFiniteNumber(v) then return nil end
  return v
end

-- tracks { [trackName] = { items, ranksLeft, levels, maxLevels } }, order { trackName, ... }, unknown count
function Gear.Tracks()
  local tracks, order, unknown = {}, {}, 0
  for _, slot in ipairs(SLOTS) do
    local link = Seams.Call("InventoryLink", slot)
    if link then
      local info = Seams.Call("UpgradeInfo", link)
      local track = type(info) == "table" and info.trackString
      local current, max = type(info) == "table" and Num(info.currentLevel), type(info) == "table" and Num(info.maxLevel)
      if type(track) == "string" and track ~= "" and not Seams.IsSecret(track) and current and max then
        local entry = tracks[track]
        if not entry then
          entry = { items = 0, ranksLeft = 0, levels = 0, maxLevels = 0 }
          tracks[track] = entry
          order[#order + 1] = track
        end
        entry.items = entry.items + 1
        entry.ranksLeft = entry.ranksLeft + math.max(0, max - current)
        entry.levels = entry.levels + math.min(current, max)
        entry.maxLevels = entry.maxLevels + max
      elseif type(info) == "table" then
        unknown = unknown + 1
      end
    end
  end
  return tracks, order, unknown
end
