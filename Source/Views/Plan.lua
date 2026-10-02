-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Plan: "I want X more Myth" from several tiers
--
-- Type how many crests of the target to receive (or Max). Once you press
-- Enter or leave the box, the ladder below previews the whole plan: each
-- tier's balance before and
-- after, the target glowing, and each step's trade with dots flowing up it
-- ("Step 1: 6 packs, 180 Champion to 60 Hero"). Each tier below the target
-- has a Spend checkbox: checked, the plan may spend the crests you have
-- there; unchecked, crests made there along the way are used and your
-- balance stays as it is. One review and one confirmation start the plan;
-- the progress page then walks through the steps.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = Views.Window
local T = Views.Text
local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local Seasons = CobysCrestExchange.Seasons
local Plan = CobysCrestExchange.Plan
local Store = CobysCrestExchange.Store
local E = CobysCrestExchange.Events

local PlanView = {}
Views.Plan = PlanView

-- What the player chose on this page (kept while the page is open)
local S = { target = nil, crests = nil, spend = {} }
PlanView.state = S

local function Options(ctx)
  local reserves = {}
  for _, tier in ipairs(ctx.season.tiers) do reserves[tier.currencyID] = Store.GetReserve(tier.currencyID) end
  local Session = CobysCrestExchange.Session
  return { spend = S.spend, reserves = reserves, unsettled = Session and Session.Unsettled(ctx.obs) or {} }
end

function PlanView.Current(ctx)
  if not (ctx.season and S.target) then return nil end
  return Plan.Build(ctx.obs, S.target, S.crests, Options(ctx))
end

-- Start a plan for a tier: every tier below it may be spent at first
function PlanView.Start(tierKey)
  local season = CobysCrestExchange.Observer.Season()
  S.target, S.crests, S.spend = tierKey, nil, {}
  for _, tier in ipairs(season and Plan.SourceTiers(season, tierKey) or {}) do S.spend[tier.key] = true end
  Window.Go("plan", { tier = tierKey })
end

local function SetCrests(n) S.crests = n; Window.RefreshNow() end

local function Build(host)
  local page = {}
  page.Title = host:CreateFontString(nil, "OVERLAY", U.Fonts.HEADING)
  page.Title:SetPoint("TOPLEFT", 4, -4)
  local label = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  label:SetPoint("TOPLEFT", 6, -34)
  label:SetText("Receive")
  page.Input = UI.CreateNumberInput(host, { width = 64, maxLetters = 6, point = { "LEFT", label, "RIGHT", 10, 0 },
    parse = function(text) local n = tonumber(text); return n and n == math.floor(n) and n or nil end,
    validate = function(n) return n >= 1 and n <= 100000 end,
    onCommit = function(n) SetCrests(n) end })
  page.Input:SetNumeric(true)   -- digits only
  page.Unit = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Unit:SetPoint("LEFT", page.Input, "RIGHT", 8, 0)
  page.Max = UI.CreateButton(host, { text = "Max", size = { 50, 22 }, point = { "TOPRIGHT", host, "TOPRIGHT", -4, -30 },
    onClick = function() if page.plan and page.plan.maxCrests > 0 then SetCrests(page.plan.maxCrests) end end })
  UI.AddDynamicTooltip(page.Max, function(tip)
    local plan = page.plan
    tip:AddLine("Max: " .. (plan and T.Count(plan.maxCrests) or "?"))
    if plan and plan.limiter then tip:AddLine("Limited by: " .. T.PlanLimiter(plan, page.season, page.away, page.obs), 1, 1, 1, true) end
  end, { fillable = true })
  page.Round = CreateFrame("Frame", nil, host)
  page.Round:SetPoint("TOPLEFT", 6, -56)
  page.Round:SetSize(300, 22)
  page.Round.Text = page.Round:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.Round.Text:SetPoint("LEFT")
  page.Round.Down = UI.CreateButton(page.Round, { text = "", size = { 60, 20 }, point = { "LEFT", page.Round.Text, "RIGHT", 6, 0 },
    onClick = function() if page.plan and page.plan.rounding then SetCrests(page.plan.rounding.down) end end })
  page.Round.Up = UI.CreateButton(page.Round, { text = "", size = { 60, 20 }, point = { "LEFT", page.Round.Down, "RIGHT", 4, 0 },
    onClick = function() if page.plan and page.plan.rounding then SetCrests(page.plan.rounding.up) end end })
  page.ladder = Views.Ladder.Create(host, { top = -80, nodeH = 28, gap = 14,
    onSpend = function(tierKey, on) S.spend[tierKey] = on and true or nil; Window.RefreshNow() end })
  page.Summary = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Summary:SetPoint("TOPLEFT", page.ladder.frame, "BOTTOMLEFT", 2, -8)
  page.Summary:SetPoint("TOPRIGHT", page.ladder.frame, "BOTTOMRIGHT", -2, -8)
  page.Summary:SetJustifyH("LEFT")
  page.Summary:SetSpacing(2)
  page.Back = UI.CreateButton(host, { text = "Back", size = { 90, 22 }, point = { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 },
    onClick = function()
      -- The Get page keeps the amount typed here, with the plan still chosen
      Views.Get.state.crests, Views.Get.state.route = S.crests, "plan"
      Window.Go("source")
    end })
  page.Review = UI.CreateButton(host, { text = "Review plan", size = { 150, 24 }, point = { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 4 },
    onClick = function()
      if page.plan and page.plan.status == "ok" then CobysCrestExchange.EventBus:Fire(E.PlanReviewRequested, page.plan) end
    end })
  return page
