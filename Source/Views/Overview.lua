-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Overview: "Which crests do you need?"
--
-- The crest ladder as tiles (Views.Ladder), Myth on top: each tier's icon,
-- balance, the room left under its cap and crests waiting in unopened packs,
-- with the trade up into it between each pair (open, or locked with a lock).
-- Clicking a tile means "get more of this tier" and opens the source
-- choice; its tooltip names the cap that binds. Unopened packs get a banner
-- with an Open button, so the player opens those before buying more.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = Views.Window
local T = Views.Text
local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local GOLD = U.Colors.STATUS_GOLD
local Currency = CobysCrestExchange.Currency
local Eligibility = CobysCrestExchange.Eligibility
local E = CobysCrestExchange.Events

local function TileTooltip(tip, tierKey)
  local ctx = Window.Context()
  local t = ctx.obs.tiers and ctx.obs.tiers[tierKey]
  if not t then return end
  tip:AddLine(T.Currency(ctx.season, tierKey))
  tip:AddDoubleLine("Balance", T.Count(t.currency.ok and t.currency.quantity or nil), 0.8, 0.8, 0.8, 1, 1, 1)
  local room = t.room
  if room.kind == "none" then
    tip:AddLine("No cap on this tier right now.", 0.8, 0.8, 0.8, true)
  elseif room.kind == "unknown" then
    tip:AddLine("The game isn't reporting this tier's cap.", U.Colors.CAUTION_ORANGE[1], U.Colors.CAUTION_ORANGE[2], U.Colors.CAUTION_ORANGE[3], true)
  else
    tip:AddDoubleLine("Room (" .. T.LimitKind(room.kind) .. ")", T.Count(room.raw), 0.8, 0.8, 0.8, 1, 1, 1)
    if room.season and room.weekly then
      tip:AddDoubleLine("Season room", T.Count(room.season), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
      tip:AddDoubleLine("Weekly room", T.Count(room.weekly), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
    end
    if t.packedCrests > 0 then
      tip:AddDoubleLine("Room after your unopened packs", T.Count(Currency.Uncommitted(room, t.packedCrests, 0)),
        0.8, 0.8, 0.8, 1, 1, 1)
    end
  end
  if t.packs > 0 then
    tip:AddDoubleLine("In unopened packs", T.Count(t.packedCrests) .. " (" .. T.Packs(t.packs) .. ")", 0.8, 0.8, 0.8, 1, 1, 1)
  end
  tip:AddLine(" ")
  tip:AddLine("Click to get more " .. T.TierLabel(ctx.season, tierKey) .. " crests.", unpack(U.Colors.INFO_BLUE))
end

local function OnTile(tierKey)
  Window.Go("source", { tier = tierKey, productKey = nil })
  CobysCrestExchange.EventBus:Fire(E.SelectionChanged, { tier = tierKey })
end

local function BuildBanner(host, page)
  local banner = CreateFrame("Frame", nil, host, "BackdropTemplate")
  banner:SetBackdrop(U.Backdrops.CONTENT)
  banner:SetBackdropColor(0.15, 0.12, 0.02, 0.9)
  banner:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
  banner:SetHeight(34)
  banner.Icon = banner:CreateTexture(nil, "ARTWORK")
  banner.Icon:SetSize(24, 24)
  banner.Icon:SetPoint("LEFT", 6, 0)
  banner.Text = banner:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  banner.Text:SetPoint("LEFT", banner.Icon, "RIGHT", 8, 0)
  banner.Text:SetPoint("RIGHT", -112, 0)
  banner.Text:SetJustifyH("LEFT")
  banner.Button = UI.CreateButton(banner, { text = "Open packs", size = { 100, 22 },
    point = { "RIGHT", banner, "RIGHT", -6, 0 },
    onClick = function()
      if banner.productKey then
        CobysCrestExchange.EventBus:Fire(E.SessionCommand, "open_existing", banner.productKey)
      end
    end })
  page.banner = banner
end

local function Build(host)
  local page = {}
  page.Title = host:CreateFontString(nil, "OVERLAY", U.Fonts.HEADING)
  page.Title:SetPoint("TOPLEFT", 4, -4)
  page.Hint = host:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  page.Hint:SetPoint("TOPRIGHT", -4, -8)
  page.Hint:SetTextColor(0.6, 0.6, 0.6)
  page.Hint:SetText("Click a tier to get more")
  page.ladder = Views.Ladder.Create(host, { top = -28, nodeH = 40, gap = 16, onClick = OnTile })
  for _, node in ipairs(page.ladder.nodes) do
    UI.AddDynamicTooltip(node, function(tip, self) TileTooltip(tip, self.tierKey) end, { fillable = true })
  end
  BuildBanner(host, page)
  page.banner:SetPoint("TOPLEFT", page.ladder.frame, "BOTTOMLEFT", 0, -6)
  page.banner:SetPoint("TOPRIGHT", page.ladder.frame, "BOTTOMRIGHT", 0, -6)
  page.Footer = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.Footer:SetPoint("BOTTOMLEFT", 4, 30)
  page.Footer:SetPoint("BOTTOMRIGHT", -4, 30)
  page.Footer:SetJustifyH("LEFT")
  page.BeforeButton = UI.CreateButton(host, { text = "Before you spend...", size = { 150, 22 },
    point = { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 }, onClick = function() Window.Go("before") end })
  page.LocksButton = UI.CreateButton(host, { text = "Why are trades locked?", size = { 170, 22 },
    point = { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 4 },
    onClick = function() Window.Go("requirements", nil, { "reqKey", "from" }) end })
  return page
end

local function TileSub(t)
  local parts = {}
  if t.room.kind == "none" then
    parts[#parts + 1] = "No cap"
  elseif t.room.kind == "unknown" then
    parts[#parts + 1] = "Cap unknown"
  else
    parts[#parts + 1] = "Room " .. T.Count(t.room.raw)
  end
  if t.packs > 0 then parts[#parts + 1] = T.Count(t.packedCrests) .. " in packs" end
  return table.concat(parts, "  |cff888888|||r  ")
end

-- One pack's price, as the quotes take it: Vaskarn's live offer, else the
-- last one seen at him; nil when he was never visited
local function PackPrice(ctx, key)
  local m = ctx.obs.merchant
  local live = m and m.isExchange and m.offers and m.offers[key]
  if live then return live.costPerUnit, live.yieldPerUnit end
  for _, entry in ipairs(ctx.obs.lastSeen and ctx.obs.lastSeen.list or {}) do
    if entry.key == key then return entry.costPerUnit, entry.yieldPerUnit end
  end
end

-- The trade up into each tier: open, locked, or unknown away from the vendor.
-- It reads "Trade up 30 for 10" (one pack's cost and crests) at Vaskarn and
-- away alike, or "Trade up" before his prices were ever seen. A locked one
-- says why in red, and its hover says what exactly is missing; a click opens
-- the trade's requirements
local function LinkFor(ctx, product)
  local season = ctx.season
  local result = Eligibility.ForTrade(season, product, ctx.obs)
  local cost, yield = PackPrice(ctx, product.key)
  local name = cost and yield and string.format("Trade up %s for %s", T.Count(cost), T.Count(yield)) or "Trade up"
  if result.state == "locked" then
    return { state = "locked",
      label = U.WrapColor(U.Colors.LABEL_GRAY, name .. ":  ")
        .. U.WrapColor(U.Colors.WARNING_RED, Views.Requirements.ShortReason(result)),
      tooltip = function(tip) Views.Requirements.AddTooltip(tip, season, product, result) end,
      onClick = function() Window.Go("requirements", { reqKey = product.key, from = "overview" }) end }
  end
  return { state = "idle", label = U.WrapColor(U.Colors.LABEL_GRAY, name) }
end

local function Model(ctx)
  local model = { season = ctx.season, nodes = {}, links = {} }
  for _, tier in ipairs(ctx.season.tiers) do
    local t = ctx.obs.tiers[tier.key]
    if t then
      model.nodes[tier.key] = { value = T.Count(t.currency.ok and t.currency.quantity or nil), sub = TileSub(t),
        icon = t.currency.icon }
    end
  end
  for _, product in ipairs(ctx.season.products) do
    if product.kind == "up" then model.links[product.to] = LinkFor(ctx, product) end
  end
  return model
end

local function RefreshBanner(page, ctx)
  local banner = page.banner
  banner.productKey = nil
  if not ctx.view.order and not ctx.view.plan then
    for _, product in ipairs(ctx.season.products) do
      local n = ctx.obs.packs[product.key] or 0
      if n > 0 and not banner.productKey then
        banner.productKey = product.key
        banner.Icon:SetTexture(product.itemID and CobysCrestExchange.Seams.Call("ItemIcon", product.itemID) or 134400)
        banner.Text:SetText(string.format("%s of %s waiting (%s crests)",
          T.Packs(n), T.Tier(ctx.season, product.to), T.Count(n * product.yield)))
      end
    end
  end
  banner:SetShown(banner.productKey ~= nil)
end

local function RefreshFooter(page, ctx)
  local lines = {}
  local notice = ctx.view.state == "COMPLETE" and nil or T.Notice(ctx.view.notice)
  if notice then lines[#lines + 1] = notice end
  if not (ctx.obs.merchant and ctx.obs.merchant.isExchange) then
    local seen = ctx.obs.lastSeen
    lines[#lines + 1] = seen and seen.seenAt and seen.seenAt > 0
      and ("Trades last seen at Vaskarn on " .. T.Date(seen.seenAt) .. ". Visit him in Silvermoon to exchange.")
      or "Visit Vaskarn in Silvermoon to exchange."
  end
  if ctx.view.advisorOnly then
    lines[#lines + 1] = "Buying from this window was refused by the game. Buy from Vaskarn's own list; this window keeps counting."
  end
  page.Footer:SetText(table.concat(lines, "\n"))
end

local page = Window.AddPage("overview", Build)
function page:Refresh(ctx)
  if not ctx.season then
    self.Title:SetText("This season's crests aren't known to this version yet.")
    self.ladder:Render(nil)
    self.banner:Hide()
    self.Footer:SetText("Type /ce dump for a report you can send in.")
    return
  end
  self.Title:SetText("Which crests do you need?")
  self.ladder:Render(Model(ctx))
  RefreshBanner(self, ctx)
  RefreshFooter(self, ctx)
end
