-------------------------------------------------------------------------------
-- CobysCrestExchange Session: the one place an exchange moves forward
--
-- States: IDLE, SELECTING, REVIEWING, BUYING, WAITING_FOR_PURCHASE,
-- READY_TO_OPEN, WAITING_FOR_OPEN, WAITING_FOR_LOOT, PAUSED, COMPLETE,
-- UNCERTAIN, NEXT_STEP (a plan between steps). Only this module changes them;
-- Buyer and Opener are helpers.
--
-- Invariants
--   * One operation outstanding at a time.
--   * The approved product, quantity and budget are fixed at confirmation; a
--     larger Max later never raises them.
--   * Before every purchase: Buyer.NextChunk re-validates and sizes the
--     chunk, then the attempt is saved before one BuyMerchantItem call.
--   * Progress moves only on observed results (bag and currency deltas).
--   * A purchase settles only on proof: its crests gone and its packs in the
--     bags. The two arrive on separate game updates, sometimes seconds apart,
--     so the session re-reads every second until the purchase watchdog; a
--     half seen alone is never a verdict before then. A watchdog that expires
--     without proof goes to UNCERTAIN; nothing is ever retried automatically.
--     A purchase sent this session still settles by itself from UNCERTAIN the
--     moment proof shows up (then pauses or opens, never buys); one restored
--     after a reload waits for "Check again", since its saved totals may be
--     stale. "Check again" only reads: it never starts automatic opening.
--   * Stop, combat and the vendor closing pause; nothing resumes spending by
--     itself (not after combat, not after a reload). Resuming is a fresh
--     review and confirmation of what is left.
--   * The open watchdog counts a pack observed gone. Otherwise it stops
--     automatic opening and returns to READY_TO_OPEN with an open_no_effect
--     notice; another open needs a new press.
--
-- The order and its ledger, and a plan with its step index, are saved per
-- character through Store on every change; permission to spend never is.
-- Restore pauses an unfinished order, marks a pending attempt UNCERTAIN, and
-- completes an exhausted order through the normal plan advancement; a saved
-- plan without an order comes back as NEXT_STEP; buying never resumes by itself.
-------------------------------------------------------------------------------

local Session = {}
CobysCrestExchange.Session = Session

local Seams = CobysCrestExchange.Seams
local Seasons = CobysCrestExchange.Seasons
local Store = CobysCrestExchange.Store
local Ledger = CobysCrestExchange.Ledger
local Buyer = CobysCrestExchange.Buyer
local Opener = CobysCrestExchange.Opener
local Observer = CobysCrestExchange.Observer
local E = CobysCrestExchange.Events

local BUY_WATCHDOG = 10
local OPEN_WATCHDOG = 6
local BUY_REREAD = 1
local SETTLE_OPEN = 1.5
local NEXT_CHUNK_DELAY = 0.2
local NEXT_AUTO_DELAY = 0.3

local ST = {
  IDLE = "IDLE", SELECTING = "SELECTING", REVIEWING = "REVIEWING", BUYING = "BUYING",
  WAITING_FOR_PURCHASE = "WAITING_FOR_PURCHASE", READY_TO_OPEN = "READY_TO_OPEN",
  WAITING_FOR_OPEN = "WAITING_FOR_OPEN", WAITING_FOR_LOOT = "WAITING_FOR_LOOT",
  PAUSED = "PAUSED", COMPLETE = "COMPLETE", UNCERTAIN = "UNCERTAIN",
  NEXT_STEP = "NEXT_STEP",   -- a multi-tier plan waits for the press that buys its next step
}

local function NewState()
  return { state = ST.IDLE, order = nil, ledger = nil, frozenQuote = nil, notice = nil, reason = nil,
    needsPress = false, advisorOnly = false, stopRequested = false, auto = false, lootPending = false,
    openBase = nil, uncertainKind = nil, liveAttempt = nil, refusal = nil, blocked = false, receipt = nil,
    plan = nil, frozenPlan = nil, timers = {} }
end
local S = NewState()

-------------------------------------------------------------------------------
-- Plumbing
-------------------------------------------------------------------------------
local function Log(fmt, ...) CobysCrestExchange.Debug.Log("SESSION", fmt, ...) end

local function CancelTimer(name)
  local t = S.timers[name]
  if t and t.Cancel then t:Cancel() end
  S.timers[name] = nil
end

local function CancelAllTimers()
  for name in pairs(S.timers) do CancelTimer(name) end
end

local function StartTimer(name, seconds, fn)
  CancelTimer(name)
  local generation = S
  S.timers[name] = Seams.Call("NewTimer", seconds, function()
    if S ~= generation then return end
    S.timers[name] = nil
    fn()
  end)
end

local function StatusFor(state)
  if state == ST.PAUSED then return "paused" end
  if state == ST.UNCERTAIN then return "uncertain" end
  if state == ST.COMPLETE then return "complete" end
  return "active"
end

local function Persist()
  if S.plan then Store.SavePlan(S.plan) end
  if not S.order or not S.ledger then return end
  S.ledger.status = StatusFor(S.state)
  Store.SaveOrder(S.order, S.ledger)
