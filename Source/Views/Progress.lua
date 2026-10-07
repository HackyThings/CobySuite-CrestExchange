-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Progress: an exchange under way, stopped or done
--
-- One page with a mode per session state:
--   buying     purchased so far, crests spent, waiting; Stop after this
--              purchase; Buy next pack only when the game needs a press
--   opening    opened so far, crests received, what the next press does;
--              the one button (Views/SecureOpen.lua) fixed at the bottom
--              center; End exchange here (End plan here with a plan) sits
--              bottom left, clear of it
--   next       a plan between steps: the ladder, the step bar and what the
--              next step does; the one button buys it at Vaskarn (or starts
--              an open step), else says to talk to him; Discard
--   paused     the unfinished order: received, still in packs, not yet
--              bought; Open purchased packs, Review remaining, Discard
--   uncertain  the last purchase or open isn't confirmed; nothing more is
--              bought; the rows show what changed since the purchase, the
--              message what to look for and what each button does; Check
--              again only reads; Copy details, Discard
--   done       the receipt; Choose another exchange, Close
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = Views.Window
local T = Views.Text
local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local WHITE = U.Colors.HIGHLIGHT_WHITE
local Seasons = CobysCrestExchange.Seasons
local E = CobysCrestExchange.Events

local function Command(cmd, arg) CobysCrestExchange.EventBus:Fire(E.SessionCommand, cmd, arg) end

local DISCARD_BODY = "The rest of this exchange won't be bought. Packs in your bags and crests you already have stay yours."
-- An unconfirmed purchase may still land: discarding can't call it back
local DISCARD_UNCONFIRMED = "The last purchase may still arrive; discarding can't cancel it."

local discardPopup = UI.CreateDialogPopup({
  name = "CobysCrestExchangeDiscardPopup",
  icon = CobysCrestExchange.ICON,
  title = "Discard this order?",
  danger = true,
  body = DISCARD_BODY,
  confirmText = "Discard", cancelText = "Keep",
  width = 360, height = 150, hidden = true,
  onConfirm = function() Command("discard") end,
})

local MODES = {
  BUYING = "buying", WAITING_FOR_PURCHASE = "buying",
  READY_TO_OPEN = "opening", WAITING_FOR_OPEN = "opening", WAITING_FOR_LOOT = "opening",
  PAUSED = "paused", UNCERTAIN = "uncertain", COMPLETE = "done", NEXT_STEP = "next",
}

local function Button(host, text, width, point, onClick)
  return UI.CreateButton(host, { text = text, size = { width, 22 }, point = point, onClick = onClick })
end