end

-- The ladder model for a plan: before and after, the target glowing, steps flowing
local function Model(ctx, plan)
  local model = { season = ctx.season, nodes = {}, links = {} }
  local targetIndex = Seasons.TierIndex(ctx.season, S.target)
  local stepByTo, opens = {}, {}
  for i, step in ipairs(plan.steps or {}) do
    if step.kind == "open" then opens[#opens + 1] = { index = i, step = step }
    else stepByTo[step.to] = { index = i, step = step } end
  end
  for i, tier in ipairs(ctx.season.tiers) do
    local t = ctx.obs.tiers[tier.key]
    local before = t and t.currency.ok and t.currency.quantity or nil
    local after = plan.after and plan.after[tier.key]
    local node = { icon = t and t.currency.icon, value = T.Count(before), dim = i > targetIndex }
    if plan.status == "ok" and after and before and after ~= before then
      node.value = T.Count(before) .. " > " .. T.Count(after)
      node.valueColor = after > before and { 0.3, 1, 0.3 } or { 1, 0.55, 0.3 }
    end
    if i < targetIndex then
      node.spend = S.spend[tier.key] == true
    elseif i == targetIndex then
      node.glow = true
    end
    model.nodes[tier.key] = node
  end
  -- Packs you have: said on the tier's tile, not as a trade between tiers
  for _, o in ipairs(opens) do
    local node = model.nodes[o.step.to]
    if node then node.sub = string.format("Step %d: %s", o.index, T.StepWords(ctx.season, o.step)) end
  end
  for _, tier in ipairs(ctx.season.tiers) do
    local entry = stepByTo[tier.key]
    if entry then
      local s = entry.step
      model.links[tier.key] = { state = "pending", label = string.format("Step %d: %s, %s to %s", entry.index,
        T.Packs(s.packs), T.Crests(ctx.season, s.from, s.spend), T.Crests(ctx.season, s.to, s.packs * s.yield)) }
    end
  end
  return model
end

local function SummaryText(ctx, plan)
  local lines = {}
  if plan.status == "ok" then
    local steps, presses = #plan.steps, 0
    for _, s in ipairs(plan.steps) do presses = presses + s.packs end
    lines[#lines + 1] = string.format("%s in %d %s. You'll press Open once per pack (%d in all); the panel shows each next press.",
      T.Crests(ctx.season, S.target, S.crests), steps, T.Plural(steps, "step", "steps"), presses)
    local over = {}
    for key, after in pairs(plan.after or {}) do
      local before = plan.before[key]
      if before and after > before and key ~= S.target then over[#over + 1] = T.Crests(ctx.season, key, after - before) end
    end
    if #over > 0 then lines[#lines + 1] = "Left over from rounding up to whole packs: " .. table.concat(over, ", ") .. "." end
  elseif plan.status == "too_many" then
    lines[#lines + 1] = U.WrapColor(U.Colors.CAUTION_ORANGE, "That's more than a plan can make right now: " .. T.PlanLimiter(plan, ctx.season, not (ctx.obs.merchant and ctx.obs.merchant.isExchange), ctx.obs))
  elseif plan.status == "empty" then
    lines[#lines + 1] = string.format("Up to %s now. Type an amount, or press Max.", T.Crests(ctx.season, S.target, plan.maxCrests))
  elseif plan.status == "invalid" then
    lines[#lines + 1] = "Enter a whole number of crests."
  end
  if plan.planning then lines[#lines + 1] = "Visit Vaskarn to run this plan; the rates shown are from your last visit." end
  if ctx.view.advisorOnly then lines[#lines + 1] = "Buying from this window was refused by the game." end
  return table.concat(lines, "\n")
end

local page = Window.AddPage("plan", Build)
function page:Refresh(ctx)
  if not ctx.season or not S.target then return Window.Go("overview") end
  self.season = ctx.season
  self.away = not (ctx.obs.merchant and ctx.obs.merchant.isExchange)
  self.obs = ctx.obs
  local plan = PlanView.Current(ctx)
  self.plan = plan
  self.Title:SetText("Get " .. T.Currency(ctx.season, S.target) .. " from lower tiers")
  if not self.Input:HasFocus() then self.Input:SetCommittedValue(S.crests) end
  self.Unit:SetText(string.format("more %s   (up to %s)", T.Tier(ctx.season, S.target), T.Count(plan.maxCrests or 0)))
  local r = self.Round
  r:SetShown(plan.status == "rounding")
  if plan.status == "rounding" then
    r.Text:SetText(string.format("Packs hold %s. Choose", T.Count(plan.yield)))
    r.Down:SetShown(plan.rounding.down ~= nil); r.Down:SetText(T.Count(plan.rounding.down or 0))
    r.Up:SetShown(plan.rounding.up ~= nil); r.Up:SetText(T.Count(plan.rounding.up or 0))
  end
  self.ladder:Render(Model(ctx, plan))
  self.Summary:SetText(SummaryText(ctx, plan))
  local ok
  if plan.status == "ok" and Plan.OpenOnly(plan) then
    -- Only your own packs are opened: no vendor, no buying checks
    ok = not ctx.obs.inCombat and ctx.view.state == "SELECTING"
  else
    ok = plan.status == "ok" and not plan.planning and not ctx.obs.inCombat and not ctx.view.advisorOnly
      and ctx.obs.merchant.isExchange == true and ctx.view.state == "SELECTING"
  end
  self.Review:SetEnabled(ok == true)
end
