-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Review: the one confirmation, as a page
--
-- Shown while the session is REVIEWING, for a single trade or a multi-tier
-- plan alike, inside the exchange window (no popup). Step cards show each
-- trade with both crests' icons ("30 Veteran  >  10 Champion, 1 pack");
-- under them what you spend and receive in all, as aligned rows (label, the
-- crest's icon, the amount, and its balance before and after the packs open;
-- hovering a row shows the crest's own tooltip), how the plan runs, and a
-- banner that exchanges can't be refunded (a trade down gets its own
-- warning).
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
local ROWS = 6      -- spend rows (a plan spends up to four tiers) and the receive row
local ROW_H = 20
local LABEL_W = 84  -- "You receive" and the gap after it
local HEAD_H = 14   -- the small "Balance now to after opening" heading over the rows

local S = { token = 0, armedFor = nil }

local function Icon(ctx, tierKey)
  local t = ctx.obs.tiers[tierKey]
  return t and t.currency.icon or 134400
end

local function BuildCard(host)
  local card = CreateFrame("Frame", nil, host, "BackdropTemplate")
  card:SetHeight(CARD_H - 4)
  card:SetBackdrop(U.Backdrops.CONTENT)
  card:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
  card:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
  card.Num = card:CreateFontString(nil, "OVERLAY", U.Fonts.TITLE)
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

-- Fills tip (GameTooltip on a hover, or a Verify grid tip) for one row's entry
local function FillRowTooltip(tip, e)
  -- The game's currency tooltip only for a currency it knows: for one it
  -- doesn't, SetCurrencyByID hides the tip and the lines below go nowhere
  local okData, data = pcall(C_TooltipInfo.GetCurrencyByID, e.currencyID)
  local ok = e.currencyID and okData and data and pcall(tip.SetCurrencyByID, tip, e.currencyID)
  if not ok then tip:SetText(e.name or "") end
  if e.n then
    tip:AddLine(" ")
    tip:AddLine(string.format(e.spend and "This exchange spends %s." or "This exchange gives %s.", e.text), 1, 1, 1, true)
  end
  if e.before and e.after then
    tip:AddLine(string.format("Your balance: %s now, %s after the packs open.", T.Count(e.before), T.Count(e.after)),
      1, 1, 1, true)
  end
end

local function RowTooltip(row)
  local e = row.entry
  if not e then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  FillRowTooltip(GameTooltip, e)
  GameTooltip:Show()
end