local function Build(host)
  local page = {}
  page.Title = host:CreateFontString(nil, "OVERLAY", U.Fonts.HEADING)
  page.Title:SetPoint("TOPLEFT", 4, -4)
  page.Title:SetPoint("TOPRIGHT", -4, -4)
  page.Title:SetJustifyH("LEFT")
  -- A plan's ladder: done steps checked, the current one flowing, the target glowing
  page.ladder = Views.Ladder.Create(host, { top = -26, nodeH = 24, gap = 12 })
  page.ladder.frame:Hide()
  -- A plan's progress: every step bought and opened counts
  page.StepBar = CreateFrame("StatusBar", nil, host)
  page.StepBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  page.StepBar:SetStatusBarColor(0.75, 0.52, 0.05)
  page.StepBar:SetMinMaxValues(0, 1)
  page.StepBar:SetHeight(16)
  page.StepBar.bg = page.StepBar:CreateTexture(nil, "BACKGROUND")
  page.StepBar.bg:SetAllPoints()
  -- A lighter track than the window, so an empty bar still reads as a bar
  page.StepBar.bg:SetColorTexture(1, 1, 1, 0.12)
  page.StepBar.Text = page.StepBar:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  page.StepBar.Text:SetPoint("CENTER")
  local font, size = page.StepBar.Text:GetFont()
  if font then page.StepBar.Text:SetFont(font, size, "OUTLINE") end
  page.StepBar.Text:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
  page.StepBar:Hide()
  page.Figures = CreateFrame("Frame", nil, host)
  page.Figures:SetPoint("TOPLEFT", 0, -36)
  page.Figures:SetPoint("TOPRIGHT", 0, -36)
  page.Figures:SetHeight(18 * 4)
  page.Rows = {}
  for i = 1, 4 do
    local row = CreateFrame("Frame", nil, page.Figures)
    row:SetHeight(18)
    row:SetPoint("TOPLEFT", 4, -(i - 1) * 18)
    row:SetPoint("TOPRIGHT", -4, -(i - 1) * 18)
    U.AddAlternatingRowBg(row, i)
    row.Label = row:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
    row.Label:SetPoint("LEFT", 0, 0)
    row.Value = row:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
    row.Value:SetPoint("RIGHT", -4, 0)
    page.Rows[i] = row
  end
  page.Message = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Message:SetPoint("TOPLEFT", 6, -120)
  page.Message:SetPoint("TOPRIGHT", -6, -120)
  page.Message:SetJustifyH("LEFT")
  -- Under the figures, never centred in the room left above the buttons
  page.Message:SetJustifyV("TOP")
  -- A receipt's figures: one stat tile per tier that changed, and the
  -- unopened packs (the shared tiles, built at load)
  page.tileList = {}
  page.Tiles = UI.CreateStatTiles(host, { tiles = function() return page.tileList end, maxTiles = 6,
    columns = 2, minTileWidth = 150, height = 46 })
  page.Tiles:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -30)
  page.Tiles:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -30)
  page.Tiles:Hide()

  page.Stop = Button(host, "Stop after this purchase", 190, { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 44 },
    function() Command("stop") end)
  page.BuyNext = Button(host, "Buy next pack", 150, { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 44 },
    function() Command("continue") end)
  page.Leave = Button(host, "End exchange here", 190, { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 44 },
    function() Command("leave_rest") end)
  -- Disabled while a pack opens: its tooltip still says why
  page.Leave:SetMotionScriptsWhileDisabled(true)
  UI.AddDynamicTooltip(page.Leave, function(tip, button)
    if not button:IsEnabled() then
      tip:AddLine(page.planActive and "End plan here" or "End exchange here")
      tip:AddLine("Wait for the pack to finish opening.", 1, 1, 1, true)
    elseif page.planActive then
      tip:AddLine("End plan here")
      tip:AddLine("Ends this plan without buying its remaining steps. Unopened packs stay in your bags.", 1, 1, 1, true)
    else
      tip:AddLine("End exchange here")
      tip:AddLine("Ends this exchange without buying any more packs. Unopened packs stay in your bags.", 1, 1, 1, true)
    end
  end, { fillable = true })
  page.OpenPurchased = Button(host, "Open purchased packs", 170, { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 44 },
    function() Command("open_purchased") end)
  page.ReviewRemaining = Button(host, "Review remaining", 150, { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 44 },
    function() Command("review_remaining") end)
  page.Discard = Button(host, "Discard order", 120, { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 },
    function()
      -- Read at the click: only a purchase still unconfirmed gets the warning
      local view = CobysCrestExchange.Session.View()
      local unconfirmed = view.state == "UNCERTAIN" and view.uncertainKind ~= "open"
      discardPopup:SetBody(unconfirmed and (DISCARD_BODY .. " " .. DISCARD_UNCONFIRMED) or DISCARD_BODY)
      discardPopup:Show()
    end)
  page.CheckAgain = Button(host, "Check again", 120, { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 44 },
    function() Command("check_again") end)
  page.CopyDetails = Button(host, "Copy details", 120, { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 4 },
    function() CobysCrestExchange.Capture.Show() end)
  UI.AddDynamicTooltip(page.CheckAgain, function(tip)
    tip:AddLine("Check again")
    tip:AddLine("Reads your bags and crests now. Only reads: nothing is bought.", 1, 1, 1, true)
  end, { fillable = true })
  UI.AddDynamicTooltip(page.CopyDetails, function(tip)
    tip:AddLine("Copy details")
    tip:AddLine("A plain-text report of your crests, packs and this exchange. It opens selected: press Ctrl+C to copy it, then paste it where someone can help.", 1, 1, 1, true)
  end, { fillable = true })
  page.Another = Button(host, "Choose another exchange", 190, { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 },
    function() Command("done"); Window.Go("overview") end)
  page.Close = Button(host, "Close", 90, { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 4 },
    function() Command("done"); Window.Go("overview"); Window.Hide() end)

  page.Open = Views.SecureOpen.Create(host, { "BOTTOM", host, "BOTTOM", 0, 74 })
  page.OpenHint = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.OpenHint:SetPoint("BOTTOM", page.Open, "TOP", 0, 6)
  page.OpenHint:SetPoint("LEFT", host, "LEFT", 6, 0)
  page.OpenHint:SetPoint("RIGHT", host, "RIGHT", -6, 0)
  page.all = { page.Stop, page.BuyNext, page.Leave, page.OpenPurchased, page.ReviewRemaining, page.Discard,
    page.CheckAgain, page.CopyDetails, page.Another, page.Close }
  return page