end

function Session.View()
  local obs = Observer.Current()
  local view = {
    state = S.state, order = S.order, ledger = S.ledger, notice = S.notice, reason = S.reason,
    needsPress = S.needsPress, advisorOnly = S.advisorOnly, auto = S.auto, stopRequested = S.stopRequested,
    receipt = S.receipt, uncertainKind = S.uncertainKind,
    plan = S.plan, frozenPlan = S.frozenPlan,
  }
  if S.order then
    local bagCount = obs.packs and obs.packs[S.order.key] or 0
    local balance
    for _, t in pairs(obs.tiers or {}) do
      if t.tier.currencyID == S.order.destCurrencyID and t.currency.ok then balance = t.currency.quantity end
    end
    view.summary = Ledger.Summary(S.order, S.ledger, bagCount, balance)
    view.openQuota = Ledger.OpenQuota(S.order, S.ledger)
    local ok, why = Opener.MayOpen(S.order, S.ledger, obs, S.lootPending)
    view.canOpen = ok and S.state == ST.READY_TO_OPEN
    view.openBlockedReason = not ok and why or nil
    -- An unproven purchase: what it should change, and what changed so far
    local attempt = S.ledger and S.ledger.attempt
    if S.state == ST.UNCERTAIN and S.uncertainKind == "buy" and attempt then
      local result, dp, ds = Buyer.Classify(S.order, attempt, obs)
      view.check = { result = result, packs = attempt.packs, cost = attempt.packs * S.order.cost,
        packsSeen = result ~= "unknown" and dp or nil, spentSeen = result ~= "unknown" and ds or nil,
        live = attempt == S.liveAttempt }
    end
  end
  return view
end

-- Tests record views here instead of broadcasting them (Session._test.WithState)
local notifySpy

local function Enter(state, notice, reason)
  if S.state ~= state then Log("%s -> %s%s", S.state, state, reason and (" (" .. reason .. ")") or "") end
  S.state = state
  S.notice = notice
  S.reason = reason
  Persist()
  if notifySpy then
    notifySpy(Session.View())
  else
    CobysCrestExchange.EventBus:Fire(E.SessionChanged, Session.View())
  end
end

local function Fresh()
  return Observer.Rebuild()
end

-------------------------------------------------------------------------------
-- Unsettled crests: bought or opened but not yet visible anywhere
-------------------------------------------------------------------------------
function Session.Unsettled(obs)
  local result = {}
  local order = S.order
  if not order or not obs or not obs.season then return result end
  local product = Seasons.ProductByKey(obs.season, order.key)
  if not product then return result end
  local packsNow = obs.packs and obs.packs[order.key] or 0
  local attempt = S.ledger and S.ledger.attempt
  if attempt then
    local arrived = packsNow - attempt.base.packs
    result[product.to] = (result[product.to] or 0) + math.max(0, attempt.packs - arrived) * order.yield
  end
  if S.openBase and (S.state == ST.WAITING_FOR_OPEN or S.state == ST.WAITING_FOR_LOOT) then
    local dst = obs.tiers and obs.tiers[product.to]
    local destNow = dst and dst.currency.ok and dst.currency.quantity or S.openBase.dest
    local consumed = math.max(0, S.openBase.packs - packsNow) * order.yield
    result[product.to] = (result[product.to] or 0) + math.max(0, consumed - (destNow - S.openBase.dest))
  end
  return result
end

-------------------------------------------------------------------------------
-- Endings
-------------------------------------------------------------------------------
local function StopAuto()
  S.auto = false
  CancelTimer("auto")
end

local StartPlanStep   -- defined with the other plan functions below

local function Complete(outcome)
  StopAuto()
  CancelAllTimers()
  local plan = S.plan
  if S.order then
    S.receipt = { order = S.order, ledger = S.ledger, outcome = outcome, plan = plan }
    Store.ClearOrder(plan and outcome == "done" and "step" or outcome)
  end
  S.order, S.ledger, S.frozenQuote = nil, nil, nil
  -- A plan with steps left waits for the press that buys the next one
  if plan and outcome == "done" and plan.index < #plan.steps then
    plan.index = plan.index + 1
    Enter(ST.NEXT_STEP)
    -- Opening packs you have needs no vendor and buys nothing: it starts at
    -- once, from NEXT_STEP, the state the next_step press starts from
    if plan.steps[plan.index].kind == "open" then return StartPlanStep() end
    return
  end
  if plan then
    S.plan = nil
    Store.ClearPlan()
  end
  Enter(ST.COMPLETE, nil, outcome)
end

local function Reset()
  CancelAllTimers()
  local advisorOnly = S.advisorOnly
  S = NewState()
  S.advisorOnly = advisorOnly
end

local function Pause(reason, notice)
  StopAuto()
  CancelTimer("buy"); CancelTimer("settle")
  S.stopRequested = false
  Enter(ST.PAUSED, notice, reason)
end

-------------------------------------------------------------------------------
-- Opening
-------------------------------------------------------------------------------
local AutoStepNow

