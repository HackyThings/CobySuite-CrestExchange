-------------------------------------------------------------------------------
-- CobysCrestExchange Views.SourcePicker: "Get <tier> crests", amount first
--
-- The player says how many they want ("I want [20] more Myth": minus and plus
-- step by a pack, Max fills in the most any route allows, and an amount
-- between packs offers the two pack amounts around it). Every way of getting
-- that tier is then priced for exactly that amount (until an amount is
-- typed the routes show greyed and can't be chosen; a locked one still opens
-- its requirements):
--   * trade up from the tier below      "Spend 60 Hero (2 packs)"
--   * trade down from the tier above
--   * a plan using every lower tier     "Spend 30 Hero, 90 Champion in 2 steps"
-- A route that can't reach the amount says why, and a locked trade opens its
-- requirements when clicked. A route that works is chosen for you (the plan
-- first, then a trade up) and highlighted; clicking another chooses it. Under the routes, a small path
-- shows the chosen one tier by tier. Review goes to the review page; Adjust
-- on the plan opens the full ladder with its Spend boxes. Unopened packs of
-- this tier are offered first.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = Views.Window
local T = Views.Text
local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local GOLD = U.Colors.STATUS_GOLD
local Seasons = CobysCrestExchange.Seasons
local Seams = CobysCrestExchange.Seams
local Eligibility = CobysCrestExchange.Eligibility
local Quote = CobysCrestExchange.Quote
local Plan = CobysCrestExchange.Plan
local Store = CobysCrestExchange.Store
local E = CobysCrestExchange.Events

local TILE_H = 56   -- a title and a reason that wraps to two lines
local TILES = 3
local SPENT, GAINED = { 1, 0.55, 0.3 }, { 0.3, 1, 0.3 }

-- The amount and the chosen route, kept while the tier stays the same
local S = { tier = nil, crests = nil, route = nil }
local Get = { state = S }
Views.Get = Get

local function Bus() return CobysCrestExchange.EventBus end

-------------------------------------------------------------------------------
-- Pricing every route for the amount
-------------------------------------------------------------------------------
local function Reason(result)
  local reason = result.reasons and result.reasons[1]
  if result.state == "locked" and reason then
    if reason.kind == "achievement" then return "Needs " .. tostring(reason.name) .. " on this character" end
    if reason.kind == "practicum" then return "Needs Vaskarn's quest Upgrade Practicum" end
  end
  if result.state == "not_offered" then return "Vaskarn isn't offering this right now" end
  if result.state == "unsupported" then return "Vaskarn sells it, but this version can't buy it yet" end
  return "Seen only at Vaskarn"
end

local function TradeRoute(ctx, product)
  local season = ctx.season
  local result = Eligibility.ForTrade(season, product, ctx.obs)
  local route = { key = product.key, kind = "trade", product = product,
    icon = product.itemID and Seams.Call("ItemIcon", product.itemID) or 134400,
    title = (product.kind == "up" and "Trade up from " or "Trade down from ") .. T.Tier(season, product.from) }
  local q = Quote.Build(ctx.obs, { productKey = product.key, crests = S.crests }, Quote.Controller.Options(ctx.obs, product))
  route.open = result.state == "available" or (result.state == "away" and q.offer ~= nil)
  if not route.open then
    route.line, route.locked, route.state = Reason(result), result.state == "locked", result.state
    return route
  end
  route.quote, route.max, route.yield = q, q.maxCrests or 0, q.yield
  if q.status == "ok" then
    route.ok = true
    route.line = product.kind == "down"
      and string.format("Gives up %s, one for one  (%s)", T.Crests(season, product.from, q.spend), T.Packs(q.packs))
      or string.format("Spend %s  (%s)", T.Crests(season, product.from, q.spend), T.Packs(q.packs))
  elseif q.status == "unavailable" then
    route.line = "Rate not seen yet: visit Vaskarn"
  elseif route.max == 0 then
    route.line, route.blocked = T.WhyNone(season, q, ctx.obs), true
  else
    route.line = string.format("Up to %s now", T.Crests(season, product.to, route.max))
  end
  route.down = product.kind == "down"
  return route
end

-- A plan's Spend choices live on the plan page; a new target starts with all on
local function PlanOptions(ctx, tierKey)
  local ps = Views.Plan.state
  if ps.target ~= tierKey then
    ps.target, ps.crests, ps.spend = tierKey, nil, {}
    for _, tier in ipairs(Plan.SourceTiers(ctx.season, tierKey)) do ps.spend[tier.key] = true end
  end
  local reserves = {}
  for _, tier in ipairs(ctx.season.tiers) do reserves[tier.currencyID] = Store.GetReserve(tier.currencyID) end
  return { spend = ps.spend, reserves = reserves, unsettled = CobysCrestExchange.Session.Unsettled(ctx.obs) }
