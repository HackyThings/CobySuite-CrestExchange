-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Review: the one confirmation, as a page
--
-- Shown while the session is REVIEWING, for a single trade or a multi-tier
-- plan alike, inside the exchange window (no popup). Step cards show each
-- trade with both crests' icons ("30 Veteran  >  10 Champion, 1 pack");
-- under them what you spend and receive in all, the balances before and
-- after, how the plan runs, and a banner that exchanges can't be refunded (a
-- trade down gets its own warning).
--
-- Protections: Confirm sits in the middle of the page, away from where
-- Review was pressed, and only arms a moment after the page appears, so a
-- double press can't accept by accident. Go back (or closing the window)
-- cancels. Confirm sends PurchaseApproved with the reviewed fingerprint;
-- the session refuses it if anything changed since.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = Views.Window
local T = Views.Text
local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local Seasons = CobysCrestExchange.Seasons
local Store = CobysCrestExchange.Store
local E = CobysCrestExchange.Events

local ARM_DELAY = 0.6
local CARDS = 12    -- a plan: up to 4 trades and 8 openings (a tier's trade-up and trade-down packs)
local VISIBLE = 4   -- cards shown at once; more scroll with the mouse wheel
local CARD_H = 34
local MORE_H = 16   -- the "scroll for more" line under them
local BANNER_H = 26
local CONFIRM_H = 28
local CONFIRM_MIN = 34   -- Confirm never sits lower than this, clear of Go back
local GAP = 10

local S = { token = 0, armedFor = nil }

local function Icon(ctx, tierKey)
  local t = ctx.obs.tiers[tierKey]
  return t and t.currency.icon or 134400
end

local function BuildCard(host, i)
  local card = CreateFrame("Frame", nil, host, "BackdropTemplate")
  card:SetHeight(CARD_H - 4)
  card:SetBackdrop(U.Backdrops.CONTENT)
  card:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
  card:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
  card.Num = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  card.Num:SetPoint("LEFT", 8, 0)
  card.FromIcon = card:CreateTexture(nil, "ARTWORK")
  card.FromIcon:SetSize(20, 20)
  card.FromIcon:SetPoint("LEFT", 30, 0)
  card.From = card:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  card.From:SetPoint("LEFT", card.FromIcon, "RIGHT", 4, 0)
  card.Arrow = card:CreateTexture(nil, "ARTWORK")
  card.Arrow:SetAtlas("NPE_ArrowUp")
  card.Arrow:SetRotation(-math.pi / 2)
  card.Arrow:SetSize(14, 14)
  card.Arrow:SetPoint("LEFT", card.From, "RIGHT", 8, 0)
  card.ToIcon = card:CreateTexture(nil, "ARTWORK")
  card.ToIcon:SetSize(20, 20)
  card.ToIcon:SetPoint("LEFT", card.Arrow, "RIGHT", 8, 0)
  card.To = card:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  card.To:SetPoint("LEFT", card.ToIcon, "RIGHT", 4, 0)
  card.Packs = card:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  card.Packs:SetPoint("RIGHT", -8, 0)
  card.Packs:SetTextColor(0.75, 0.75, 0.75)
  return card
end

local function Line(host, font)
  local fs = host:CreateFontString(nil, "OVERLAY", font or U.Fonts.BODY)
  fs:SetJustifyH("LEFT")
  return fs
end

local function Build(host)
  local page = { cards = {} }
  page.Title = Line(host, U.Fonts.HEADING)
  page.Title:SetPoint("TOPLEFT", 4, -4)
  page.Title:SetPoint("TOPRIGHT", -4, -4)
  page.Sub = Line(host, U.Fonts.SMALL)
  page.Sub:SetPoint("TOPLEFT", page.Title, "BOTTOMLEFT", 0, -3)
  page.Sub:SetText("Nothing is bought until you press Confirm.")
  -- The step cards scroll: every step can be read before Confirm
  page.Scroll = CreateFrame("ScrollFrame", nil, host)
  page.Scroll:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -44)
  page.Scroll:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -44)
  page.Scroll:SetHeight(VISIBLE * CARD_H)
  page.List = CreateFrame("Frame", nil, page.Scroll)
  page.List:SetSize(1, CARDS * CARD_H)
  page.Scroll:SetScrollChild(page.List)
  page.Scroll:EnableMouseWheel(true)
  page.Scroll:SetScript("OnMouseWheel", function(self, delta)
    local most = math.max(0, (page.shown or 0) * CARD_H - self:GetHeight())
    self:SetVerticalScroll(math.min(most, math.max(0, self:GetVerticalScroll() - delta * CARD_H)))
  end)
  for i = 1, CARDS do
    local card = BuildCard(page.List, i)
    card:SetPoint("TOPLEFT", page.List, "TOPLEFT", 0, -(i - 1) * CARD_H)
    card:SetPoint("TOPRIGHT", page.List, "TOPRIGHT", 0, -(i - 1) * CARD_H)
    page.cards[i] = card
  end
  page.More = Line(host, U.Fonts.SMALL)
  page.More:SetPoint("TOPLEFT", page.Scroll, "BOTTOMLEFT", 4, -2)
  page.More:SetTextColor(0.65, 0.65, 0.65)
  page.Totals = Line(host)
  page.Totals:SetSpacing(3)
  page.Balances = Line(host, U.Fonts.DATA)
  page.Balances:SetSpacing(2)
  page.Info = Line(host, U.Fonts.SMALL)
  page.Info:SetSpacing(2)
  page.Banner = CreateFrame("Frame", nil, host, "BackdropTemplate")
  page.Banner:SetBackdrop(U.Backdrops.CONTENT)
  page.Banner:SetBackdropColor(0.25, 0.04, 0.04, 0.9)
  local red = U.Colors.WARNING_RED
  page.Banner:SetBackdropBorderColor(red[1], red[2], red[3], 0.9)
  page.Banner:SetHeight(BANNER_H)
  page.Banner.Icon = page.Banner:CreateTexture(nil, "ARTWORK")
  page.Banner.Icon:SetAtlas("AdventureMapIcon-Lock")
  page.Banner.Icon:SetSize(16, 16)
  page.Banner.Icon:SetPoint("LEFT", 8, 0)
  page.Banner.Text = page.Banner:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Banner.Text:SetPoint("LEFT", page.Banner.Icon, "RIGHT", 6, 0)
  page.Banner.Text:SetText("Exchanges can't be refunded.")
  page.Confirm = UI.CreateButton(host, { text = "Confirm", size = { 220, CONFIRM_H },
    point = { "BOTTOM", host, "BOTTOM", 0, CONFIRM_MIN },
    onClick = function() Views.Review.Accept() end })
  page.Back = UI.CreateButton(host, { text = "Go back", size = { 90, 22 }, point = { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 },
    onClick = function() CobysCrestExchange.EventBus:Fire(E.SessionCommand, "cancel_review") end })
  -- Leaving the page disarms Confirm, so the next review waits again
  host:HookScript("OnHide", function() S.armedFor = nil; S.token = S.token + 1 end)
  return page
