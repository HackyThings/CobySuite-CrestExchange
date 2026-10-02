-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Amount: resuming a stopped exchange
--
-- Reached only from Review remaining on a paused order: "Receive [ 20 ]
-- more Champion crests", filled in with what is left and capped by it.
-- Minus and plus step by one pack; Max fills in everything allowed right
-- now, and its tooltip names what limits it. An amount that isn't a whole
-- number of packs offers the two pack amounts around it as buttons (never
-- rounded silently). The ladder previews the single trade: both balances
-- before and after all packs open, and the room left; the reserve sits under
-- it. Enter only commits the number; Review exchange opens the Review page,
-- where buying is confirmed.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = Views.Window
local T = Views.Text
local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local Seasons = CobysCrestExchange.Seasons
local Store = CobysCrestExchange.Store
local E = CobysCrestExchange.Events

local function Bus() return CobysCrestExchange.EventBus end

local function CurrentSelection()
  return CobysCrestExchange.Quote.Controller.selection or {}
end

local function Select(crests)
  local sel = CurrentSelection()
  Bus():Fire(E.SelectionChanged, { tier = sel.tier, productKey = sel.productKey, crests = crests,
    capPacks = sel.capPacks, resume = sel.resume })
end

local function Step(page, packs)
  local q = page.q
  if not q or not q.yield then return end
  local current = CurrentSelection().crests or 0
  local nextValue = math.max(q.yield, math.floor(current / q.yield) * q.yield + packs * q.yield)
  Select(math.min(nextValue, math.max(q.yield, q.maxCrests)))
end

local function BuildStepper(host, page)
  page.Minus = UI.CreateButton(host, { text = "-", size = { 24, 22 }, point = { "TOPLEFT", host, "TOPLEFT", 64, -34 },
    onClick = function() Step(page, -1) end })
  page.Input = UI.CreateNumberInput(host, { width = 70, maxLetters = 6,
    point = { "LEFT", page.Minus, "RIGHT", 8, 0 },
    parse = function(text) local n = tonumber(text); return n and n == math.floor(n) and n or nil end,
    validate = function(n) return n >= 1 and n <= 100000 end,
    onCommit = function(n) Select(n) end })
  page.Input:SetNumeric(true)   -- digits only
  page.Plus = UI.CreateButton(host, { text = "+", size = { 24, 22 }, point = { "LEFT", page.Input, "RIGHT", 4, 0 },
    onClick = function() Step(page, 1) end })
  page.Max = UI.CreateButton(host, { text = "Max", size = { 50, 22 }, point = { "LEFT", page.Plus, "RIGHT", 6, 0 },
    onClick = function() if page.q and page.q.maxCrests and page.q.maxCrests > 0 then Select(page.q.maxCrests) end end })
  UI.AddDynamicTooltip(page.Max, function(tip)
    local q = page.q
    tip:AddLine("Max: " .. (q and T.Count(q.maxCrests) or "?"))
    if q and q.limiter then tip:AddLine("Limited by: " .. T.Limiter(q.limiter), 1, 1, 1, true) end
  end, { fillable = true })
  local label = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  label:SetPoint("RIGHT", page.Minus, "LEFT", -8, 0)
  label:SetText("Receive")
  page.Unit = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Unit:SetPoint("TOPLEFT", page.Minus, "BOTTOMLEFT", 0, -6)
  page.Unit:SetJustifyH("LEFT")
  page.Possible = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.Possible:SetPoint("TOPLEFT", page.Unit, "BOTTOMLEFT", 0, -4)
end

local function BuildRounding(host, page)
  local r = CreateFrame("Frame", nil, host)
  r:SetPoint("TOPLEFT", 0, -86)
  r:SetPoint("TOPRIGHT", 0, -86)
  r:SetHeight(26)
  r.Text = r:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  r.Text:SetPoint("LEFT", 6, 0)
  r.Down = UI.CreateButton(r, { text = "", size = { 90, 22 }, point = { "LEFT", r.Text, "RIGHT", 8, 0 },
    onClick = function() if r.down then Select(r.down) end end })
  r.Up = UI.CreateButton(r, { text = "", size = { 90, 22 }, point = { "LEFT", r.Down, "RIGHT", 6, 0 },
    onClick = function() if r.up then Select(r.up) end end })
  page.Rounding = r
end

-- The whole ladder as the preview: both tiers' before and after, the
-- destination glowing, and the trade flowing while the amount is good
local function BuildPreview(host, page)
  page.ladder = Views.Ladder.Create(host, { top = -106, nodeH = 26, gap = 12 })
  page.Summary = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Summary:SetPoint("TOPLEFT", page.ladder.frame, "BOTTOMLEFT", 2, -6)
  page.Summary:SetPoint("TOPRIGHT", page.ladder.frame, "BOTTOMRIGHT", -2, -6)
  page.Summary:SetJustifyH("LEFT")