end

local function SetRows(page, rows)
  page.lastRows = rows
  -- The plain layout's figures take only the rows they show
  if not page.planned then page.Figures:SetHeight(18 * math.max(1, #rows)) end
  for i, row in ipairs(page.Rows) do
    local data = rows[i]
    row:SetShown(data ~= nil)
    if data then
      row.Label:SetText(data[1])
      row.Value:SetText(data[2])
    end
  end
end

local function Only(page, ...)
  local keep = {}
  for i = 1, select("#", ...) do
    local button = select(i, ...)
    if button then keep[button] = true end
  end
  for _, b in ipairs(page.all) do b:SetShown(keep[b] == true) end
end

local function Buying(page, ctx, view)
  local o, l, s = view.order, view.ledger, ctx.season
  page.Title:SetText(string.format("Buying %s crest packs", T.Tier(s, Seasons.ProductByKey(s, o.key).to)))
  SetRows(page, {
    { "Purchased", string.format("%s of %s", T.Count(l.purchased), T.Count(o.approvedPacks)) },
    { "Spent", string.format("%s of %s", T.Count(l.spent), T.Count(o.approvedPacks * o.cost)) },
  })
  local msg = view.state == "WAITING_FOR_PURCHASE" and "Waiting for the merchant..." or ""
  if view.needsPress then msg = "The game needs a press for each purchase. Press Buy next pack to continue." end
  if view.notice then msg = T.Notice(view.notice, view.reason) or msg end
  page.Message:SetText(msg)
  Only(page, page.Stop, view.needsPress and view.state == "BUYING" and page.BuyNext or nil)
  page.Stop:SetEnabled(not view.stopRequested)
end

-- A single exchange's opening as a bar under the title, the figures below it
-- (verified opens only)
local function OpenBar(page, opened, total)
  local bar = page.StepBar
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 2, -30)
  bar:SetPoint("TOPRIGHT", page.frame, "TOPRIGHT", -2, -30)
  bar:SetValue(total > 0 and math.min(1, opened / total) or 0)
  bar.Text:SetText(string.format("Opened %s of %s", T.Count(opened), T.Packs(total)))
  bar:Show()
  page.Figures:ClearAllPoints()
  page.Figures:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -2, -6)
  page.Figures:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 2, -6)
end