-- Nothing left to open: done, or paused while packs of the order are still to buy
local function NothingToOpen()
  if Ledger.Remaining(S.order, S.ledger) > 0 then return Pause("more_to_buy") end
  Complete("done")
end

-- `quiet`: never start automatic opening (a settled uncertain purchase)
local function ToOpening(quiet)
  if not S.order then return Enter(ST.IDLE) end
  if Ledger.OpenQuota(S.order, S.ledger) <= 0 then return NothingToOpen() end
  Enter(ST.READY_TO_OPEN)
  local obs = Observer.Current()
  if not quiet and S.order.autoOpen and Seasons.CAPABILITIES.autoOpenAfterClose and not (obs.merchant and obs.merchant.open) then
    S.auto = true
    AutoStepNow()
  end
end

local function BeginOpen()
  local obs = Observer.Current()
  S.openBase = Opener.Baseline(S.order, obs)
  -- saved with the ledger (Enter persists), so a reload mid-open is uncertain, not forgotten
  S.ledger.openAttempt = { packs = S.openBase.packs, dest = S.openBase.dest }
  Enter(ST.WAITING_FOR_OPEN)
  StartTimer("open", OPEN_WATCHDOG, function() Session._OnOpenWatchdog() end)
end

AutoStepNow = function()
  if not S.auto or S.state ~= ST.READY_TO_OPEN then return end
  local obs = Fresh()
  local sent, why = Opener.AutoStep(S.order, S.ledger, obs)
  if sent then
    BeginOpen()
  else
    StopAuto()
    if why ~= "quota" then Enter(ST.READY_TO_OPEN, "auto_stopped", why) end
  end
end

local function ClearOpen()
  S.openBase = nil
  S.uncertainKind = nil
  if S.ledger then S.ledger.openAttempt = nil end
end

-- A pack left the bags: it counts against the order's quota whatever arrived,
-- so an open whose crests look wrong can never free a second open
local function FinishOpen(crests, notice)
  CancelTimer("open"); CancelTimer("settle")
  Ledger.RecordOpen(S.ledger, math.max(0, crests or 0))
  ClearOpen()
  if Ledger.OpenQuota(S.order, S.ledger) <= 0 then return NothingToOpen() end
  Enter(ST.READY_TO_OPEN, notice)
  if S.auto then StartTimer("auto", NEXT_AUTO_DELAY, AutoStepNow) end
end

-- The open's outcome from the baseline: packs gone, crests gained
local function OpenDelta(obs)
  local dp, dd = Opener.Delta(S.order, S.openBase, obs)
  return dp or 0, dd or 0
end

function Session._OnOpenWatchdog()
  if S.state ~= ST.WAITING_FOR_OPEN then return end
  local obs = Fresh()
  -- the rebuild may have settled the open already (OnOpenObservation)
  if S.state ~= ST.WAITING_FOR_OPEN or not S.openBase then return end
  local dp, dd = OpenDelta(obs)
  if dp >= 1 then return FinishOpen(dd, dd ~= S.order.yield and "open_odd" or nil) end
  StopAuto()
  CancelTimer("settle")
  ClearOpen()
  Enter(ST.READY_TO_OPEN, "open_no_effect")
end

local function OnOpenObservation(obs)
  local dp, dd = OpenDelta(obs)
  if dp == 1 and dd == S.order.yield then return FinishOpen(dd) end
  if dp >= 1 and not S.timers.settle then
    -- the pack is gone but the crests don't match yet: give them a moment
    StartTimer("settle", SETTLE_OPEN, function()
      local obs2 = Fresh()
      if S.state ~= ST.WAITING_FOR_OPEN or not S.openBase then return end
      local dp2, dd2 = OpenDelta(obs2)
      if dp2 >= 1 then
        if dd2 ~= S.order.yield then StopAuto() end
        return FinishOpen(dd2, dd2 ~= S.order.yield and "open_odd" or nil)
      end
    end)
  end
end

-------------------------------------------------------------------------------
-- Buying
-------------------------------------------------------------------------------
local Step

local function AfterPurchase(obs)
  local remaining = Ledger.Remaining(S.order, S.ledger)
  if remaining <= 0 then return ToOpening() end
  if S.stopRequested then return Pause("stopped") end
  if obs.inCombat then return Pause("combat") end
  if not (obs.merchant and obs.merchant.open and obs.merchant.isExchange) then return Pause("merchant_closed") end
  if S.needsPress or not Seasons.CAPABILITIES.chunkWithoutPress then
    S.needsPress = true
    return Enter(ST.BUYING)
  end
  Enter(ST.BUYING)
  StartTimer("step", NEXT_CHUNK_DELAY, function() if S.state == ST.BUYING then Step() end end)
end

local function Resolve(result, dp, ds, obs)
  CancelTimer("buy"); CancelTimer("settle")
  if result == "complete" then
    Ledger.ResolveBought(S.ledger, dp, ds)
    S.refusal, S.blocked = nil, false
    Log("Bought %d (%d spent), %d of %d", dp, ds, S.ledger.purchased, S.order.approvedPacks)
    return AfterPurchase(obs)
  end
  S.uncertainKind = "buy"
  Enter(ST.UNCERTAIN, nil, "buy_" .. result)
