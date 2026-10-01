-------------------------------------------------------------------------------
-- CobysCrestExchange Seams: every call this addon makes into the game
--
-- Each wrapper looks its global up when it runs, so this file loads with no
-- client at all (the offline harness) and tests swap any entry with
-- Tests.Override(ctx, Seams, "NumItems", fn). Nothing outside this file names
-- a merchant, currency, bag, achievement or quest API directly.
--
-- Seams.Call(name, ...) runs one wrapper under pcall and returns nil when it
-- errors or when a returned value is secret (issecretvalue), so callers never
-- compare or index a secret. Wrappers that return tables are checked field by
-- field by their callers with Seams.IsSecret, as Blizzard's structs can carry
-- secret fields individually.
-------------------------------------------------------------------------------

local Seams = {}
CobysCrestExchange.Seams = Seams

function Seams.IsSecret(value)
  return CobySuite_CobysCrestExchange.Utilities.IsSecret(value)
end

local function AnySecret(a, b, c, d)
  local IsSecret = Seams.IsSecret
  return IsSecret(a) or IsSecret(b) or IsSecret(c) or IsSecret(d)
end

function Seams.Call(name, ...)
  local fn = Seams[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok or AnySecret(a, b, c, d) then return nil end
  return a, b, c, d
end

-------------------------------------------------------------------------------
-- Unit, world, time
-------------------------------------------------------------------------------
function Seams.NpcGUID() return UnitGUID("npc") end
function Seams.CreatureID(guid) return C_CreatureInfo.GetCreatureID(guid) end
function Seams.InCombat() return InCombatLockdown() end
function Seams.InInstance() return (IsInInstance()) end
function Seams.Now() return GetTime() end
function Seams.Time() return time() end
function Seams.NewTimer(seconds, fn) return C_Timer.NewTimer(seconds, fn) end
function Seams.Interface() return (select(4, GetBuildInfo())) end
function Seams.Build() local version, build = GetBuildInfo(); return version, build end
function Seams.PlayerGUID() return UnitGUID("player") end
function Seams.PlayerName()
  local name, realm = UnitFullName("player")
  if name and realm and realm ~= "" then return name .. "-" .. realm end
  return name
end
function Seams.Locale() return GetLocale() end

-------------------------------------------------------------------------------
-- Merchant (legacy globals Blizzard's own MerchantFrame still calls)
-------------------------------------------------------------------------------
function Seams.MerchantShown() return MerchantFrame ~= nil and MerchantFrame:IsShown() end
function Seams.NumItems() return GetMerchantNumItems() end
function Seams.ItemID(index) return GetMerchantItemID(index) end
function Seams.ItemInfo(index) return C_MerchantFrame.GetItemInfo(index) end
function Seams.CostCount(index) return GetMerchantItemCostInfo(index) end
function Seams.CostItem(index, costIndex) return GetMerchantItemCostItem(index, costIndex) end
function Seams.MaxStack(index) return GetMerchantItemMaxStack(index) end
function Seams.Refundable(index) return C_MerchantFrame.IsMerchantItemRefundable(index) end
function Seams.Filter() return GetMerchantFilter() end
function Seams.FilterAllValue() return LE_LOOT_FILTER_ALL end
function Seams.Buy(index, quantity) return BuyMerchantItem(index, quantity) end
function Seams.NumBuyback() return GetNumBuybackItems() end
function Seams.Money() return GetMoney() end

-------------------------------------------------------------------------------
-- Currency
-------------------------------------------------------------------------------
function Seams.CurrencyInfo(currencyID) return C_CurrencyInfo.GetCurrencyInfo(currencyID) end
function Seams.CurrencyIDFromLink(link) return C_CurrencyInfo.GetCurrencyIDFromLink(link) end

-------------------------------------------------------------------------------
-- Items and bags
-------------------------------------------------------------------------------
function Seams.ItemCount(itemID) return C_Item.GetItemCount(itemID) end
function Seams.ItemIcon(itemID) return C_Item.GetItemIconByID(itemID) end
function Seams.ItemStackSize(itemID) return (select(8, C_Item.GetItemInfo(itemID))) end
function Seams.ItemBindType(itemID) return (select(14, C_Item.GetItemInfo(itemID))) end
function Seams.NumSlots(bag) return C_Container.GetContainerNumSlots(bag) end
function Seams.SlotInfo(bag, slot) return C_Container.GetContainerItemInfo(bag, slot) end
function Seams.FreeSlots(bag) return (C_Container.GetContainerNumFreeSlots(bag)) end
function Seams.UseContainerItem(bag, slot) return C_Container.UseContainerItem(bag, slot) end
function Seams.BagRange()
  local first = Enum.BagIndex and Enum.BagIndex.Backpack or 0
  local last = NUM_BAG_SLOTS or 4
  return first, last
end

-------------------------------------------------------------------------------
-- Achievements, quests
-------------------------------------------------------------------------------
-- id, name, points, completed, month, day, year, description, flags, icon,
-- rewardText, isGuild, wasEarnedByMe, earnedBy, isStatistic
function Seams.AchievementInfo(achievementID)
  local _, name, _, completed, _, _, _, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(achievementID)
  return name, completed, wasEarnedByMe
end
function Seams.CriteriaCount(achievementID) return GetAchievementNumCriteria(achievementID) end
-- criteriaString, criteriaType, completed, quantity, reqQuantity, ...
function Seams.CriteriaInfo(achievementID, index)
  local text, _, completed, quantity, required = GetAchievementCriteriaInfo(achievementID, index)
  return text, completed, quantity, required
end
function Seams.QuestDone(questID) return C_QuestLog.IsQuestFlaggedCompleted(questID) end
function Seams.QuestObjectives(questID) return C_QuestLog.GetQuestObjectives(questID) end
function Seams.QuestInLog(questID) return (C_QuestLog.GetLogIndexForQuestID(questID)) ~= nil end

-------------------------------------------------------------------------------
-- Gear
-------------------------------------------------------------------------------
function Seams.Watermark(redundancySlot) return C_ItemUpgrade.GetHighWatermarkForSlot(redundancySlot) end
function Seams.UpgradeInfo(link) return C_Item.GetItemUpgradeInfo(link) end
function Seams.InventoryLink(slot) return GetInventoryItemLink("player", slot) end
function Seams.RedundancySlots() return Enum.ItemRedundancySlot end