local function Opening(page, ctx, view)
  local o, l, s = view.order, view.ledger, ctx.season
  local product = Seasons.ProductByKey(s, o.key)
  local total = o.kind == "open_existing" and l.openQuota or l.purchased
  page.Title:SetText(string.format("Open your %s crest packs", T.Tier(s, product.to)))
  local rows = {
    { "Received", T.Crests(s, product.to, l.received) },
    { "Balance", T.Count(view.summary and view.summary.balanceNow) },
  }
  if page.planned then
    -- A plan's own bar counts its steps; the opens go in the folded line
    table.insert(rows, 1, { "Opened", string.format("%s of %s", T.Count(l.opened), T.Count(total)) })
  else
    OpenBar(page, l.opened or 0, total or 0)
  end
  SetRows(page, rows)
  local msg
  if view.state == "WAITING_FOR_LOOT" then
    msg = "Collect the contents in the loot window; the next pack is ready after."
  elseif view.state == "WAITING_FOR_OPEN" then
    msg = "Opening pack..."
  elseif view.canOpen then
    msg = string.format("Next press opens 1 pack for %s.", T.Crests(s, product.to, o.yield))
  else
    msg = T.OpenBlock(view.openBlockedReason)
  end
  local notice = T.Notice(view.notice, view.reason)
  if notice then msg = notice .. "\n" .. (msg or "") end
  page.Message:SetText(msg or "")
  -- The last refused press, only while that refusal still holds: one from an
  -- earlier pack or exchange never lingers (run 2026-10-01: "Wait for the last
  -- pack" stayed up beside a ready Open next pack)
  local lastRefusal = Views.SecureOpen.button and Views.SecureOpen.button.lastRefusal
  local mayOpen, why = CobysCrestExchange.Session.MayOpen()
  page.OpenHint:SetText(lastRefusal and not mayOpen and why == lastRefusal and T.OpenBlock(lastRefusal) or "")
  page.planActive = view.plan ~= nil
  page.Leave:SetText(view.plan and "End plan here" or "End exchange here")
  -- Ending waits for an open in flight (and its loot) to settle
  page.Leave:SetEnabled(view.state == "READY_TO_OPEN")
  Only(page, page.Leave)
end

local function Paused(page, ctx, view)
  local o, s, sum = view.order, ctx.season, view.summary
  local product = Seasons.ProductByKey(s, o.key)
  local goal = o.kind == "open_existing" and "open your packs" or ("receive " .. T.Count(sum.goal) .. " more " .. T.TierLabel(s, product.to))
  page.Title:SetText("Unfinished: " .. goal)
  SetRows(page, {
    { "Received so far", T.Count(sum.received) },
    { "Still in purchased packs", T.Count(sum.stillInPacks * o.yield) .. " (" .. T.Packs(sum.stillInPacks) .. ")" },
    { "Not yet bought", T.Count(sum.notBought) .. (sum.notBoughtPacks > 0
      and (" (" .. T.Packs(sum.notBoughtPacks) .. ", " .. T.Crests(s, product.from, sum.notBoughtCost) .. ")") or "") },
    { "Your balance now", T.Count(sum.balanceNow) },
  })
  local lines = { T.Pause(view.reason) or "" }
  if view.notice then lines[#lines + 1] = T.Notice(view.notice, view.reason) or view.notice end
  if sum.missingPacks > 0 then
    lines[#lines + 1] = string.format("%s from this order aren't in your bags any more; they aren't bought again.", T.Packs(sum.missingPacks))
  end
  local canReview = sum.notBoughtPacks > 0 and ctx.obs.merchant and ctx.obs.merchant.isExchange
  if sum.notBoughtPacks > 0 and not canReview then
    lines[#lines + 1] = "Talk to Vaskarn again to review and buy the rest."
  elseif canReview then
    lines[#lines + 1] = "Review remaining to buy the rest."
  end
  if (view.openQuota or 0) > 0 then
    lines[#lines + 1] = "Open purchased packs to collect the crests already bought."
  end
  page.Message:SetText(table.concat(lines, "\n"))
  Only(page, (view.openQuota or 0) > 0 and page.OpenPurchased or nil, canReview and page.ReviewRemaining or nil, page.Discard)
end

local function Uncertain(page, ctx, view)
  local notice = T.Notice(view.notice, view.reason)
  local product = view.order and Seasons.ProductByKey(ctx.season, view.order.key)
  if view.uncertainKind == "open" then
    page.Title:SetText("Last pack needs checking")
    SetRows(page, {})
    page.Message:SetText(T.UncertainOpenMessage(notice))
  elseif view.check and product then
    page.Title:SetText("Waiting to see the last purchase")
    SetRows(page, T.UncertainRows(ctx.season, product, view.check, view.ledger, view.order))
    page.Message:SetText(T.UncertainMessage(view.check, view.reason, notice))
  else
    page.Title:SetText("Last purchase needs checking")
    SetRows(page, {})
    page.Message:SetText(T.UncertainPlainMessage(notice))
  end
  Only(page, page.CheckAgain, page.CopyDetails, page.Discard)
end

-- One receipt tile: a tier's crests received or spent, in its color
local function TierTile(ctx, key, n, received)
  local t = ctx.obs.tiers[key]
  local r, g, b = U.HexToRGB(T.TierColor(ctx.season, key))
  return { key = key .. (received and "+" or "-"), icon = t and t.currency.icon or 134400, value = T.Count(n),
    label = T.TierLabel(ctx.season, key) .. (received and " received" or " spent"), labelColor = { r, g, b },
    color = received and n > 0 and U.Colors.SUCCESS_GREEN or nil }
end

-- A receipt's tiles: what each tier received, then spent, then any packs
-- left unopened. A plan counts each tier's net change over all its steps
-- (the target first), so crests made on the way and spent again cancel out
local function ReceiptTiles(ctx, r)
  local s, list = ctx.season, {}
  if r.plan then
    local t = r.plan.totals or { spent = {}, received = {} }
    local target = r.plan.target
    local function Net(key) return (t.received[key] or 0) - (t.spent[key] or 0) end
    list[1] = TierTile(ctx, target, math.max(0, Net(target)), true)
    for _, tier in ipairs(s.tiers) do
      local n = Net(tier.key)
      if n > 0 and tier.key ~= target then list[#list + 1] = TierTile(ctx, tier.key, n, true) end
    end
    for _, tier in ipairs(s.tiers) do
      local n = Net(tier.key)
      if n < 0 then list[#list + 1] = TierTile(ctx, tier.key, -n, false) end
    end
  elseif r.order then
    local product = Seasons.ProductByKey(s, r.order.key)
    list[1] = TierTile(ctx, product.to, r.ledger.received or 0, true)
    -- Opening packs you had spends nothing
    if r.order.kind ~= "open_existing" then list[2] = TierTile(ctx, product.from, r.ledger.spent or 0, false) end
  end
  if (r.unopened or 0) > 0 then
    list[#list + 1] = { key = "unopened", icon = CobysCrestExchange.ICON, value = T.Count(r.unopened),
      label = T.Plural(r.unopened, "Pack left unopened", "Packs left unopened") }
  end
  while #list > 6 do table.remove(list) end
  return list
end

local function Done(page, ctx, view)
  local r = view.receipt
  local s = ctx.season
  local left = r and r.outcome == "left"
  local opening = r and not r.plan and r.order and r.order.kind == "open_existing"
  local title
  if r and r.plan then
    -- An ended plan names its goal as a goal, not as what it made
    title = left and string.format("Plan ended (goal: %s more %s)", T.Count(r.plan.crests), T.Tier(s, r.plan.target))
      or string.format("Plan complete: %s more %s", T.Count(r.plan.crests), T.Tier(s, r.plan.target))
  elseif opening then
    title = left and "Opening ended" or "Packs opened"
  else
    title = left and "Exchange ended" or "Exchange complete"
  end
  page.Title:SetText(title)
  SetRows(page, {})
  page.tileList = r and ReceiptTiles(ctx, r) or {}
  page.Tiles:Show()
  page.Tiles:Refresh()
  page.Figures:Hide()
  page.Message:ClearAllPoints()
  page.Message:SetPoint("TOPLEFT", page.Tiles, "BOTTOMLEFT", 6, -10)
  page.Message:SetPoint("TOPRIGHT", page.Tiles, "BOTTOMRIGHT", -6, -10)
  local message
  if left then
    message = r.plan and "This plan ended here; its remaining steps weren't bought."
      or opening and "Opening ended here."
      or "This exchange ended here; nothing more was bought."
  else
    message = (r and (r.unopened or 0) > 0) and "This exchange is done." or "All packs opened. What you received is shown above."
  end
  if r and (r.unopened or 0) > 0 then
    message = message .. " Unopened packs stay in your bags: choose another exchange, then Open packs on the first page."
  end
  page.Message:SetText(message)
  Only(page, page.Another, page.Close)
end

-------------------------------------------------------------------------------
-- Plans: the ladder at the top, and the press that buys the next step
-------------------------------------------------------------------------------
local function PlanModel(ctx, view)
  local plan, season = view.plan, ctx.season
  local model = { season = season, nodes = {}, links = {} }
  local targetIndex = Seasons.TierIndex(season, plan.target)
  for i, tier in ipairs(season.tiers) do
    local t = ctx.obs.tiers[tier.key]
    model.nodes[tier.key] = { icon = t and t.currency.icon, value = T.Count(t and t.currency.ok and t.currency.quantity or nil),
      glow = i == targetIndex, dim = i > targetIndex }
  end
  for i, s in ipairs(plan.steps) do
    local state = (i < plan.index) and "done" or (i == plan.index and view.state ~= "NEXT_STEP" and "current") or "pending"
    if s.kind == "open" then
      -- Packs you have: said on the tier's tile, not as a trade between tiers
      local node = model.nodes[s.to]
      if node then node.sub = string.format("Step %d: %s%s", i, T.StepWords(season, s), state == "done" and " (done)" or "") end
    else
    model.links[s.to] = { state = state, label = string.format("Step %d: %s, %s to %s", i, T.Packs(s.packs),
      T.Crests(season, s.from, s.spend or s.packs * s.cost), T.Crests(season, s.to, s.packs * s.yield)) }
    end
  end
  return model
end

local function Next(page, ctx, view)
  local plan = view.plan
  local step = plan.steps[plan.index]
  page.Title:SetText(string.format("Plan: step %d of %d is ready", plan.index, #plan.steps))
  SetRows(page, {
    { "Next step", T.StepWords(ctx.season, step) },
    { "Packs", T.Count(step.packs) },
  })
  local atVendor = ctx.obs.merchant and ctx.obs.merchant.isExchange
  local msg
  if step.kind == "open" then
    msg = "The button below opens the packs you have."
  elseif ctx.obs.inCombat then
    msg = T.StepBlocked("combat")
  elseif not atVendor then
    local IK = Views.InteractKey
    local key = IK and IK.Name()
    local target = key and not IK.TalkReady() and ", target him" or ""
    if key and IK.KeyState() == "modified" then
      -- A key with a modifier is never bound to the button: it only talks
      msg = string.format("Walk up to Vaskarn%s and press %s to talk to him, then click the button below to buy the next step.", target, key)
    elseif key then
      msg = string.format("Walk up to Vaskarn%s and press %s to talk to him, then the same key buys the next step.", target, key)
    elseif IK and IK.KeyState() ~= "none" then
      msg = T.StepBlocked("merchant_closed") .. " Then use the button below."   -- the key setting is off
    else
      msg = T.StepBlocked("merchant_closed") .. " With a key bound to Interact with Target, one key does every step."
    end
  elseif view.reason and view.reason ~= "restored" and view.reason ~= "merchant_closed" and view.reason ~= "combat" then
    msg = T.StepBlocked(view.reason)
  else
    msg = "The button below buys the next step, then opens each pack, one press per pack."
  end
  page.Message:SetText(msg)
  Only(page, page.Discard)
end

local RENDER = { buying = Buying, opening = Opening, paused = Paused, uncertain = Uncertain, done = Done, next = Next }

-- How far a plan has come: steps done, and in the current step its packs
-- bought and opened (an open step counts its opens only); 0 to 1, with words
local function PlanProgress(view)
  local plan = view.plan
  local n = #plan.steps
  local frac, words = 0, nil
  local o, l = view.order, view.ledger
  if view.state ~= "NEXT_STEP" and o and l then
    if o.kind == "open_existing" then
      local packs = math.max(1, l.openQuota or 1)
      frac = (l.opened or 0) / packs
      words = string.format("opened %d of %d", l.opened or 0, l.openQuota or 0)
    else
      local packs = math.max(1, o.approvedPacks or 1)
      frac = ((l.purchased or 0) + (l.opened or 0)) / (2 * packs)
      words = string.format("bought %d of %d, opened %d of %d", l.purchased or 0, o.approvedPacks or 0, l.opened or 0, l.purchased or 0)
    end
  end
  local done = plan.index - 1
  local text = view.state == "NEXT_STEP"
    and string.format("%d of %d %s done", done, n, T.Plural(n, "step", "steps"))
    or string.format("Step %d of %d: %s", plan.index, n, words or "starting")
  return (done + math.min(1, frac)) / n, text
end

local function LayoutForPlan(page, ctx, view)
  -- An uncertain purchase keeps the plain layout even in a plan: its rows and
  -- explanation need the room the ladder would take (review, 2026-09-30)
  local planned = view.plan ~= nil and ctx.season ~= nil and view.state ~= "UNCERTAIN" and view.state ~= "COMPLETE"
  page.planned = planned
  page.ladder.frame:SetShown(planned)
  page.StepBar:SetShown(planned)
  page.Figures:ClearAllPoints()
  page.Message:ClearAllPoints()
  if planned then
    -- The ladder takes the room: the figures are hidden and folded into the
    -- message line (page:Refresh)
    page.ladder:Render(PlanModel(ctx, view))
    page.StepBar:ClearAllPoints()
    page.StepBar:SetPoint("TOPLEFT", page.ladder.frame, "BOTTOMLEFT", 2, -6)
    page.StepBar:SetPoint("TOPRIGHT", page.ladder.frame, "BOTTOMRIGHT", -2, -6)
    local value, text = PlanProgress(view)
    page.StepBar:SetValue(value)
    page.StepBar.Text:SetText(text)
    page.Figures:SetPoint("TOPLEFT", page.StepBar, "BOTTOMLEFT", -2, -4)
    page.Figures:SetPoint("TOPRIGHT", page.StepBar, "BOTTOMRIGHT", 2, -4)
    page.Figures:SetHeight(1)
  else
    page.ladder:StopAll()
    page.Figures:SetPoint("TOPLEFT", 0, -36)
    page.Figures:SetPoint("TOPRIGHT", 0, -36)
    page.Figures:SetHeight(18 * 4)
  end
  page.Figures:SetShown(not planned)
  page.Message:SetPoint("TOPLEFT", page.Figures, "BOTTOMLEFT", 6, -8)
  page.Message:SetPoint("TOPRIGHT", page.Figures, "BOTTOMRIGHT", -6, -8)
end

local page = Window.AddPage("progress", Build)
function page:Refresh(ctx)
  local view = ctx.view
  local mode = MODES[view.state] or (view.order and "paused")
  if not mode or not ctx.season or (mode ~= "done" and mode ~= "next" and not view.order) or (mode == "next" and not view.plan) then
    self.Title:SetText("")
    self.Message:SetText("")
    SetRows(self, {})
    Only(self, self.Close)
    self.Open:Hide()
    self.Tiles:Hide()
    self.StepBar:Hide()
    return
  end
  LayoutForPlan(self, ctx, view)
  RENDER[mode](self, ctx, view)
  if self.planned and self.lastRows and #self.lastRows > 0 then
    local parts = {}
    for _, row in ipairs(self.lastRows) do parts[#parts + 1] = row[1] .. ": " .. tostring(row[2]) end
    self.Message:SetText(table.concat(parts, "   ") .. "\n" .. (self.Message:GetText() or ""))
  end
  if mode ~= "done" then self.Tiles:Hide() end
  -- Receipts have no button: there is nothing left to press (Task #236)
  local opening = mode == "opening" or mode == "next"
  self.Open:SetShown(opening)
  -- The text never runs under the button: it ends above the hint line, which
  -- only opening shows
  if opening then
    self.Message:SetPoint("BOTTOM", self.Open, "TOP", 0, mode == "opening" and 22 or 6)
  elseif mode == "uncertain" then
    self.Message:SetPoint("BOTTOM", self.CheckAgain, "TOP", 0, 6)
  end
  self.OpenHint:SetShown(mode == "opening")
  Views.SecureOpen.Update(view)
end