end

function Session._OnBuyWatchdog()
  if S.state ~= ST.WAITING_FOR_PURCHASE then return end
  local obs = Fresh()
  -- the rebuild may have settled the purchase already (OnBuyObservation)
  if S.state ~= ST.WAITING_FOR_PURCHASE or not S.ledger.attempt then return end
  local result, dp, ds = Buyer.Classify(S.order, S.ledger.attempt, obs)
  if result == "complete" then return Resolve(result, dp, ds, obs) end
  if result == "none" and (S.refusal or S.blocked) then
    Ledger.ResolveNotBought(S.ledger)
    if S.blocked then
      if S.ledger.purchased == 0 then S.advisorOnly = true else S.needsPress = true end
    end
    local reason = S.blocked and "blocked" or "refused"
    local message = S.refusal
    S.refusal, S.blocked = nil, false
    return Pause(reason, message)
  end
  Resolve(result, dp, ds, obs)
end

-- Only proof settles a purchase before the watchdog. The crests leaving and
-- the packs arriving come on separate game updates, sometimes more than a
-- second apart (Cobanyte, 2026-09-30: a real purchase went uncertain when a
-- one-second re-read still saw only the crests gone), so a partial,
-- overshooting or empty reading just waits for the next one.
local function OnBuyObservation(obs)
  local attempt = S.ledger and S.ledger.attempt
  if not attempt then return end
  local result, dp, ds = Buyer.Classify(S.order, attempt, obs)
  if result == "complete" then return Resolve(result, dp, ds, obs) end
end

-- Re-read every second while a purchase is out: the late half may land
-- without another event reaching Observer
local function RereadPurchase()
  StartTimer("settle", BUY_REREAD, function()
    if S.state ~= ST.WAITING_FOR_PURCHASE or not S.ledger.attempt then return end
    Fresh()   -- OnBuyObservation settles it on proof
    if S.state == ST.WAITING_FOR_PURCHASE and S.ledger.attempt then RereadPurchase() end
  end)
end