end

local function PreviewModel(page, ctx, q)
  local season = page.season
  local model = { season = season, nodes = {}, links = {} }
  local ok = q.status == "ok"
  for _, tier in ipairs(season.tiers) do
    local t = ctx.obs.tiers[tier.key]
    local node = { icon = t and t.currency.icon, value = T.Count(t and t.currency.ok and t.currency.quantity or nil),
      dim = tier.key ~= q.sourceTier and tier.key ~= q.destTier }
    if ok and tier.key == q.sourceTier and q.sourceBefore then
      node.value, node.valueColor = T.Count(q.sourceBefore) .. " > " .. T.Count(q.sourceAfter), { 1, 0.55, 0.3 }
      node.sub = "You spend " .. T.Count(q.spend)
    elseif ok and tier.key == q.destTier and q.destBefore then
      node.value, node.valueColor = T.Count(q.destBefore) .. " > " .. T.Count(q.destAfterOpen), { 0.3, 1, 0.3 }
      node.sub = q.roomKind == "none" and "No cap" or ("Room after: " .. T.Count(q.roomAfter))
    end
    node.glow = tier.key == q.destTier
    model.nodes[tier.key] = node
  end
  local label = ok and string.format("%s: %s to %s", T.Packs(q.packs), T.Crests(season, q.sourceTier, q.spend),
    T.Crests(season, q.destTier, q.crests)) or string.format("%s for %s", T.Count(q.cost), T.Count(q.yield))
  -- A trade down runs the other way on the ladder: its link sits above the destination
  local linkKey = q.direction == "down" and q.sourceTier or q.destTier
  model.links[linkKey] = { state = ok and "current" or "idle", label = label, down = q.direction == "down" }
  return model
end

local function BuildOptions(host, page)
  page.ReserveLabel = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.ReserveLabel:SetPoint("TOPLEFT", page.Summary, "BOTTOMLEFT", 4, -8)
  page.ReserveLabel:SetText("Keep at least")
  page.Reserve = UI.CreateNumberInput(host, { width = 60, maxLetters = 6,
    point = { "LEFT", page.ReserveLabel, "RIGHT", 8, 0 },
    parse = function(text) if text == "" then return 0 end local n = tonumber(text); return n and n == math.floor(n) and n or nil end,
    validate = function(n) return n >= 0 and n <= 100000 end,
    onCommit = function(n)
      local src = page.season and page.q and Seasons.Tier(page.season, page.q.sourceTier)
      if src then
        Store.SetReserve(src.currencyID, n)
        Bus():Fire(E.PreferenceChanged, "reserve", src.currencyID, n)
      end
    end })
  page.Reserve:SetNumeric(true)
  page.ReserveUnit = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.ReserveUnit:SetPoint("LEFT", page.Reserve, "RIGHT", 8, 0)
  page.AutoOpen = UI.CreateCheckbox(host, { label = "Open packs automatically after you close Vaskarn",
    point = { "TOPLEFT", page.ReserveLabel, "BOTTOMLEFT", -6, -4 },
    onChange = function(checked)
      Store.SetAutoOpen(checked)
      Bus():Fire(E.PreferenceChanged, "autoOpen", nil, checked)
    end })
  page.Problems = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Problems:SetPoint("TOPLEFT", page.ReserveLabel, "BOTTOMLEFT", 0, -8)
  page.Problems:SetPoint("RIGHT", host, "RIGHT", -6, 0)
  page.Problems:SetJustifyH("LEFT")
end

local function Build(host)
  local page = {}
  page.Title = host:CreateFontString(nil, "OVERLAY", U.Fonts.HEADING)
  page.Title:SetPoint("TOPLEFT", 4, -4)
  page.Direction = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.Direction:SetPoint("TOPRIGHT", -4, -8)
  BuildStepper(host, page)
  BuildRounding(host, page)
  BuildPreview(host, page)
  BuildOptions(host, page)
  page.Back = UI.CreateButton(host, { text = "Back", size = { 90, 22 }, point = { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 },
    onClick = function()
      local view = CobysCrestExchange.Session.View()
      if view.order then
        Bus():Fire(E.SessionCommand, "back")
      else
        Window.Go("source")
      end
    end })
  page.Review = UI.CreateButton(host, { text = "Review exchange", size = { 150, 24 },
    point = { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 4 },
    onClick = function() if page.q and page.q.status == "ok" then Bus():Fire(E.ReviewRequested, page.q) end end })
  page.Planning = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.Planning:SetPoint("BOTTOMRIGHT", -4, 10)
  page.Planning:SetText("Visit Vaskarn to exchange.")
  return page
