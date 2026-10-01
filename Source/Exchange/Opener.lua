-------------------------------------------------------------------------------
-- CobysCrestExchange Opener: when a pack may be opened, and what happened
--
-- MayOpen is the gate the secure Open button asks in its PreClick, and the
-- automatic loop asks before each use. It refuses:
--   * in combat (the secure action would refuse anyway)
--   * while any merchant window is open, unless the sell test proved that
--     using a pack by item ID there opens it (CAPABILITIES.openAtVendor);
--     with a merchant open, a bag-slot use sells the item
--   * past the order's quota (at most N copies of the recognized pack)
--   * with no unlocked pack in the bags, or a loot window pending
--   * when the destination has less raw room than one pack holds (the
--     conservative policy until the cap rule is verified)
--
-- Baseline saves the pack count and destination balance when an open
-- starts; Delta returns the packs gone and the crests gained since then (nil
-- when either is unreadable). Session decides what they mean.
-------------------------------------------------------------------------------

local Opener = {}
CobysCrestExchange.Opener = Opener

local Seams = CobysCrestExchange.Seams
local Seasons = CobysCrestExchange.Seasons
local Inventory = CobysCrestExchange.Inventory
local Ledger = CobysCrestExchange.Ledger

local function DestTier(order, obs)
  for _, t in pairs(obs.tiers or {}) do
    if t.tier.currencyID == order.destCurrencyID then return t end
  end
end

-- true, or false and a reason key
function Opener.MayOpen(order, ledger, obs, lootPending)
  if not order then return false, "no_order" end
  if obs.inCombat or Seams.Call("InCombat") then return false, "combat" end
  local merchantOpen = (obs.merchant and obs.merchant.open) or Seams.Call("MerchantShown")
  if merchantOpen and not Seasons.CAPABILITIES.openAtVendor then return false, "merchant_open" end
  if Ledger.OpenQuota(order, ledger) <= 0 then return false, "quota" end
  if lootPending then return false, "loot" end
  local count = obs.packs and obs.packs[order.key] or 0
  if count <= 0 then return false, "no_pack" end
  local bag, why = Inventory.FindSlot(order.itemID)
  if not bag then return false, why == "locked" and "locked" or "no_pack" end
  local dst = DestTier(order, obs)
  if not dst or dst.room.raw == nil then return false, "unknown_room" end
  local product = obs.season and Seasons.ProductByKey(obs.season, order.key)
  if (not product or product.requiresOpeningHeadroom) and dst.room.raw < order.yield then
    return false, "capped"
  end
  return true
end

function Opener.Baseline(order, obs)
  local dst = DestTier(order, obs)
  return { packs = obs.packs and obs.packs[order.key] or 0,
    dest = dst and dst.currency.ok and dst.currency.quantity or 0 }
end

-- packs gone and destination crests gained since base, or nil when unreadable
function Opener.Delta(order, base, obs)
  if not order or not base then return nil end
  local dst = DestTier(order, obs)
  local packsNow = obs.packs and obs.packs[order.key]
  local destNow = dst and dst.currency.ok and dst.currency.quantity
  if packsNow == nil or destNow == nil then return nil end
  return base.packs - packsNow, destNow - base.dest
end

-- One automatic open, only when the capability is verified and no merchant
-- is open. It uses a bag slot, which sells at an open merchant, so it refuses
-- at any merchant whatever openAtVendor says (that flag covers the secure
-- button's item-ID use only). Returns true when a use was sent.
function Opener.AutoStep(order, ledger, obs)
  if not Seasons.CAPABILITIES.autoOpenAfterClose then return false, "not_verified" end
  if (obs.merchant and obs.merchant.open) or Seams.Call("MerchantShown") then return false, "merchant_open" end
  local ok, why = Opener.MayOpen(order, ledger, obs, false)
  if not ok then return false, why end
  local bag, slot = Inventory.FindSlot(order.itemID)
  if not bag then return false, "no_pack" end
  local info = Seams.Call("SlotInfo", bag, slot)
  if type(info) ~= "table" or info.itemID ~= order.itemID or info.isLocked then return false, "no_pack" end
  Seams.Call("UseContainerItem", bag, slot)
  return true
end
