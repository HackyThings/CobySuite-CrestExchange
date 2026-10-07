-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Overview: "Which crests do you need?"
--
-- The crest ladder as tiles (Views.Ladder), Myth on top: each tier's icon,
-- balance, and its cap as a meter filling the tile in the tier's color (a
-- fainter band for crests in unopened packs, a check and MAX when no room is
-- left), with the trade up into it between each pair (quiet when open, its
-- reason in red when locked).
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
local Store = CobysCrestExchange.Store

-- Whether this character has finished an exchange this season (its history
-- holds one that received crests)
local function Exchanged()
  for _, h in ipairs(Store.GetHistory()) do
    if (h.received or 0) > 0 then return true end
  end
  return false
end

local function TileTooltip(tip, tierKey)
  local ctx = Window.Context()
  local t = ctx.obs.tiers and ctx.obs.tiers[tierKey]
  if not t then return end
  tip:AddLine(T.Currency(ctx.season, tierKey))
  tip:AddDoubleLine("Balance", T.Count(t.currency.ok and t.currency.quantity or nil), 0.8, 0.8, 0.8, 1, 1, 1)
  local room = t.room
  if room.kind == "none" then
    -- Task #297: a lifted season cap reads as the earned total over the infinity sign
    if not T.NoSeasonCapLines(t, function(label, value) tip:AddDoubleLine(label, value, 0.8, 0.8, 0.8, 1, 1, 1) end,
        function(text) tip:AddLine(text, 0.8, 0.8, 0.8, true) end) then
      tip:AddLine("No cap on this tier right now.", 0.8, 0.8, 0.8, true)
    end
  elseif room.kind == "unknown" then
    tip:AddLine("The game isn't reporting this tier's cap.", U.Colors.CAUTION_ORANGE[1], U.Colors.CAUTION_ORANGE[2], U.Colors.CAUTION_ORANGE[3], true)
  else
    -- Each cap that applies, with its numbers, then the room the binding one leaves
    local c = t.currency
    if room.season ~= nil then
      local seasonUsed = c.useTotalEarned and c.totalEarned or c.quantity
      tip:AddDoubleLine(c.useTotalEarned and "Season earned" or "Held",
        T.Count(seasonUsed) .. "/" .. T.Count(c.maxQuantity), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    if room.season == nil then
      -- Only the weekly cap is left: the season's is lifted
      T.NoSeasonCapLines(t, function(label, value) tip:AddDoubleLine(label, value, 0.8, 0.8, 0.8, 1, 1, 1) end,
        function(text) tip:AddLine(text, 0.8, 0.8, 0.8, true) end)
    end
    if room.weekly ~= nil then
      tip:AddDoubleLine("Earned this week", T.Count(c.earnedThisWeek) .. "/" .. T.Count(c.maxWeekly), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    tip:AddDoubleLine("Room for more crests", T.Count(room.raw), 0.8, 0.8, 0.8, 1, 1, 1)
    if t.packs > 0 then
      tip:AddDoubleLine("In unopened packs", T.Count(t.packedCrests) .. " (" .. T.Packs(t.packs) .. ")", 0.8, 0.8, 0.8, 1, 1, 1)
      tip:AddDoubleLine("Room after unopened packs", T.Count(Currency.Uncommitted(room, t.packedCrests, 0)),
        0.8, 0.8, 0.8, 1, 1, 1)
      tip:AddLine("The faint band shows unopened crests that fit under this cap.", 0.65, 0.65, 0.65, true)
    end
    if room.season ~= nil and room.weekly ~= nil then
      tip:AddLine("Both limits apply. The meter shows the one with less room.", 0.8, 0.8, 0.8, true)
    end
    -- What frees each cap
    if room.season ~= nil then
      tip:AddLine(c.useTotalEarned and "Spending crests does not lower the season total. Season caps usually rise at weekly resets."
        or "Spending some makes room again.", 0.8, 0.8, 0.8, true)
    end
    if room.weekly ~= nil then tip:AddLine("The weekly total resets each week.", 0.8, 0.8, 0.8, true) end
  end
  if room.kind == "none" or room.kind == "unknown" then
    if t.packs > 0 then
      tip:AddDoubleLine("In unopened packs", T.Count(t.packedCrests) .. " (" .. T.Packs(t.packs) .. ")", 0.8, 0.8, 0.8, 1, 1, 1)
    end
  end
  tip:AddLine(" ")
  tip:AddLine("Click to get more " .. T.TierLabel(ctx.season, tierKey) .. " crests.", unpack(U.Colors.INFO_BLUE))
end

local function OnTile(tierKey)
  Window.Go("source", { tier = tierKey, productKey = nil })
  CobysCrestExchange.EventBus:Fire(E.SelectionChanged, { tier = tierKey })
end

-- A framed strip under the ladder: an icon and a line or two of text
local function Strip(host, font, rightInset)
  local strip = CreateFrame("Frame", nil, host, "BackdropTemplate")
  strip:SetBackdrop(U.Backdrops.CONTENT)
  strip:SetBackdropColor(0.15, 0.12, 0.02, 0.9)
  strip:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
  strip:SetHeight(34)
  strip.Icon = strip:CreateTexture(nil, "ARTWORK")
  strip.Icon:SetSize(24, 24)
  strip.Icon:SetPoint("LEFT", 6, 0)
  strip.Text = strip:CreateFontString(nil, "OVERLAY", font)
  strip.Text:SetPoint("LEFT", strip.Icon, "RIGHT", 8, 0)
  strip.Text:SetPoint("RIGHT", -rightInset, 0)
  strip.Text:SetJustifyH("LEFT")
  strip.Text:SetMaxLines(2)
  return strip
end

local function BuildBanner(host, page)
  local banner = Strip(host, U.Fonts.BODY, 112)
  banner.Button = UI.CreateButton(banner, { text = "Open packs", size = { 100, 22 },
    point = { "RIGHT", banner, "RIGHT", -6, 0 },
    onClick = function()
      if banner.productKey then
        CobysCrestExchange.EventBus:Fire(E.SessionCommand, "open_existing", banner.productKey)
      end
    end })
  page.banner = banner
  -- Until the first exchange: the whole flow in one line (Task #236)
  local first = Strip(host, U.Fonts.SMALL, 8)
  first.Icon:SetTexture(CobysCrestExchange.ICON)
  first.Text:SetText("Your first exchange: click a tier, say how many, check the cost on Review, then buy and open the packs.")
  page.first = first
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
  page.first:SetAllPoints(page.banner)
  page.Footer = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.Footer:SetPoint("BOTTOMLEFT", 4, 30)
  page.Footer:SetPoint("BOTTOMRIGHT", -4, 30)
  page.Footer:SetJustifyH("LEFT")
  page.BeforeButton = UI.CreateButton(host, { text = "Before you spend...", size = { 150, 22 },
    point = { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 }, onClick = function() Window.Go("before") end })
  page.LocksButton = UI.CreateButton(host, { text = "Trade requirements", size = { 170, 22 },
    point = { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 4 },
    onClick = function() Window.Go("requirements", nil, { "reqKey", "from" }) end })
  return page
end

-- The line under a tier's name: its cap meter's words (Task #247), or No cap
-- and Cap unknown
local function TileSub(t, meter)
  if meter then return T.MeterLine(meter) end
  if t.room.kind == "none" then return "No cap" end
  return "Cap unknown"
end

-- The trade up into each tier: only a locked one says anything (why, in
-- red; its hover says what exactly is missing, a click opens its
-- requirements). An open trade is priced on the Get page, so its line stays
-- quiet (Cobanyte, 2026-10-05: "Trade up 30 for 10" wasn't helpful)
local function LinkFor(ctx, product)
  local season = ctx.season
  local result = Eligibility.ForTrade(season, product, ctx.obs)
  if result.state == "locked" then
    return { state = "locked",
      label = U.WrapColor(U.Colors.LABEL_GRAY, "Locked:  ")
        .. U.WrapColor(U.Colors.WARNING_RED, Views.Requirements.ShortReason(result)),
      tooltip = function(tip) Views.Requirements.AddTooltip(tip, season, product, result) end,
      onClick = function() Window.Go("requirements", { reqKey = product.key, from = "overview" }) end }
  end
  return { state = "idle" }
end

local function Model(ctx)
  local model = { season = ctx.season, nodes = {}, links = {} }
  for _, tier in ipairs(ctx.season.tiers) do
    local t = ctx.obs.tiers[tier.key]
    if t then
      local meter = T.CapMeter(t)
      model.nodes[tier.key] = { value = T.Count(t.currency.ok and t.currency.quantity or nil), sub = TileSub(t, meter),
        icon = t.currency.icon, meter = meter }
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
    -- A kind of pack that can open now comes first (a reward pack the cap
    -- keeps shut would only refuse); else the first one held
    local chosen, fallback
    for _, product in ipairs(ctx.season.products) do
      local n = ctx.obs.packs[product.key] or 0
      local t = ctx.obs.tiers[product.to]
      if n > 0 and t then
        if (Currency.Openable(t.room, t.packList).byKey[product.key] or 0) > 0 then
          chosen = chosen or product
        else
          fallback = fallback or product
        end
      end
    end
    local product = chosen or fallback
    if product then
      local n = ctx.obs.packs[product.key]
      banner.productKey = product.key
      banner.Icon:SetTexture(product.itemID and CobysCrestExchange.Seams.Call("ItemIcon", product.itemID) or 134400)
      banner.Text:SetText(string.format("%s of %s waiting (%s crests)",
        T.Packs(n), T.Tier(ctx.season, product.to), T.Count(n * product.yield)))
    end
  end
  banner:SetShown(banner.productKey ~= nil)
end

-- The first-exchange line gives way to the banner, to anything under way and
-- to a footer of more than one line (a notice, or a refused buy), so it never
-- crowds what the player has to act on
local function RefreshFirst(page, ctx)
  local footerFits = (page.Footer:GetStringHeight() or 0) <= 16 and not ctx.view.advisorOnly
  page.first:SetShown(not page.banner:IsShown() and not ctx.view.order and not ctx.view.plan and footerFits
    and not Exchanged())
end

local function RefreshFooter(page, ctx)
  local lines = {}
  local notice = T.Notice(ctx.view.notice)
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
    self.first:Hide()
    self.Footer:SetText("Type /ce dump for a report you can send in.")
    return
  end
  self.Title:SetText("Which crests do you need?")
  self.ladder:Render(Model(ctx))
  RefreshBanner(self, ctx)
  RefreshFooter(self, ctx)
  RefreshFirst(self, ctx)
end