end

local function ProblemLines(page, q, ctx)
  local lines = {}
  local direction = T.Direction(q, page.season)
  if direction then lines[#lines + 1] = U.WrapColor(U.Colors.CAUTION_ORANGE, direction) end
  for _, p in ipairs(q.problems or {}) do
    if p.kind == "capped" then lines[#lines + 1] = T.CappedLine(page.season, q.destTier, q.yield, p.room)
    elseif p.kind == "unknown_room" then lines[#lines + 1] = T.Limiter("unknown_room")
    elseif p.kind == "balance" then lines[#lines + 1] = string.format("Not enough %s: one pack costs %s.",
      T.Tier(page.season, q.sourceTier), T.Count(p.need))
    elseif p.kind == "existing_packs" then lines[#lines + 1] = string.format("You already have %s of these crests unopened; they are counted in the room.",
      T.Packs(p.packs))
    elseif p.kind == "combat" then lines[#lines + 1] = T.Pause("combat") end
  end
  if q.status == "too_many" then lines[#lines + 1] = "That's more than you can receive right now." end
  if q.status == "invalid" then lines[#lines + 1] = "Enter a whole number of crests." end
  if ctx.view.advisorOnly then
    lines[#lines + 1] = "Buying from this window was refused by the game. Buy from Vaskarn's own list; this window keeps counting."
  end
  local notice = T.Notice(ctx.view.notice)
  if notice and ctx.view.state == "SELECTING" then lines[#lines + 1] = notice end
  return table.concat(lines, "\n")
end

local function RefreshControls(page, q, ctx)
  page.Title:SetText(string.format("%s to %s", T.Tier(page.season, q.sourceTier), T.Tier(page.season, q.destTier)))
  page.Direction:SetText(q.direction == "down" and "Trade down" or "Trade up")
  local sel = CurrentSelection()
  if not page.Input:HasFocus() then page.Input:SetCommittedValue(sel.crests) end
  page.Unit:SetText(string.format("more %s crests%s", T.Tier(page.season, q.destTier),
    q.status == "ok" and (" (" .. T.Packs(q.packs) .. ")") or ""))
  page.Possible:SetText(string.format("You could receive up to %s.%s", T.Count(q.maxCrests),
    q.status == "ok" and (" Selected: " .. T.Count(q.crests) .. ".") or ""))
  local r = page.Rounding
  r:SetShown(q.status == "rounding")
  if q.status == "rounding" then
    r.down, r.up = q.rounding.down, q.rounding.up
    r.Text:SetText(string.format("Packs hold %s crests. Choose", T.Count(q.yield)))
    r.Down:SetShown(r.down ~= nil); r.Down:SetText(r.down and T.Count(r.down) or "")
    r.Up:SetShown(r.up ~= nil); r.Up:SetText(r.up and T.Count(r.up) or "")
  end
  local src = Seasons.Tier(page.season, q.sourceTier)
  if not page.Reserve:HasFocus() then page.Reserve:SetCommittedValue(src and Store.GetReserve(src.currencyID) or 0) end
  page.ReserveUnit:SetText(T.Tier(page.season, q.sourceTier))
  page.AutoOpen:SetShown(Seasons.CAPABILITIES.autoOpenAfterClose == true and not q.planning)
  page.AutoOpen:SetChecked(Store.GetAutoOpen())
  local ok = q.status == "ok" and not q.planning and not ctx.obs.inCombat and not ctx.view.advisorOnly
    and Seasons.CAPABILITIES.buyFromAddon == true and ctx.obs.merchant.isExchange == true
  page.Review:SetShown(not q.planning)
  page.Review:SetEnabled(ok == true and ctx.view.state == "SELECTING")
  page.Planning:SetShown(q.planning == true)
end

local page = Window.AddPage("amount", Build)
function page:Refresh(ctx)
  self.season = ctx.season
  local q = ctx.quote
  if not q or not q.key then
    if not ctx.nav.productKey then return Window.Go("source") end
    self.q = nil
    return
  end
  self.q = q
  if q.status == "unavailable" then
    self.Review:Hide()
    self.Rounding:Hide()
    self.Planning:Show()
    self.Problems:SetText("This trade hasn't been seen at Vaskarn yet, so there's no rate to show.")
    return
  end
  RefreshControls(self, q, ctx)
  self.ladder:Render(PreviewModel(self, ctx, q))
  self.Summary:SetText(q.status == "ok" and string.format("You spend %s and receive %s after opening %s.",
    T.Crests(self.season, q.sourceTier, q.spend), T.Crests(self.season, q.destTier, q.crests), T.Packs(q.packs)) or "")
  self.Problems:SetText(ProblemLines(self, q, ctx))
end