end

-- The trades to show, as steps: a plan's steps, or one step for a single trade
local function Steps(view, quote)
  if view.frozenPlan then return view.frozenPlan.steps, view.frozenPlan end
  if not quote or quote.status ~= "ok" then return {}, nil end
  return { { from = quote.sourceTier, to = quote.destTier, spend = quote.spend, packs = quote.packs,
    yield = quote.yield, down = quote.direction == "down" } }, nil
end

local function FillCards(page, ctx, steps)
  for i, card in ipairs(page.cards) do
    local s = steps[i]
    card:SetShown(s ~= nil)
    if s then
      card.Num:SetText(#steps > 1 and tostring(i) or "")
      card.FromIcon:SetPoint("LEFT", #steps > 1 and 30 or 10, 0)
      if s.kind == "open" then
        -- Packs already in your bags: the pack's own icon, nothing spent
        card.FromIcon:SetTexture(s.itemID and CobysCrestExchange.Seams.Call("ItemIcon", s.itemID) or Icon(ctx, s.to))
        card.From:SetText("Open the packs you have")
      else
        card.FromIcon:SetTexture(Icon(ctx, s.from))
        card.From:SetText(T.Crests(ctx.season, s.from, s.spend))
      end
      card.ToIcon:SetTexture(Icon(ctx, s.to))
      card.To:SetText(T.Crests(ctx.season, s.to, s.packs * s.yield))
      card.Packs:SetText(T.Packs(s.packs))
      local hex = T.TierColor(ctx.season, s.to)
      local r, g, b = U.HexToRGB(hex)
      card:SetBackdropBorderColor(r, g, b, 0.9)
    end
  end
end

local function TotalsText(ctx, steps, plan, quote)
  local spend, receiveKey, receive = {}, nil, 0
  if plan then
    for _, tier in ipairs(ctx.season.tiers) do
      local n = plan.spendBy and plan.spendBy[tier.key]
      if n and n > 0 then spend[#spend + 1] = T.Crests(ctx.season, tier.key, n) end
    end
    receiveKey, receive = plan.target, plan.crests
  else
    spend[1] = T.Crests(ctx.season, quote.sourceTier, quote.spend)
    receiveKey, receive = quote.destTier, quote.crests
  end
  if #spend == 0 then spend[1] = "nothing from your balances" end
  local text = string.format("|cffffd100You spend|r   %s\n|cffffd100You receive|r   %s", table.concat(spend, ", "),
    T.Crests(ctx.season, receiveKey, receive))
  -- A plan's totals are what leaves your balances: each later step also spends
  -- the crests the step before it made, so the steps add up to more
  if plan and #steps > 1 then
    text = text .. "\n" .. U.WrapColor(U.Colors.LABEL_GRAY,
      "Each step after the first also spends the crests the step before it made, so the steps add up to more than you spend.")
  end
  return text
end

local function BalancesText(ctx, plan, quote)
  local parts = {}
  for _, tier in ipairs(ctx.season.tiers) do
    local before, after
    if plan then
      before, after = plan.before and plan.before[tier.key], plan.after and plan.after[tier.key]
    elseif tier.key == quote.sourceTier then
      before, after = quote.sourceBefore, quote.sourceAfter
    elseif tier.key == quote.destTier then
      before, after = quote.destBefore, quote.destAfterOpen
    end
    if before and after and before ~= after then
      parts[#parts + 1] = string.format("%s %s > %s", T.Tier(ctx.season, tier.key), T.Count(before), T.Count(after))
    end
  end
  return "After the packs open:  " .. table.concat(parts, "   ")
end

local function InfoText(ctx, steps, plan, quote)
  local lines = {}
  if plan and CobysCrestExchange.Plan.OpenOnly(plan) then
    lines[#lines + 1] = "Nothing is bought: one press opens each of your packs. The window always shows the next press."
  elseif plan then
    lines[#lines + 1] = "Each step is bought, then its packs are opened, one press per pack, before the next step. The window always shows the next press."
  else
    lines[#lines + 1] = "After buying, open the packs with one press each."
  end
  for _, s in ipairs(steps) do
    if s.down then
      lines[#lines + 1] = U.WrapColor(U.Colors.CAUTION_ORANGE,
        T.DownWarning(ctx.season, s.from, s.to, s.spend, s.packs * s.yield))
    end
  end
  if Seasons.CAPABILITIES.autoOpenAfterClose and Store.GetAutoOpen() then
    lines[#lines + 1] = "Packs open by themselves after you close Vaskarn, one at a time."
  end
  return table.concat(lines, "\n")
end

-- The refund banner and Confirm sit GAP below the text, or as low
-- as Go back allows when the text is long. Confirm stays centered, away from
-- the bottom-right corner where Review was pressed.
local function PlaceBanner(page, count)
  local width = page.frame:GetWidth() - 8
  local used = 44 + math.min(count, VISIBLE) * CARD_H + (count > VISIBLE and MORE_H or 0) + 10
  for _, fs in ipairs({ page.Totals, page.Balances, page.Info }) do
    fs:SetWidth(width)
    used = used + fs:GetStringHeight() + 8
  end
  -- the banner's bottom, measured up from the page's bottom
  local below = page.frame:GetHeight() - used - GAP - BANNER_H
  local bannerBottom = math.max(CONFIRM_MIN + CONFIRM_H + 8, below)
  page.Banner:ClearAllPoints()
  page.Banner:SetPoint("BOTTOMLEFT", page.frame, "BOTTOMLEFT", 0, bannerBottom)
  page.Banner:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT", 0, bannerBottom)
  page.Confirm:ClearAllPoints()
  page.Confirm:SetPoint("BOTTOM", page.frame, "BOTTOM", 0, bannerBottom - 8 - CONFIRM_H)
end

-- Arm Confirm a moment after the page shows, once per review
local function Arm(page, key)
  if S.armedFor == key then return end
  S.armedFor = key
  S.token = S.token + 1
  local mine = S.token
  page.Confirm:Disable()
  C_Timer.After(ARM_DELAY, function()
    if mine == S.token and page.frame:IsShown() then page.Confirm:Enable() end
  end)
end

local Review = {}
Views.Review = Review

local page = Window.AddPage("review", Build)

function page:Refresh(ctx)
  local view = ctx.view
  local quote = CobysCrestExchange.Quote.Controller.Current()
  local steps, plan = Steps(view, quote)
  if #steps == 0 then return end
  self.current = plan and plan.fingerprint or (quote and quote.fingerprint)
  self.Title:SetText(plan and string.format("Review: %s in %d steps", T.Crests(ctx.season, plan.target, plan.crests), #steps)
    or string.format("Review: %s", T.Crests(ctx.season, quote.destTier, quote.crests)))
  FillCards(self, ctx, steps)
  local count = math.min(#steps, CARDS)
  self.shown = count
  self.List:SetWidth(self.frame:GetWidth())
  self.Scroll:SetHeight(math.min(count, VISIBLE) * CARD_H)
  -- A new review starts at the top; the same one keeps its place as it refreshes
  if self.scrolledFor ~= self.current then
    self.scrolledFor = self.current
    self.Scroll:SetVerticalScroll(0)
  else
    local most = math.max(0, count * CARD_H - self.Scroll:GetHeight())
    self.Scroll:SetVerticalScroll(math.min(most, self.Scroll:GetVerticalScroll()))
  end
  local more = count > VISIBLE
  self.More:SetShown(more)
  if more then self.More:SetText(string.format("Scroll for steps %d to %d", VISIBLE + 1, count)) end
  self.Totals:ClearAllPoints()
  if more then
    self.Totals:SetPoint("TOPLEFT", self.More, "BOTTOMLEFT", 0, -6)
  else
    self.Totals:SetPoint("TOPLEFT", self.Scroll, "BOTTOMLEFT", 4, -6)
  end
  self.Totals:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
  self.Totals:SetText(TotalsText(ctx, steps, plan, quote))
  self.Balances:ClearAllPoints()
  self.Balances:SetPoint("TOPLEFT", self.Totals, "BOTTOMLEFT", 0, -8)
  self.Balances:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
  self.Balances:SetText(BalancesText(ctx, plan, quote))
  self.Info:ClearAllPoints()
  self.Info:SetPoint("TOPLEFT", self.Balances, "BOTTOMLEFT", 0, -8)
  self.Info:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
  self.Info:SetText(InfoText(ctx, steps, plan, quote))
  PlaceBanner(self, #steps)
  local spendText = plan and "Confirm: start the plan" or ("Confirm: spend " .. T.Count(quote.spend) .. " " .. T.TierLabel(ctx.season, quote.sourceTier))
  self.Confirm:SetText(spendText)
  Arm(self, self.current)
end

-- The Confirm press: approve exactly what was reviewed
function Review.Accept()
  if not page.current or not page.Confirm:IsEnabled() then return end
  page.Confirm:Disable()
  S.armedFor = nil
  local autoOpen = Seasons.CAPABILITIES.autoOpenAfterClose and Store.GetAutoOpen()
  CobysCrestExchange.EventBus:Fire(E.PurchaseApproved, page.current, autoOpen)
end