Step = function()
  if S.state ~= ST.BUYING or not S.order then return end
  if S.stopRequested then return Pause("stopped") end
  local obs = Fresh()
  local chunk, why = Buyer.NextChunk(S.order, S.ledger, obs, Session.Unsettled(obs))
  if not chunk then
    if why == "done" then return ToOpening() end
    return Pause(why)
  end
  Ledger.BeginAttempt(S.ledger, chunk.qty, chunk.base, Seams.Call("Now"))
  -- Sent this session: its baseline is current, so later proof may settle it
  -- by itself (a restored attempt's saved totals may be stale)
  S.liveAttempt = S.ledger.attempt
  S.refusal, S.blocked = nil, false
  Enter(ST.WAITING_FOR_PURCHASE)
  Log("Buying %d of %s (index %d)", chunk.qty, S.order.key, chunk.index)
  StartTimer("buy", BUY_WATCHDOG, function() Session._OnBuyWatchdog() end)
  RereadPurchase()
  Buyer.Send(chunk.index, chunk.qty)
end

-------------------------------------------------------------------------------
-- Approval
-------------------------------------------------------------------------------
local function DestCurrency(obs, product)
  local tier = obs.season and Seasons.Tier(obs.season, product.to)
  return tier and tier.currencyID
end

local ApprovePlan   -- defined with the other plan functions below

local function Approve(fingerprint, autoOpen)
  if S.state ~= ST.REVIEWING then return end
  if S.frozenPlan then return ApprovePlan(fingerprint, autoOpen) end
  if not S.frozenQuote then return end
  local q = S.frozenQuote
  local current = CobysCrestExchange.Quote.Controller.Current()
  if fingerprint ~= q.fingerprint or not current or current.fingerprint ~= q.fingerprint then
    S.frozenQuote = nil
    return Enter(ST.SELECTING, "changed")
  end
  local obs = Observer.Current()
  autoOpen = autoOpen == true and Seasons.CAPABILITIES.autoOpenAfterClose
  if S.order and S.ledger then
    Ledger.Reapprove(S.order, S.ledger, q.packs)
    S.order.autoOpen = autoOpen
    S.order.signature = q.signature
    S.order.cost = q.cost
    S.order.reserve = q.reserve or 0
  else
    S.order = Ledger.NewOrder(q, { now = Seams.Call("Time") or 0, season = obs.season and obs.season.key,
      npcID = obs.merchant and obs.merchant.npcID, destCurrencyID = DestCurrency(obs, q.product), autoOpen = autoOpen })
    S.ledger = Ledger.New(S.order)
  end
  S.frozenQuote = nil
  S.needsPress, S.stopRequested = false, false
  Log("Approved %s: %d packs for %d", S.order.key, S.order.approvedPacks, q.spend)
  Enter(ST.BUYING)
  Step()
end

-- The reserve a plan step's source tier keeps: the player's own reserve, or,
-- for a tier the plan passes through without spending, its balance at the start
local function StepReserve(step)
  local plan = S.plan
  local obs = Observer.Current()
  local tier = obs.season and Seasons.Tier(obs.season, step.from)
  local reserve = tier and Store.GetReserve(tier.currencyID) or 0
  local keep = plan and plan.keep and plan.keep[step.from]
  return math.max(reserve, keep or 0)
end

-- An order that opens packs already in the bags (no purchase)
local function NewOpenOrder(obs, key, quota)
  local season = obs.season
  local product = season and Seasons.ProductByKey(season, key)
  if not product then return false end
  S.order = Ledger.NewOrder({ key = key, itemID = product.itemID, direction = product.kind, yield = product.yield, packs = 0 },
    { kind = "open_existing", now = Seams.Call("Time") or 0, season = season.key, destCurrencyID = DestCurrency(obs, product) })
  S.ledger = Ledger.New(S.order, quota)
  return true
end

-- Run the current step of the plan: open the packs you have, or buy (a
-- fresh quote for exactly its packs)
StartPlanStep = function()
  local plan = S.plan
  local step = plan and plan.steps[plan.index]
  if not step then return end
  local obs = Fresh()
  -- The rebuild runs observers synchronously: recheck before using anything
  if S.plan ~= plan or S.order or plan.steps[plan.index] ~= step then return end
  if step.kind == "open" then
    local count = obs.packs and obs.packs[step.key] or 0
    local quota = math.min(step.packs, count)
    if quota <= 0 or not NewOpenOrder(obs, step.key, quota) then
      -- Opened by hand already: on to the step after it
      if plan.index < #plan.steps then
        plan.index = plan.index + 1
        if plan.steps[plan.index].kind == "open" then return StartPlanStep() end
        return Enter(ST.NEXT_STEP)
      end
      S.plan = nil
      Store.ClearPlan()
      return Enter(ST.COMPLETE, nil, "done")
    end
    S.order.planStep = plan.index
    S.needsPress, S.stopRequested = false, false
    Log("Plan step %d of %d: open %s x%d", plan.index, #plan.steps, step.key, quota)
    return ToOpening()
  end
  if obs.inCombat then return Enter(ST.NEXT_STEP, nil, "combat") end
  if not (obs.merchant and obs.merchant.isExchange) then return Enter(ST.NEXT_STEP, nil, "merchant_closed") end
  local q = CobysCrestExchange.Quote.Build(obs, { productKey = step.key, crests = step.packs * step.yield },
    { reserve = StepReserve(step), unsettled = Session.Unsettled(obs) })
  if q.status ~= "ok" or q.planning then
    return Enter(ST.NEXT_STEP, nil, q.limiter or q.status)
  end
  S.order = Ledger.NewOrder(q, { now = Seams.Call("Time") or 0, season = obs.season and obs.season.key,
    npcID = obs.merchant.npcID, destCurrencyID = DestCurrency(obs, q.product), autoOpen = plan.autoOpen })
  S.order.planStep = plan.index
  S.ledger = Ledger.New(S.order)
  S.needsPress, S.stopRequested = false, false
  Log("Plan step %d of %d: %s x%d", plan.index, #plan.steps, step.key, step.packs)
  Enter(ST.BUYING)
  Step()
end

local function RequestPlanReview(plan)
  if S.state ~= ST.SELECTING or S.order or type(plan) ~= "table" or plan.status ~= "ok" or plan.planning then return end
  local obs = Observer.Current()
  if obs.inCombat then return end
  -- A plan that only opens your own packs buys nothing: no vendor, no buying checks
  if not CobysCrestExchange.Plan.OpenOnly(plan) then
    if S.advisorOnly or not Seasons.CAPABILITIES.buyFromAddon then return end
    if not (obs.merchant and obs.merchant.isExchange) then return end
  end
  S.frozenPlan = plan
  Enter(ST.REVIEWING)
end

-- The plan is rebuilt from its own inputs: anything that changed its steps refuses
ApprovePlan = function(fingerprint, autoOpen)
  local frozen = S.frozenPlan
  local obs = Fresh()
  local opts = { spend = frozen.opts.spend, reserves = frozen.opts.reserves, unsettled = Session.Unsettled(obs) }
  local again = CobysCrestExchange.Plan.Build(obs, frozen.target, frozen.crests, opts)
  S.frozenPlan = nil
  if fingerprint ~= frozen.fingerprint or again.fingerprint ~= frozen.fingerprint then
    return Enter(ST.SELECTING, "changed")
  end
  local keep = {}
  for _, tier in ipairs(obs.season.tiers) do
    local t = obs.tiers[tier.key]
    if not frozen.opts.spend[tier.key] and t and t.currency.ok then keep[tier.key] = t.currency.quantity end
  end
  local steps = {}
  for i, s in ipairs(again.steps) do
    steps[i] = { kind = s.kind, key = s.key, from = s.from, to = s.to, packs = s.packs, cost = s.cost, yield = s.yield,
      spend = s.spend or s.packs * s.cost }
  end
  S.plan = { target = frozen.target, crests = frozen.crests, steps = steps, index = 1, keep = keep,
    autoOpen = autoOpen == true and Seasons.CAPABILITIES.autoOpenAfterClose }
  Log("Plan approved: %d more %s in %d steps", frozen.crests, frozen.target, #steps)
  StartPlanStep()
end

local function RequestReview(q)
  if S.state ~= ST.SELECTING or type(q) ~= "table" or q.status ~= "ok" or q.planning then return end
  local obs = Observer.Current()
  if obs.inCombat or S.advisorOnly or not Seasons.CAPABILITIES.buyFromAddon then return end
  if not (obs.merchant and obs.merchant.isExchange) then return end
  S.frozenQuote = q
  Enter(ST.REVIEWING)
end

-------------------------------------------------------------------------------
-- Commands from the window
-------------------------------------------------------------------------------
-- Settles an uncertain purchase or open from `obs`, on proof only. Every new
-- observation tries it for a purchase sent this session (a late purchase
-- settles by itself); `asked` is the player's Check again, which also covers
-- a restored attempt, says when there is still no proof, and returns an
-- unproven open to ready (an open spends nothing).
local function SettleUncertain(obs, asked)
  local attempt = S.ledger and S.ledger.attempt
  if not asked and (S.uncertainKind ~= "buy" or not attempt or attempt ~= S.liveAttempt) then return end
  if S.uncertainKind == "open" then
    if S.openBase then
      local dp, dd = OpenDelta(obs)
      if dp >= 1 then return FinishOpen(dd, "checked") end
    end
    if not asked then return end
    ClearOpen()
    return Enter(ST.READY_TO_OPEN, "checked")
  end
  if not attempt then
    S.uncertainKind = nil
    return Pause("checked")
  end
  local result, dp, ds = Buyer.Classify(S.order, attempt, obs)
  if result ~= "complete" then
    -- Only proof settles a purchase: time passing is not proof it failed, and
    -- freeing the allowance could buy the same packs twice. Discard ends the order.
    if asked then return Enter(ST.UNCERTAIN, "still_unclear", S.reason) end
    return
  end
  Ledger.ResolveBought(S.ledger, dp, ds)
  S.uncertainKind = nil
  Log("Settled the uncertain purchase: %d (%d spent)%s", dp, ds, asked and ", checked" or "")
  if Ledger.Remaining(S.order, S.ledger) <= 0 then return ToOpening(true) end
  -- The rest is never bought without a fresh review
  Pause(asked and "checked" or "arrived")
end

local function Reconcile()
  local obs = Fresh()   -- may settle it already (OnObservations)
  if S.state ~= ST.UNCERTAIN then return end
  SettleUncertain(obs, true)
end

local function OpenExisting(key)
  local obs = Observer.Current()
  local count = obs.packs and obs.packs[key] or 0
  if count <= 0 or S.order then return end
  if NewOpenOrder(obs, key, count) then ToOpening() end
end

local function ReviewRemaining()
  if S.state ~= ST.PAUSED or not S.order then return end
  local remaining = Ledger.Remaining(S.order, S.ledger)
  local obs = Observer.Current()
  if remaining <= 0 or not (obs.merchant and obs.merchant.isExchange) then return end
  local product = obs.season and Seasons.ProductByKey(obs.season, S.order.key)
  if not product then return end
  Enter(ST.SELECTING)
  CobysCrestExchange.EventBus:Fire(E.SelectionChanged, { tier = product.to, productKey = S.order.key,
    crests = remaining * S.order.yield, capPacks = remaining, resume = true })
end

local COMMANDS = {
  stop = function()
    if S.state == ST.BUYING then return Pause("stopped") end
    if S.state == ST.WAITING_FOR_PURCHASE then S.stopRequested = true; return Enter(S.state, "stopping") end
    if S.auto then StopAuto(); return Enter(S.state, "auto_stopped") end
  end,
  continue = function() if S.state == ST.BUYING and S.needsPress then Step() end end,
  leave_rest = function() if S.state == ST.READY_TO_OPEN or S.state == ST.PAUSED then Complete("left") end end,
  review_remaining = ReviewRemaining,
  open_purchased = function()
    if (S.state == ST.PAUSED or S.state == ST.COMPLETE) and S.order and Ledger.OpenQuota(S.order, S.ledger) > 0 then ToOpening() end
  end,
  discard = function()
    if S.order then Store.ClearOrder("discarded") end
    if S.plan then Store.ClearPlan() end
    Reset(); Enter(ST.IDLE)
  end,
  next_step = function() if S.state == ST.NEXT_STEP then StartPlanStep() end end,
  done = function()
    if S.state == ST.COMPLETE or not S.order then Reset(); Enter(ST.IDLE) end
  end,
  check_again = function() if S.state == ST.UNCERTAIN then Reconcile() end end,
  open_existing = OpenExisting,
  cancel_review = function()
    if S.state == ST.REVIEWING then S.frozenQuote, S.frozenPlan = nil, nil; Enter(ST.SELECTING) end
  end,
  back = function()
    if S.state ~= ST.SELECTING then return end
    if S.order then return Enter(ST.PAUSED, nil, "restored") end
    Enter(ST.IDLE)
  end,
}

-------------------------------------------------------------------------------
-- Event handling
-------------------------------------------------------------------------------
local function OnSelection(sel)
  if sel and sel.resume then return end
  if S.order or S.plan then return end
  if S.state == ST.IDLE or S.state == ST.COMPLETE or S.state == ST.SELECTING then
    if S.state == ST.COMPLETE then S.receipt = nil end
    if sel then Enter(ST.SELECTING) elseif S.state ~= ST.IDLE then Enter(ST.IDLE) end
  end
end

local function OnObservations(obs)
  if S.state == ST.WAITING_FOR_PURCHASE then return OnBuyObservation(obs) end
  if S.state == ST.WAITING_FOR_OPEN then return OnOpenObservation(obs) end
  if S.state == ST.UNCERTAIN then return SettleUncertain(obs, false) end
  if S.state == ST.REVIEWING and obs.inCombat then S.frozenQuote = nil; return Enter(ST.SELECTING, "changed") end
end

local function OnMerchantChanged(state)
  if state == "other" and S.auto then StopAuto() end
  if state == "closed" or state == "other" then
    if S.state == ST.REVIEWING then S.frozenQuote = nil; return Enter(ST.SELECTING, "changed") end
    if S.state == ST.BUYING then return Pause("merchant_closed") end
    if S.state == ST.WAITING_FOR_PURCHASE then S.stopRequested = true; return end
    if S.state == ST.READY_TO_OPEN and state == "closed" and S.order and S.order.autoOpen
      and Seasons.CAPABILITIES.autoOpenAfterClose then
      S.auto = true
      return StartTimer("auto", NEXT_AUTO_DELAY, AutoStepNow)
    end
    if S.state == ST.READY_TO_OPEN then return Enter(S.state, S.notice) end
  elseif state == "exchange" then
    if S.auto then StopAuto() end
    Enter(S.state, S.notice, S.reason)
  end
end

function Session:ReceiveEvent(event, a, b)
  if event == E.ObservationsChanged then return OnObservations(a) end
  if event == E.SelectionChanged then return OnSelection(a) end
  if event == E.ReviewRequested then return RequestReview(a) end
  if event == E.PlanReviewRequested then return RequestPlanReview(a) end
  if event == E.PurchaseApproved then return Approve(a, b) end
  if event == E.SessionCommand then
    local fn = COMMANDS[a]
    if fn then fn(b) end
    return
  end
  if event == E.OpenAttempted then
    if S.state == ST.READY_TO_OPEN then BeginOpen() end
    return
  end
  if event == E.MerchantChanged then return OnMerchantChanged(a) end
  if event == E.QuoteChanged then
    if S.state == ST.REVIEWING and not S.frozenPlan and (not a or not S.frozenQuote or a.fingerprint ~= S.frozenQuote.fingerprint) then
      S.frozenQuote = nil
      Enter(ST.SELECTING, "changed")
    end
  end
end

CobysCrestExchange.EventBus:Register(Session, {
  E.ObservationsChanged, E.SelectionChanged, E.ReviewRequested, E.PlanReviewRequested, E.PurchaseApproved,
  E.SessionCommand, E.OpenAttempted, E.MerchantChanged, E.QuoteChanged,
})

-------------------------------------------------------------------------------
-- Game events forwarded by Observer
-------------------------------------------------------------------------------
local GAME_EVENTS = {
  LOOT_READY = true, LOOT_OPENED = true, LOOT_CLOSED = true, UI_ERROR_MESSAGE = true,
  PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true,
  ADDON_ACTION_BLOCKED = true, ADDON_ACTION_FORBIDDEN = true,
}

function Session.WantsGameEvent(event) return GAME_EVENTS[event] == true end

function Session.OnGameEvent(event, a, b)
  if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    if a == "CobysCrestExchange" then
      S.blocked = true
      Log("%s: %s", event, tostring(b))
    end
  elseif event == "UI_ERROR_MESSAGE" then
    local message = not Seams.IsSecret(b) and b or nil
    if S.state == ST.WAITING_FOR_PURCHASE then S.refusal = message end
    if S.state == ST.WAITING_FOR_OPEN then
      StopAuto()
      local obs = Fresh()
      -- the rebuild may have settled the open (and even the order) already
      if S.state ~= ST.WAITING_FOR_OPEN or not S.order or not S.openBase then return end
      local dp = OpenDelta(obs)
      if dp == 0 then
        CancelTimer("open"); CancelTimer("settle")
        ClearOpen()
        Enter(ST.READY_TO_OPEN, "game_message", message)
      end
    end
  elseif event == "LOOT_OPENED" then
    if S.state == ST.WAITING_FOR_OPEN and not a then
      S.lootPending = true
      CancelTimer("open")
      Enter(ST.WAITING_FOR_LOOT)
    end
  elseif event == "LOOT_CLOSED" then
    S.lootPending = false
    if S.state == ST.WAITING_FOR_LOOT then
      Enter(ST.WAITING_FOR_OPEN)
      StartTimer("open", OPEN_WATCHDOG, function() Session._OnOpenWatchdog() end)
      Observer.Invalidate()
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    StopAuto()
    if S.state == ST.BUYING then Pause("combat")
    elseif S.state == ST.WAITING_FOR_PURCHASE then S.stopRequested = true
    elseif S.state == ST.REVIEWING then S.frozenQuote = nil; Enter(ST.SELECTING, "changed")
    else Enter(S.state, S.notice, S.reason) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    Enter(S.state, S.notice, S.reason)
  end
end

-------------------------------------------------------------------------------
-- Public helpers
-------------------------------------------------------------------------------
function Session.State() return S.state end

function Session.IsBusy()
  return S.state == ST.BUYING or S.state == ST.WAITING_FOR_PURCHASE or S.state == ST.WAITING_FOR_OPEN
    or S.state == ST.WAITING_FOR_LOOT
end

-- The secure Open button's gate; the button blanks its action on false
function Session.MayOpen()
  if S.state ~= ST.READY_TO_OPEN then return false, "busy" end
  return Opener.MayOpen(S.order, S.ledger, Observer.Current(), S.lootPending)
end

function Session.OpenItemID()
  return S.order and S.order.itemID
end

-- The one button's next action, from the state and what the game shows now:
--   open   READY_TO_OPEN and a pack may open (the secure item use)
--   close  READY_TO_OPEN but a vendor's window is open: using a pack there
--          would sell it, so the press closes the window and opens nothing
--   buy    NEXT_STEP at Vaskarn: the press buys the plan's next step ("Buy
--          step N of M"); an open step reads "Start step N of M" anywhere
--   talk   NEXT_STEP away from Vaskarn: nothing to press; the label says why
--   wait   buying or opening is under way
-- nil for every other state (the page shows its own buttons there)
function Session.NextAction()
  local obs = Observer.Current()
  local st = S.state
  if st == ST.READY_TO_OPEN and S.order then
    local ok, why = Opener.MayOpen(S.order, S.ledger, obs, S.lootPending)
    if ok then return { mode = "open", label = "Open next pack", enabled = true } end
    if why == "merchant_open" and not obs.inCombat then
      return { mode = "close", label = "Close the vendor's window", enabled = true, reason = why }
    end
    return { mode = "open", label = "Open next pack", enabled = false, reason = why }
  end
  if st == ST.WAITING_FOR_OPEN or st == ST.WAITING_FOR_LOOT then
    return { mode = "wait", label = "Opening pack...", enabled = false }
  end
  if st == ST.BUYING or st == ST.WAITING_FOR_PURCHASE then
    return { mode = "wait", label = "Buying...", enabled = false }
  end
  local plan = S.plan
  if st == ST.NEXT_STEP and plan and plan.steps[plan.index] then
    if plan.steps[plan.index].kind == "open" then
      return { mode = "buy", label = string.format("Start step %d of %d", plan.index, #plan.steps), enabled = not obs.inCombat }
    end
    local label = string.format("Buy step %d of %d", plan.index, #plan.steps)
    if obs.inCombat then return { mode = "buy", label = label, enabled = false, reason = "combat" } end
    if obs.merchant and obs.merchant.isExchange then return { mode = "buy", label = label, enabled = true } end
    return { mode = "talk", label = string.format("Talk to Vaskarn for step %d", plan.index), enabled = false,
      reason = "merchant_closed" }
  end
  return nil
end

-- At login: bring a saved order back as PAUSED or UNCERTAIN (completed
-- through the normal plan advancement when nothing is left), or a saved plan
-- with no order as NEXT_STEP; never buying
function Session.Restore()
  S.plan = Store.GetPlan()
  local order, ledger = Store.GetOrder()
  if not order then
    if S.plan then Enter(ST.NEXT_STEP, nil, "restored") end
    return
  end
  S.order, S.ledger = order, ledger
  if ledger.attempt then
    S.uncertainKind = "buy"
    Enter(ST.UNCERTAIN, nil, "restored")
  elseif ledger.openAttempt then
    S.uncertainKind = "open"
    S.openBase = { packs = ledger.openAttempt.packs, dest = ledger.openAttempt.dest }
    Enter(ST.UNCERTAIN, nil, "restored_open")
  elseif Ledger.Remaining(order, ledger) <= 0 and Ledger.OpenQuota(order, ledger) <= 0 then
    Complete("done")
  else
    Enter(ST.PAUSED, nil, "restored")
  end
end

-- Tests only: run fn with a fresh session state, then put the real one back
Session._test = {
  -- fn(getState, views): runs with a fresh state; views collects every
  -- SessionChanged view instead of broadcasting it
  WithState = function(fn)
    local saved, savedSpy = S, notifySpy
    local views = {}
    S = NewState()
    notifySpy = function(view) views[#views + 1] = view end
    local ok, err = pcall(fn, function() return S end, views)
    CancelAllTimers()
    S, notifySpy = saved, savedSpy
    if not ok then error(err, 0) end
  end,
}