local function BuildRow(host)
  local row = CreateFrame("Frame", nil, host)
  row:SetHeight(ROW_H)
  row:EnableMouse(true)
  UI.AddHoverHighlight(row)
  row.Label = row:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  row.Label:SetPoint("LEFT", 0, 0)
  row.Label:SetWidth(LABEL_W)
  row.Label:SetJustifyH("LEFT")
  local gold = U.Colors.STATUS_GOLD
  row.Label:SetTextColor(gold[1], gold[2], gold[3])
  row.Icon = row:CreateTexture(nil, "ARTWORK")
  row.Icon:SetSize(16, 16)
  row.Icon:SetPoint("LEFT", LABEL_W, 0)
  row.Amount = row:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  row.Amount:SetJustifyH("LEFT")
  row.Balance = row:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  row.Balance:SetPoint("RIGHT", -4, 0)
  row.Balance:SetJustifyH("RIGHT")
  local gray = U.Colors.LIGHT_GRAY
  row.Balance:SetTextColor(gray[1], gray[2], gray[3])
  row:SetScript("OnEnter", RowTooltip)
  row:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
  return row
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
    local card = BuildCard(page.List)
    card:SetPoint("TOPLEFT", page.List, "TOPLEFT", 0, -(i - 1) * CARD_H)
    card:SetPoint("TOPRIGHT", page.List, "TOPRIGHT", 0, -(i - 1) * CARD_H)
    page.cards[i] = card
  end
  page.More = Line(host, U.Fonts.SMALL)
  page.More:SetPoint("TOPLEFT", page.Scroll, "BOTTOMLEFT", 4, -2)
  page.More:SetTextColor(0.65, 0.65, 0.65)
  -- What you spend and receive, as aligned rows under a small heading
  page.Rows = CreateFrame("Frame", nil, host)
  page.Rows:SetHeight(HEAD_H)
  local gray = U.Colors.LABEL_GRAY
  page.BalanceHead = page.Rows:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.BalanceHead:SetPoint("TOPRIGHT", page.Rows, "TOPRIGHT", -4, 0)
  page.BalanceHead:SetText("Balance now to after opening")
  page.BalanceHead:SetTextColor(gray[1], gray[2], gray[3])
  page.rows = {}
  for i = 1, ROWS do
    local row = BuildRow(page.Rows)
    row:SetPoint("TOPLEFT", page.Rows, "TOPLEFT", 0, -HEAD_H - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", page.Rows, "TOPRIGHT", 0, -HEAD_H - (i - 1) * ROW_H)
    page.rows[i] = row
  end
  page.Note = Line(host, U.Fonts.SMALL)
  page.Note:SetSpacing(2)
  page.Note:SetTextColor(gray[1], gray[2], gray[3])
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

-- A tier's balance now and after the packs open, or nil when it doesn't change
local function BeforeAfter(plan, quote, tierKey)
  local before, after
  if plan then
    before, after = plan.before and plan.before[tierKey], plan.after and plan.after[tierKey]
  elseif tierKey == quote.sourceTier then
    before, after = quote.sourceBefore, quote.sourceAfter
  elseif tierKey == quote.destTier then
    before, after = quote.destBefore, quote.destAfterOpen
  end
  if before and after and before ~= after then return before, after end
end

-- The rows: each tier you spend, then the tier you receive
local function Entries(ctx, plan, quote)
  local list = {}
  local function Add(label, tierKey, n, spend)
    local t = ctx.obs.tiers[tierKey]
    local before, after = BeforeAfter(plan, quote, tierKey)
    list[#list + 1] = { label = label, key = tierKey, n = n, spend = spend, text = T.Crests(ctx.season, tierKey, n),
      name = T.Currency(ctx.season, tierKey), currencyID = t and t.tier and t.tier.currencyID,
      icon = Icon(ctx, tierKey), before = before, after = after }
  end
  if plan then
    for _, tier in ipairs(ctx.season.tiers) do
      local n = plan.spendBy and plan.spendBy[tier.key]
      if n and n > 0 and #list < ROWS - 1 then Add(#list == 0 and "You spend" or "", tier.key, n, true) end
    end
    -- Opening packs you have spends no balance
    if #list == 0 then list[1] = { label = "You spend", text = "nothing from your balances" } end
    Add("You receive", plan.target, plan.crests, false)
  else
    Add("You spend", quote.sourceTier, quote.spend, true)
    Add("You receive", quote.destTier, quote.crests, false)
  end
  return list
end

local function FillRows(page, entries)
  for i, row in ipairs(page.rows) do
    local e = entries[i]
    row:SetShown(e ~= nil)
    row.entry = e
    if e then
      row.Label:SetText(e.label)
      row.Icon:SetShown(e.icon ~= nil)
      if e.icon then row.Icon:SetTexture(e.icon) end
      row.Amount:ClearAllPoints()
      if e.icon then
        row.Amount:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
      else
        row.Amount:SetPoint("LEFT", row, "LEFT", LABEL_W, 0)
      end
      row.Amount:SetText(e.text)
      row.Balance:SetText(e.before and T.Change(e.before, e.after) or "")
      row:EnableMouse(e.n ~= nil)
    end
  end
  page.Rows:SetHeight(HEAD_H + #entries * ROW_H)
end

-- Tiers whose balance changes but have no row of their own (a plan's
-- passing tiers, when they don't come out even)
local function OtherBalances(ctx, plan, quote, entries)
  local shown, parts = {}, {}
  for _, e in ipairs(entries) do if e.key then shown[e.key] = true end end
  for _, tier in ipairs(ctx.season.tiers) do
    local before, after = BeforeAfter(plan, quote, tier.key)
    if before and not shown[tier.key] then
      parts[#parts + 1] = T.Tier(ctx.season, tier.key) .. " " .. T.Change(before, after)
    end
  end
  if #parts == 0 then return "" end
  return "Also after the packs open:  " .. table.concat(parts, "   ")
end

-- What the presses after Confirm look like: how many steps buy, whether
-- Vaskarn is needed again, and how many packs open in all
local function InfoText(ctx, steps, plan)
  local lines = {}
  local buys, opens, packs = 0, 0, 0
  for _, s in ipairs(steps) do
    packs = packs + (s.packs or 0)
    if s.kind == "open" then opens = opens + 1 else buys = buys + 1 end
  end
  -- The Get page's own wording, so both pages tell the same story
  -- The packs to open join the same line, so a long plan keeps room for its cards
  local flow = Views.Get.FlowWords(buys, opens)
  if plan then flow = flow .. string.format(" %s to open in all.", T.Packs(packs)) end
  lines[#lines + 1] = flow
  for _, s in ipairs(steps) do
    if s.down then
      -- The refund banner under this says it can't be undone
      lines[#lines + 1] = U.WrapColor(U.Colors.CAUTION_ORANGE,
        T.DownWarning(ctx.season, s.from, s.to, s.spend, s.packs * s.yield, true))
    end
  end
  if Seasons.CAPABILITIES.autoOpenAfterClose and Store.GetAutoOpen() then
    lines[#lines + 1] = "Packs open by themselves after you close Vaskarn, one at a time."
  end
  return table.concat(lines, "\n")
end

-- How many step cards show at once: up to VISIBLE, fewer when the rows and
-- text under them need the room, so nothing runs under the banner (the rest
-- scroll). Returns the count and whether it fits.
local function FitCards(page, count)
  local width = page.frame:GetWidth() - 8
  local below = page.Rows:GetHeight() + 6
  for _, fs in ipairs({ page.Note, page.Balances, page.Info }) do
    fs:SetWidth(width)
    if fs:IsShown() and (fs:GetText() or "") ~= "" then below = below + fs:GetStringHeight() + 8 end
  end
  local room = page.frame:GetHeight() - 44 - 10 - below - GAP - BANNER_H - (CONFIRM_MIN + CONFIRM_H + 8)
  local shown = math.min(count, VISIBLE)
  local function Need(n) return n * CARD_H + (count > n and MORE_H or 0) end
  while shown > 1 and Need(shown) > room do shown = shown - 1 end
  return shown, Need(shown) <= room
end

-- The refund banner and Confirm sit GAP below the text, or as low
-- as Go back allows when the text is long. Confirm stays centered, away from
-- the bottom-right corner where Review was pressed.
local function PlaceBanner(page, count)
  local width = page.frame:GetWidth() - 8
  local visible = page.visible or VISIBLE
  local used = 44 + math.min(count, visible) * CARD_H + (count > visible and MORE_H or 0) + 10
  used = used + page.Rows:GetHeight() + 6
  for _, fs in ipairs({ page.Note, page.Balances, page.Info }) do
    fs:SetWidth(width)
    if fs:IsShown() and (fs:GetText() or "") ~= "" then used = used + fs:GetStringHeight() + 8 end
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
    if mine == S.token and page.frame:IsShown() and not CobysCrestExchange.Session.SceneLocked() then
      page.Confirm:Enable()
    end
  end)
end

local Review = {}
Views.Review = Review
Review.FillRowTooltip = FillRowTooltip

-- Whether a later trade spends crests an earlier step made (opening packs
-- you have spends nothing)
local function Chained(steps)
  for i = 2, #steps do
    local s = steps[i]
    if s.kind ~= "open" then
      for j = 1, i - 1 do
        if steps[j].to == s.from then return true end
      end
    end
  end
  return false
end

local page = Window.AddPage("review", Build)

function page:Refresh(ctx)
  local view = ctx.view
  local quote = CobysCrestExchange.Quote.Controller.Current()
  local steps, plan = Steps(view, quote)
  if #steps == 0 then return end
  self.current = plan and plan.fingerprint or (quote and quote.fingerprint)
  self.Title:SetText(plan and string.format("Review: %s in %d %s", T.Crests(ctx.season, plan.target, plan.crests), #steps,
      T.Plural(#steps, "step", "steps"))
    or string.format("Review: %s", T.Crests(ctx.season, quote.destTier, quote.crests)))
  FillCards(self, ctx, steps)
  local count = math.min(#steps, CARDS)
  self.shown = count
  self.List:SetWidth(self.frame:GetWidth())
  local entries = Entries(ctx, plan, quote)
  FillRows(self, entries)
  -- Under the rows: a plan's note, then any other balance that changes
  local anchor = self.Rows
  local function Next(fs, text)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    fs:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
    fs:SetText(text)
    fs:SetShown(text ~= "")
    if text ~= "" then anchor = fs end
  end
  -- A plan's totals are what leaves your balances: when a later trade spends
  -- crests an earlier step made, the steps add up to more
  Next(self.Note, (plan and Chained(steps))
    and "A step can spend crests the step before it made, so the steps add up to more than you spend." or "")
  Next(self.Balances, OtherBalances(ctx, plan, quote, entries))
  self.Info:ClearAllPoints()
  self.Info:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
  self.Info:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
  self.Info:SetText(InfoText(ctx, steps, plan))
  local visible, fits = FitCards(self, count)
  if (not fits or visible < math.min(count, 2)) and self.Note:IsShown() then
    -- Too tall, or room for only one of several cards: the plan's side note
    -- gives way first (a plan's steps matter more), and the balances line
    -- folds up after it
    self.Note:Hide()
    self.Balances:ClearAllPoints()
    self.Balances:SetPoint("TOPLEFT", self.Rows, "BOTTOMLEFT", 0, -6)
    self.Balances:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
    self.Info:ClearAllPoints()
    self.Info:SetPoint("TOPLEFT", self.Balances:IsShown() and self.Balances or self.Rows, "BOTTOMLEFT", 0, -8)
    self.Info:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
    visible = FitCards(self, count)
  end
  self.visible = visible
  self.Scroll:SetHeight(visible * CARD_H)
  -- A new review starts at the top; the same one keeps its place as it refreshes
  if self.scrolledFor ~= self.current then
    self.scrolledFor = self.current
    self.Scroll:SetVerticalScroll(0)
  else
    local most = math.max(0, count * CARD_H - self.Scroll:GetHeight())
    self.Scroll:SetVerticalScroll(math.min(most, self.Scroll:GetVerticalScroll()))
  end
  local more = count > visible
  self.More:SetShown(more)
  if more then self.More:SetText(string.format("Scroll for steps %d to %d", visible + 1, count)) end
  self.Rows:ClearAllPoints()
  if more then
    self.Rows:SetPoint("TOPLEFT", self.More, "BOTTOMLEFT", 0, -6)
  else
    self.Rows:SetPoint("TOPLEFT", self.Scroll, "BOTTOMLEFT", 4, -6)
  end
  self.Rows:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
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