end

local function Away(ctx) return not (ctx.obs.merchant and ctx.obs.merchant.isExchange) end

-- A plan's trades end with the trade up into the target, so the plan route
-- inherits that trade's locked, not_offered or unsupported result (only a
-- locked one shows a lock and opens the requirements)
local function PlanGate(ctx, tierKey)
  for _, product in ipairs(Seasons.TradesInto(ctx.season, tierKey)) do
    if product.kind == "up" then
      local result = Eligibility.ForTrade(ctx.season, product, ctx.obs)
      local s = result.state
      if s == "locked" or s == "not_offered" or s == "unsupported" then return product, result end
      return nil
    end
  end
end

local function PlanRoute(ctx, tierKey)
  local season = ctx.season
  local t = ctx.obs.tiers[tierKey]
  local route = { key = "plan", kind = "plan", open = true, icon = t and t.currency.icon or 134400,
    title = "Plan from lower tiers" }
  local top, gate = PlanGate(ctx, tierKey)
  local plan = Plan.Build(ctx.obs, tierKey, S.crests, PlanOptions(ctx, tierKey))
  if top and (plan.maxCrests or 0) == 0 then
    -- The trade up is out and none of this tier's own packs are there to open
    route.open, route.locked, route.reqKey, route.max, route.state = false, gate.state == "locked", top.key, 0, gate.state
    route.line = Reason(gate)
    return route
  end
  if Away(ctx) and (plan.maxCrests or 0) == 0 and plan.limiter == "unavailable" then
    -- Never seen at Vaskarn, and no packs of its own to open: closed until a visit
    route.open, route.max, route.state = false, 0, "away"
    route.line = "None yet: " .. T.PlanLimiter(plan, season, true, ctx.obs)
    return route
  end
  local said = string.format("Plan into %s: max %s, stopped by %s in %s", tierKey, tostring(plan.maxCrests),
    tostring(plan.limiter), tostring(plan.limitTier))
  if said ~= S.lastPlanLog then
    S.lastPlanLog = said
    CobysCrestExchange.Debug.Log("UI", "%s", said)
  end
  route.plan, route.max, route.yield = plan, plan.maxCrests or 0, plan.yield
  if plan.status == "ok" then
    route.ok = true
    local parts = {}
    for _, tier in ipairs(season.tiers) do
      local n = plan.spendBy and plan.spendBy[tier.key]
      if n and n > 0 and tier.key ~= tierKey then parts[#parts + 1] = T.Crests(season, tier.key, n) end
    end
    if Plan.OpenOnly(plan) then
      route.line = string.format("Opens the packs you have (%s)", T.Crests(season, tierKey, plan.crests))
    elseif #parts == 0 then
      -- Trades paid for by packs you open on the way: no balance goes down
      route.line = string.format("Opens your packs and trades in %d %s, no balance goes down", #plan.steps, T.Plural(#plan.steps, "step", "steps"))
    else
      route.line = string.format("Spend %s in %d %s", table.concat(parts, ", "), #plan.steps, T.Plural(#plan.steps, "step", "steps"))
    end
  elseif top then
    -- Only this tier's own packs can be opened: the trade up is out
    route.line = string.format("Up to %s from your packs: the trade up is %s", T.Crests(season, tierKey, route.max),
      gate.state == "locked" and "locked" or "not available")
  elseif plan.status == "too_many" and route.max > 0 then
    route.line = "Can't reach that: " .. T.PlanLimiter(plan, season, Away(ctx), ctx.obs)
  elseif route.max == 0 then
    route.line, route.blocked = "None right now: " .. T.PlanLimiter(plan, season, Away(ctx), ctx.obs), true
  else
    route.line = string.format("Up to %s now, step by step", T.Crests(season, tierKey, route.max))
  end
  return route
end

-- What limits a route, in a few words
local function RouteWhy(r, page)
  if r.kind == "plan" then return r.plan and T.PlanLimiter(r.plan, page.season, page.away, page.obs) end
  if r.quote then
    if (r.max or 0) == 0 then return T.WhyNone(page.season, r.quote, page.obs) end
    return T.Limiter(r.quote.limiter or "")
  end
  return r.line
end

-- Listed trades up first, then the plan (also trading up), and a trade down
-- last, since a trade down gives up a higher tier; the plan is chosen first
-- when it works (Choose)
local function Routes(ctx, tierKey)
  local list, downs = {}, {}
  for _, product in ipairs(Seasons.TradesInto(ctx.season, tierKey)) do
    if product.kind == "down" then downs[#downs + 1] = product else list[#list + 1] = TradeRoute(ctx, product) end
  end
  if (Seasons.TierIndex(ctx.season, tierKey) or 0) >= 3 then
    local plan = PlanRoute(ctx, tierKey)
    -- A plan that is just the trade up says so, so two tiles don't seem to differ
    local step = plan.ok and #plan.plan.steps == 1 and plan.plan.steps[1]
    for _, r in ipairs(list) do
      if step and step.kind ~= "open" and r.ok and r.product.from == step.from and r.quote.packs == step.packs then
        plan.line = string.format("Spend %s. Same as the trade up.", T.Crests(ctx.season, step.from, r.quote.spend))
      end
    end
    list[#list + 1] = plan
  end
  for _, product in ipairs(downs) do
    if #list < TILES then list[#list + 1] = TradeRoute(ctx, product) end
  end
  return list
end

-- The chosen route (Plan.ChooseRoute): the player's while it works, else the
-- plan, else a trade up, else the open route that gives the most; never a trade down
local function Choose(routes)
  return Plan.ChooseRoute(routes, S.route, S.crests ~= nil)
end

-- What can still be done when a tier is at MAX or has no room for a pack
local function StillWorks(page, ctx, tierKey)
  local out, season = {}, ctx.season
  local t = ctx.obs.tiers[tierKey]
  if not T.Capped(t, page.yield) then return out end
  if t and (t.packs or 0) > 0 then
    local packs = string.format("%s unopened %s %s", T.Count(t.packs), T.Tier(season, tierKey), T.Plural(t.packs, "pack", "packs"))
    local fit = T.Openable(t, page.yield)
    if fit >= t.packs then
      out[#out + 1] = string.format("Your %s can still open: use the Open packs banner above.", packs)
    elseif fit > 0 then
      out[#out + 1] = string.format("%s of your %s can open now (use the Open packs banner above); the rest wait until %s.",
        T.Count(fit), packs, T.WaitFor(t))
    else
      out[#out + 1] = string.format("Your %s wait in your bags until %s.", packs, T.WaitFor(t))
    end
  end
  -- Trading this tier up still works only if that trade really can run now
  local index = Seasons.TierIndex(season, tierKey)
  local up = index and season.tiers[index + 1]
  if up then
    for _, product in ipairs(Seasons.TradesInto(season, up.key)) do
      if product.kind == "up" then
        local q = Quote.MaxFor(ctx.obs, product.key, Quote.Controller.Options(ctx.obs, product))
        if Eligibility.ForTrade(season, product, ctx.obs).state == "available" and (q.maxCrests or 0) > 0 then
          out[#out + 1] = string.format("What still works: trading your %s up into %s, up to %s now (Get %s on the first page).",
            T.Tier(season, tierKey), T.Tier(season, up.key), T.Crests(season, up.key, q.maxCrests), T.TierLabel(season, up.key))
        end
      end
    end
  end
  return out
end

-------------------------------------------------------------------------------
-- The path picture for the chosen route, in the order the crests flow
-------------------------------------------------------------------------------
local function PathStops(ctx, route, tierKey)
  if not route or (not route.ok and (route.max or 0) == 0) then return nil end
  local stops = {}
  local function Stop(key, text, color)
    local t = ctx.obs.tiers[key]
    stops[#stops + 1] = { tierKey = key, icon = t and t.currency.icon, text = text, color = color }
  end
  if route.kind == "trade" then
    local q = route.quote
    Stop(route.product.from, route.ok and ("-" .. T.Count(q.spend)) or "", SPENT)
    Stop(route.product.to, route.ok and ("+" .. T.Count(q.crests)) or "", GAINED)
    return stops
  end
  local plan = route.plan
  if not route.ok then
    -- The chosen plan can't give this amount exactly: every tier it may spend, up to the target
    local spend, started = Views.Plan.state.spend or {}, false
    for _, tier in ipairs(Plan.SourceTiers(ctx.season, tierKey)) do
      started = started or spend[tier.key] == true
      if started then Stop(tier.key, "") end
    end
    Stop(tierKey, "")
    return stops
  end
  local function Middle(key)
    local n = plan.spendBy[key]
    if n and n > 0 then return Stop(key, "-" .. T.Count(n), SPENT) end
    Stop(key, "passes")
  end
  -- The trades only: packs you have open into a tier already on the path
  local trades = {}
  for _, step in ipairs(plan.steps) do if step.kind ~= "open" then trades[#trades + 1] = step end end
  if #trades == 0 then
    Stop(tierKey, "+" .. T.Count(plan.crests), GAINED)
    return stops
  end
  for i, step in ipairs(trades) do
    if i == 1 then Middle(step.from) end
    if step.to == tierKey then Stop(step.to, "+" .. T.Count(plan.crests), GAINED) else Middle(step.to) end
  end
  return stops
end

-------------------------------------------------------------------------------
-- Building the page
-------------------------------------------------------------------------------
local function SetCrests(n)
  S.crests = n
  Window.RefreshNow()
end

local function Step(page, packs)
  local yield = page.yield or 10
  local current = S.crests or 0
  SetCrests(math.max(yield, math.floor(current / yield) * yield + packs * yield))
end

local function BuildAmount(host, page)
  local want = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  want:SetPoint("TOPLEFT", 6, -46)
  want:SetText("I want")
  page.Input = UI.CreateNumberInput(host, { width = 56, maxLetters = 6, point = { "LEFT", want, "RIGHT", 8, 0 },
    parse = function(text) local n = tonumber(text); return n and n == math.floor(n) and n or nil end,
    validate = function(n) return n >= 1 and n <= 100000 end,
    onCommit = function(n) SetCrests(n) end })
  page.Input:SetNumeric(true)   -- digits only: no letters, signs or decimal points
  page.Unit = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Unit:SetPoint("LEFT", page.Input, "RIGHT", 8, 0)
  page.Max = UI.CreateButton(host, { text = "Max", size = { 46, 22 }, point = { "TOPRIGHT", host, "TOPRIGHT", -2, -42 },
    onClick = function() if (page.best or 0) > 0 then SetCrests(page.best) end end })
  page.Max:SetMotionScriptsWhileDisabled(true)
  UI.AddDynamicTooltip(page.Max, function(tip)
    tip:AddLine("Max: " .. T.Count(page.best or 0))
    if page.downRoute and (page.best or 0) == 0 then
      tip:AddLine("A trade down counts only once you choose it: type an amount, then click it.", 1, 1, 1, true)
    end
    local r = page.bestRoute
    if r then
      local why = RouteWhy(r, page)
      if why and why ~= "" then tip:AddLine("Limited by: " .. why, 1, 1, 1, true) end
      return
    end
    -- Every way gives nothing: each one's reason
    for _, route in ipairs(page.routes or {}) do
      tip:AddLine(route.title .. ": " .. (route.open and (RouteWhy(route, page) or "") or (route.line or "")), 1, 0.6, 0.3, true)
    end
  end, { fillable = true })
  page.Plus = UI.CreateButton(host, { text = "+", size = { 24, 22 }, point = { "RIGHT", page.Max, "LEFT", -6, 0 },
    onClick = function() Step(page, 1) end })
  page.Minus = UI.CreateButton(host, { text = "-", size = { 24, 22 }, point = { "RIGHT", page.Plus, "LEFT", -2, 0 },
    onClick = function() Step(page, -1) end })
  local r = CreateFrame("Frame", nil, host)
  r:SetPoint("TOPLEFT", 6, -70)
  r:SetSize(340, 20)
  r.Text = r:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  r.Text:SetPoint("LEFT")
  r.Down = UI.CreateButton(r, { text = "", size = { 56, 20 }, point = { "LEFT", r.Text, "RIGHT", 6, 0 },
    onClick = function() if r.down then SetCrests(r.down) end end })
  r.Up = UI.CreateButton(r, { text = "", size = { 56, 20 }, point = { "LEFT", r.Down, "RIGHT", 4, 0 },
    onClick = function() if r.up then SetCrests(r.up) end end })
  page.Round = r
end

local function OnTileClick(tile)
  local route = tile.route
  if not route then return end
  if not route.open then
    if route.locked then Window.Go("requirements", { reqKey = route.reqKey or route.key, from = "source" }) end
    return
  end
  S.route = route.key
  Window.RefreshNow()
end

local function BuildTile(host)
  local tile = CreateFrame("Button", nil, host, "BackdropTemplate")
  tile:SetHeight(TILE_H - 4)
  tile:SetBackdrop(U.Backdrops.CONTENT)
  tile:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
  tile.Glow = tile:CreateTexture(nil, "BACKGROUND", nil, 1)
  tile.Glow:SetPoint("TOPLEFT", 3, -3)
  tile.Glow:SetPoint("BOTTOMRIGHT", -3, 3)
  tile.Glow:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.10)
  tile.Icon = tile:CreateTexture(nil, "ARTWORK")
  tile.Icon:SetSize(30, 30)
  tile.Icon:SetPoint("LEFT", 8, 0)
  tile.Title = tile:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  tile.Title:SetPoint("TOPLEFT", tile, "TOPLEFT", 46, -6)
  tile.Line = tile:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  tile.Line:SetPoint("TOPLEFT", tile.Title, "BOTTOMLEFT", 0, -2)
  tile.Line:SetPoint("RIGHT", -30, 0)
  tile.Line:SetJustifyH("LEFT")
  tile.Line:SetJustifyV("TOP")
  tile.Line:SetWordWrap(true)
  tile.Line:SetMaxLines(2)
  tile.Badge = tile:CreateTexture(nil, "OVERLAY")
  tile.Badge:SetSize(18, 18)
  tile.Badge:SetPoint("RIGHT", -8, 0)
  tile.Adjust = UI.CreateButton(tile, { text = "Adjust", size = { 58, 18 }, point = { "TOPRIGHT", tile, "TOPRIGHT", -30, -4 },
    onClick = function()
      Views.Plan.state.crests = S.crests
      Window.Go("plan", { tier = S.tier })
    end })
  UI.AddDynamicTooltip(tile.Adjust, function(tip)
    tip:AddLine("Adjust the plan")
    tip:AddLine("Choose which tiers it may spend, with every step shown on the ladder.", 1, 1, 1, true)
  end, { fillable = true })
  UI.AddHoverHighlight(tile)
  tile:HookScript("OnEnter", function(self)
    if not self.Line:IsTruncated() then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.Title:GetText() or "")
    GameTooltip:AddLine(self.Line:GetText() or "", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  tile:HookScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
  tile:SetScript("OnClick", OnTileClick)
  return tile
end

local function BuildExisting(host, page)
  local existing = CreateFrame("Frame", nil, host, "BackdropTemplate")
  existing:SetBackdrop(U.Backdrops.CONTENT)
  existing:SetBackdropColor(0.15, 0.12, 0.02, 0.9)
  existing:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
  existing:SetHeight(28)
  -- Two lines at most beside the button (large counts wrap)
  existing.Text = existing:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  existing.Text:SetPoint("TOPLEFT", 8, -2)
  existing.Text:SetPoint("BOTTOMRIGHT", -104, 2)
  existing.Text:SetJustifyH("LEFT")
  existing.Text:SetJustifyV("MIDDLE")
  existing.Text:SetMaxLines(2)
  existing.Button = UI.CreateButton(existing, { text = "Open packs", size = { 94, 20 },
    point = { "RIGHT", existing, "RIGHT", -4, 0 },
    onClick = function()
      if existing.productKey then Bus():Fire(E.SessionCommand, "open_existing", existing.productKey) end
    end })
  page.Existing = existing
end

local function Build(host)
  local page = { tiles = {} }
  page.Icon = host:CreateTexture(nil, "ARTWORK")
  page.Icon:SetSize(30, 30)
  page.Icon:SetPoint("TOPLEFT", 4, -2)
  page.Title = host:CreateFontString(nil, "OVERLAY", U.Fonts.HEADING)
  page.Title:SetPoint("TOPLEFT", page.Icon, "TOPRIGHT", 8, 0)
  page.Sub = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.Sub:SetPoint("BOTTOMLEFT", page.Icon, "BOTTOMRIGHT", 8, 0)
  BuildAmount(host, page)
  BuildExisting(host, page)
  for i = 1, TILES do page.tiles[i] = BuildTile(host) end
  page.path = Views.Path.Create(host, { height = 58 })
  page.Summary = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.Summary:SetJustifyV("TOP")
  page.SummaryHover = CreateFrame("Frame", nil, host)
  page.SummaryHover:SetAllPoints(page.Summary)
  page.SummaryHover:EnableMouse(false)
  UI.AddDynamicTooltip(page.SummaryHover, function(tip) tip:AddLine(page.Summary:GetText() or "", 1, 1, 1, true) end, { fillable = true })
  page.Summary:SetJustifyH("LEFT")
  page.Summary:SetSpacing(2)
  page.Back = UI.CreateButton(host, { text = "Back", size = { 90, 22 }, point = { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 },
    onClick = function()
      Window.Go("overview")
      Bus():Fire(E.SessionCommand, "back")
      Bus():Fire(E.SelectionChanged, nil)
    end })
  page.Review = UI.CreateButton(host, { text = "Review", size = { 150, 24 }, point = { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 4 },
    onClick = function() Get.Review(page) end })
  return page
end

-------------------------------------------------------------------------------
-- Refreshing
-------------------------------------------------------------------------------
-- waiting: no amount typed yet, so an open route is greyed and can't be
-- chosen (a locked one still opens its requirements)
local function FillTile(tile, route, chosen, waiting)
  tile.route = route
  tile.Icon:SetTexture(route.icon)
  tile.Title:SetText(route.title)
  local line = route.line or ""
  if route.open and not route.ok and (S.crests or route.blocked) then line = T.Tint(U.Colors.CAUTION_ORANGE, line) end
  if not route.open or waiting then line = T.Tint(U.Colors.LABEL_GRAY, line) end
  tile.Line:SetText(line)
  local selected = chosen == route
  -- Lit only when it can give the amount: a fallback pick that gives nothing
  -- (it names the limit in Max's tooltip) isn't shown as the way (Task #236)
  local lit = selected and route.ok
  tile.Glow:SetShown(lit)
  tile.Adjust:SetShown(route.kind == "plan" and selected)
  if route.locked then
    tile.Badge:SetAtlas("AdventureMapIcon-Lock"); tile.Badge:Show()
  elseif selected and route.ok then
    tile.Badge:SetAtlas("checkmark-minimal"); tile.Badge:Show()
  else
    tile.Badge:Hide()
  end
  local inert = waiting and route.open
  tile:SetEnabled(not inert)
  tile:SetAlpha((route.open and not inert) and 1 or 0.55)
  tile.Icon:SetDesaturated(not route.open or inert)
  -- A trade down is marked in orange, chosen or not
  local orange = U.Colors.CAUTION_ORANGE
  if inert then
    tile:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.8)
  elseif route.down and route.open then
    tile:SetBackdropBorderColor(orange[1], orange[2], orange[3], selected and 1 or 0.7)
  elseif lit then
    tile:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
  else
    tile:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.8)
  end
end

-- The amount row; returns how far the rounding choice pushes the rest down
local function RefreshAmount(page, ctx, tierKey, routes, chosen)
  local best, bestRoute, yield = 0, nil, nil
  local downRoute
  for _, r in ipairs(routes) do
    -- A trade down counts toward Max only while it is the chosen route
    local counts = not r.down or r == chosen
    if r.open and counts and (r.max or 0) > best then best, bestRoute = r.max, r end
    if r.down and r.open and (r.max or 0) > 0 and r ~= chosen then downRoute = r end
    yield = yield or r.yield
  end
  page.best, page.bestRoute, page.yield, page.season, page.away = best, bestRoute, yield or 10, ctx.season, Away(ctx)
  page.Max:SetEnabled(best > 0)
  page.routes, page.obs, page.downRoute = routes, ctx.obs, downRoute
  if not page.Input:HasFocus() then page.Input:SetCommittedValue(S.crests) end
  page.Unit:SetText("more " .. T.Tier(ctx.season, tierKey))
  local r = page.Round
  local between = S.crests ~= nil and S.crests % page.yield ~= 0
  r:SetShown(between)
  if not between then return 0 end
  local down, up = math.floor(S.crests / page.yield) * page.yield, math.ceil(S.crests / page.yield) * page.yield
  r.down, r.up = down > 0 and down or nil, up
  r.Text:SetText(string.format("%s per pack. Choose:", T.Count(page.yield)))
  r.Down:SetShown(r.down ~= nil); r.Down:SetText(T.Count(down))
  r.Up:SetText(T.Count(up))
  return 22
end

local function RefreshExisting(page, ctx, tierKey, y)
  local existing = page.Existing
  existing.productKey = nil
  local t = ctx.obs.tiers[tierKey]
  if t and t.packs > 0 and not ctx.view.order then
    -- The button opens one kind of pack, so the line counts that kind only
    for _, product in ipairs(Seasons.TradesInto(ctx.season, tierKey)) do
      local n = ctx.obs.packs[product.key] or 0
      if n > 0 and not existing.productKey then
        existing.productKey = product.key
        existing.Text:SetText(string.format("%s ready to open: %s. Open them first.", T.Packs(n),
          T.Crests(ctx.season, tierKey, n * product.yield)))
      end
    end
  end
  existing:SetShown(existing.productKey ~= nil)
  if not existing:IsShown() then return y end
  existing:ClearAllPoints()
  existing:SetPoint("TOPLEFT", 0, y)
  existing:SetPoint("TOPRIGHT", 0, y)
  return y - 32
end

local LINE_H = 14        -- a small-font summary line with its spacing
local BUTTONS_TOP = -352 -- where Back and Review begin, from the page's top

local function Warn(text) return T.Tint(U.Colors.CAUTION_ORANGE, text) end

-- Nothing can be made by trading up: the cap if that is why (it stops every
-- route), else a pointer to the routes' own reasons; what still works; and
-- how to reach a trade down, which is never chosen for you
local function NoneLines(page, ctx, tierKey, lines)
  local t = ctx.obs.tiers[tierKey]
  if T.Capped(t, page.yield) then
    lines[#lines + 1] = Warn(T.CapSentence(ctx.season, tierKey, t, page.yield))
  else
    lines[#lines + 1] = Warn(page.downRoute and "Trading up can't give you any right now: each route says why."
      or "No exchange can give you more of this tier right now: each route says why.")
  end
  for _, line in ipairs(StillWorks(page, ctx, tierKey)) do lines[#lines + 1] = line end
  local d = page.downRoute
  if d then
    local from = T.Tier(ctx.season, d.product.from)
    if S.crests and d.max < S.crests then
      lines[#lines + 1] = string.format("Trade down from %s can give up to %s. Lower the amount to choose it.", from,
        T.Crests(ctx.season, tierKey, d.max))
      return
    end
    lines[#lines + 1] = S.crests
      and string.format("Trade down from %s could give up to %s. It spends a higher tier one for one, so choose it only if you mean to.",
        from, T.Crests(ctx.season, tierKey, d.max))
      or string.format("To trade down, type an amount, then choose Trade down from %s. It spends a higher tier one for one.", from)
  end
end

-- Every route closed: why, by what closed them
local function ClosedLine(routes)
  local locked, away, unsupported = false, false, false
  for _, r in ipairs(routes or {}) do
    if r.locked then locked = true
    elseif r.state == "away" then away = true
    elseif r.state == "unsupported" then unsupported = true end
  end
  if locked then return "No trade into this tier is open to you yet. Click a locked one to see what it needs." end
  if away and not unsupported then return "Visit Vaskarn in Silvermoon to see his trades and prices." end
  if unsupported and not away then return "This version can't buy these packs yet: use Vaskarn's own list." end
  return "No trade into this tier is open right now: each one says why."
end

-- What the presses after buying look like (shared with Review's wording):
-- packs you already have need no purchase; several purchases each need
-- Vaskarn's window again
local function FlowWords(buys, opens)
  local close = Seasons.CAPABILITIES.openAtVendor and "open each pack with one press"
    or "close Vaskarn's window and open each pack with one press"
  local own = opens > 0 and "Packs you already have need no purchase. " or ""
  if buys == 0 then return "Nothing is bought: one press opens each of your packs." end
  if buys > 1 then
    -- Kept short: Review adds the pack count to this line on a docked panel
    return own .. (Seasons.CAPABILITIES.openAtVendor
      and "For each purchase: buy, open the packs, then talk to Vaskarn again."
      or "For each purchase: buy, close Vaskarn's window, open the packs, then talk to him again.")
  end
  return own .. "After buying, " .. close .. "."
end
Get.FlowWords = FlowWords

local function PlanFlow(plan)
  local buys, opens = 0, 0
  for _, step in ipairs(plan.steps) do
    if step.kind == "open" then opens = opens + 1 else buys = buys + 1 end
  end
  return FlowWords(buys, opens)
end

-- The lines every summary ends with: where to go, and a refused buy
local function Finish(lines, ctx, chosen, skipVisit)
  local openOnly = chosen and chosen.ok and chosen.kind == "plan" and Plan.OpenOnly(chosen.plan)
  if not skipVisit and not openOnly and not (ctx.obs.merchant and ctx.obs.merchant.isExchange) then
    lines[#lines + 1] = "Visit Vaskarn to exchange."
  end
  if ctx.view.advisorOnly then lines[#lines + 1] = "Buying from this window was refused by the game." end
  return table.concat(lines, "\n")
end

local function SummaryText(page, ctx, tierKey, chosen, room)
  local lines = {}
  local anyOpen = false
  for _, r in ipairs(page.routes or {}) do if r.open then anyOpen = true end end
  if not anyOpen then
    lines[#lines + 1] = ClosedLine(page.routes)
    return Finish(lines, ctx, chosen, true)
  end
  if chosen and chosen.down then
    local q = chosen.quote
    lines[#lines + 1] = Warn(chosen.ok and T.DownWarning(ctx.season, chosen.product.from, chosen.product.to, q.spend, q.crests)
      or T.DownGeneric(ctx.season, chosen.product.from))
    return Finish(lines, ctx, chosen)
  end
  if (page.best or 0) == 0 then
    NoneLines(page, ctx, tierKey, lines)
    return Finish(lines, ctx, chosen)
  end
  if not S.crests then
    lines[#lines + 1] = string.format("Type how many you want, or press Max (up to %s now). The ways to get them light up once you do.",
      T.Crests(ctx.season, tierKey, page.best or 0))
  elseif not chosen then
    lines[#lines + 1] = "Only a trade down is open: click it if you want to give up a higher tier for this one."
  elseif chosen.ok and chosen.kind == "plan" then
    -- Every step spelled out, in the order the presses come, as far as the room allows
    local steps = chosen.plan.steps
    local fit = math.max(1, room - 1 - ((ctx.obs.merchant and ctx.obs.merchant.isExchange) and 0 or 1))
    for i, step in ipairs(steps) do
      if i == fit and #steps > fit then
        local left = #steps - i + 1
        lines[#lines + 1] = string.format("%s%d %s: Review plan lists them all.", i > 1 and "and " or "", left,
          i > 1 and T.Plural(left, "more step", "more steps") or "steps")
        break
      end
      lines[#lines + 1] = step.kind == "open" and string.format("Step %d: %s", i, T.StepWords(ctx.season, step))
        or string.format("Step %d: %s  (%s)", i, T.StepWords(ctx.season, step), T.Packs(step.packs))
    end
    if #lines < fit then lines[#lines + 1] = PlanFlow(chosen.plan) end
  elseif chosen.ok then
    lines[#lines + 1] = FlowWords(1, 0)
  end
  return Finish(lines, ctx, chosen)
end

-- The tier's cap in a few words, for the subtitle
local function CapWords(t)
  if not t or t.room.kind == "unknown" or t.room.raw == nil then return "Cap unknown." end
  if t.room.kind == "none" then return "No cap." end
  if t.room.raw <= 0 then return T.MaxBadge() .. "." end
  return string.format("Cap allows %s more.", T.Count(t.room.raw))
end

local function ReviewReady(ctx, chosen)
  if not (chosen and chosen.ok) then return false end
  -- A plan that only opens your own packs buys nothing: no vendor, no buying checks
  if chosen.kind == "plan" and Plan.OpenOnly(chosen.plan) then
    return not ctx.obs.inCombat and ctx.view.state == "SELECTING"
  end
  local planning = chosen.kind == "plan" and chosen.plan.planning or (chosen.kind == "trade" and chosen.quote.planning)
  return not planning and not ctx.obs.inCombat and not ctx.view.advisorOnly
    and Seasons.CAPABILITIES.buyFromAddon == true
    and ctx.obs.merchant.isExchange == true and ctx.view.state == "SELECTING"
end

local page = Window.AddPage("source", Build)
function page:Refresh(ctx)
  local tierKey = ctx.nav.tier
  if not ctx.season or not tierKey then return Window.Go("overview") end
  if S.tier ~= tierKey then S.tier, S.crests, S.route = tierKey, nil, nil end
  local t = ctx.obs.tiers[tierKey]
  self.Icon:SetTexture(t and t.currency.icon or 134400)
  self.Title:SetText("Get " .. T.Currency(ctx.season, tierKey))
  self.Sub:SetText(string.format("You have %s.  %s", T.Count(t and t.currency.ok and t.currency.quantity or nil), CapWords(t)))
  local routes = Routes(ctx, tierKey)
  -- Nothing is chosen, highlighted or drawn until an amount is typed
  local waiting = S.crests == nil
  local chosen = not waiting and Choose(routes) or nil
  self.chosen = chosen
  local y = -74 - RefreshAmount(self, ctx, tierKey, routes, chosen)
  y = RefreshExisting(self, ctx, tierKey, y)
  for i, tile in ipairs(self.tiles) do
    local route = routes[i]
    tile:SetShown(route ~= nil)
    if route then
      tile:ClearAllPoints()
      tile:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y)
      tile:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, y)
      FillTile(tile, route, chosen, waiting)
      y = y - TILE_H
    end
  end
  local stops = PathStops(ctx, chosen, tierKey)
  -- On a full page (three routes, the packs banner, the rounding row) the
  -- picture gives way, so the summary still has room above the buttons
  if stops and y - 66 - 2 * LINE_H < BUTTONS_TOP then stops = nil end
  self.path.frame:SetShown(stops ~= nil)
  if stops then
    self.path.frame:ClearAllPoints()
    self.path.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y - 4)
    self.path.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, y - 4)
    self.path:Render(ctx.season, stops)
    y = y - 66
  else
    self.path:Stop()
  end
  self.Summary:ClearAllPoints()
  self.Summary:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, y)
  self.Summary:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
  -- Never into the buttons: whatever doesn't fit is cut, and its hover shows it whole
  self.Summary:SetPoint("BOTTOM", self.frame, "TOP", 0, math.min(BUTTONS_TOP, y - LINE_H))
  self.Summary:SetText(SummaryText(self, ctx, tierKey, chosen, math.floor((y - BUTTONS_TOP) / LINE_H)))
  self.SummaryHover:EnableMouse(self.Summary:IsTruncated())
  self.Review:SetEnabled(ReviewReady(ctx, chosen) == true)
  self.Review:SetText(chosen and chosen.kind == "plan" and "Review plan" or "Review")
end

-- Review the chosen route for the amount: a trade through the quote
-- controller, a plan through the plan page's state
function Get.Review(p)
  local route = p.chosen
  if not (route and route.ok) then return end
  if route.kind == "plan" then
    Views.Plan.state.crests = S.crests
    return Bus():Fire(E.PlanReviewRequested, route.plan)
  end
  Bus():Fire(E.SelectionChanged, { tier = S.tier, productKey = route.key, crests = S.crests })
  local q = Quote.Controller.Current()
  if q and q.status == "ok" then Bus():Fire(E.ReviewRequested, q) end
end
