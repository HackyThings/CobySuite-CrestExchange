-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Window: the exchange window and its page host
--
-- One CobySuite.UI.CreateWindow (MEDIUM strata, toplevel, Escape closes it,
-- position and size saved). Every page is built once at load by its own
-- file (Window.AddPage) and shown by name; nothing is created later, so the
-- window opens safely in combat.
--
-- Routing: REVIEWING shows the Review page; while an exchange is under way
-- (buying, opening, paused, done, uncertain, a plan waiting for its next
-- step, or an unfinished order waiting) the Progress page shows; otherwise
-- the page the player navigated to (overview, source, plan, requirements,
-- before, or amount when resuming). Refreshes are folded into one per frame.
--
-- At the vendor the window opens by itself as the "When visiting Vaskarn"
-- setting says (the window, its small tab, or nothing), and Dock places it
-- beside the merchant window. Collapsing and expanding change only what
-- shows now, never that setting. Closing the window never touches an order;
-- the session keeps watching in the background.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = {}
Views.Window = Window

local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local E = CobysCrestExchange.Events

-- The height of Blizzard's merchant window, so the two sit side by side as a pair
local WIDTH, HEIGHT = 400, 444
local PROGRESS_STATES = {
  BUYING = true, WAITING_FOR_PURCHASE = true, READY_TO_OPEN = true, WAITING_FOR_OPEN = true,
  WAITING_FOR_LOOT = true, PAUSED = true, COMPLETE = true, UNCERTAIN = true, NEXT_STEP = true,
}

local pages = {}
local nav = { page = "overview" }
Window.nav = nav

local frame = UI.CreateWindow({
  name = "CobysCrestExchangeWindow",
  title = U.WrapColor(CobysCrestExchange.BRAND_COLOR, "Coby's Crest Exchange"),
  icon = CobysCrestExchange.ICON,
  width = WIDTH, height = HEIGHT,
  resizable = { minWidth = 380, minHeight = 444, maxWidth = 760, maxHeight = 960 },
  escapeCloses = true,
  persist = {
    svTable = function() return COBYS_CREST_EXCHANGE_WINDOW_STATE end,
    key = "exchange",
    defaults = { point = "CENTER", relPoint = "CENTER", x = 0, y = 60 },
  },
})
Window.frame = frame

-- Header line under the title: the season on the left, where you are on the right
frame.SeasonText = frame:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
frame.SeasonText:SetPoint("TOPLEFT", 14, -30)
frame.PlaceText = frame:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
frame.PlaceText:SetPoint("TOPRIGHT", -14, -30)

frame.Content = CreateFrame("Frame", nil, frame)
frame.Content:SetPoint("TOPLEFT", 12, -48)
frame.Content:SetPoint("BOTTOMRIGHT", -12, 12)

-------------------------------------------------------------------------------
-- Pages
-------------------------------------------------------------------------------
-- build(host) returns the page table with an optional Refresh(page, ctx);
-- AddPage sets page.frame to the host
function Window.AddPage(name, build)
  local host = CreateFrame("Frame", nil, frame.Content)
  host:SetAllPoints()
  host:Hide()
  local page = build(host) or {}
  page.frame = host
  pages[name] = page
  return page
end

function Window.Page(name) return pages[name] end

local function Context()
  local obs = CobysCrestExchange.Observer.Current()
  return {
    obs = obs,
    season = obs.season,
    view = CobysCrestExchange.Session.View(),
    quote = CobysCrestExchange.Quote.Controller.Current(),
    nav = nav,
  }
end
Window.Context = Context

-- Why a page the player picks (Window.Go) can't show now, by PickPage's own
-- rules: nil (it can), "receipt" (a finished exchange's receipt, which the
-- done command dismisses) or "busy" (a review, or an exchange under way)
local function NavBlock(view)
  if view.state == "COMPLETE" then return "receipt" end
  if view.state == "REVIEWING" or PROGRESS_STATES[view.state] then return "busy" end
  if view.order and view.state ~= "SELECTING" then return "busy" end
  return nil
end

function Window.NavBlock() return NavBlock(CobysCrestExchange.Session.View()) end

local function PickPage(ctx)
  local view = ctx.view
  local block = NavBlock(view)
  if block then return view.state == "REVIEWING" and "review" or "progress" end
  if not ctx.season then return "overview" end
  return pages[nav.page] and nav.page or "overview"
end

local function RefreshNow()
  if not frame:IsShown() then return end
  local ctx = Context()
  frame.SeasonText:SetText(ctx.season and ctx.season.label or "Unknown season")
  local atVendor = ctx.obs.merchant and ctx.obs.merchant.isExchange
  frame.PlaceText:SetText(atVendor and U.WrapColor(U.Colors.SUCCESS_GREEN, "At Vaskarn")
    or U.WrapColor(U.Colors.LABEL_GRAY, "Planning"))
  local name = PickPage(ctx)
  for pageName, page in pairs(pages) do
    if pageName ~= name then page.frame:Hide() end
  end
  local page = pages[name]
  if page then
    page.frame:Show()
    if page.Refresh then page:Refresh(ctx) end
  end
end

local coalesced = U.Coalesce(0, RefreshNow)
function Window.Refresh() coalesced:Call() end
function Window.RefreshNow() coalesced:Cancel(); RefreshNow() end

-- Navigate within the idle pages (overview, source, plan, requirements,
-- before; amount when resuming).
-- fields are set; clear lists fields to remove (a nil in fields can't do that)
function Window.Go(page, fields, clear)
  nav.page = page
  if fields then for k, v in pairs(fields) do nav[k] = v end end
  if clear then for _, k in ipairs(clear) do nav[k] = nil end end
  Window.RefreshNow()
end

-------------------------------------------------------------------------------
-- Showing
-------------------------------------------------------------------------------
-- The full window
local function ShowFull()
  if Views.Dock then
    Views.Dock.HideTab()
    Views.Dock.Place(frame)
  else
    frame:RestoreState()
  end
  frame:Show()
  Window.RefreshNow()
end

-- The full window, or with "tab" only its small tab
function Window.Show(how)
  if how == "tab" and Views.Dock then
    frame:Hide()
    Views.Dock.ShowTab(frame)
    return
  end
  ShowFull()
end

-- Collapse to the tab for now; the exchange carries on in the background
function Window.Collapse()
  if not Views.Dock then return end
  local autoShown = Window.autoShown
  Views.Dock.ShowTab(frame)
  frame:Hide()
  Window.autoShown = autoShown
end

-- Expand from the tab
function Window.Expand()
  local autoShown = Window.autoShown
  ShowFull()
  Window.autoShown = autoShown
end

function Window.Hide()
  frame:Hide()
  if Views.Dock then Views.Dock.HideTab() end
end

-- /ce and the compartment: open fully when nothing shows, close whatever shows
function Window.Toggle()
  if frame:IsShown() or (Views.Dock and Views.Dock.TabShown()) then
    Window.Hide()
  else
    Window.Expand()
  end
end

function Window.IsShown() return frame:IsShown() end

frame:HookScript("OnShow", function() Window.Refresh() end)
frame:HookScript("OnHide", function()
  Window.autoShown = false
  -- Closing the window during a review cancels it
  local Session = CobysCrestExchange.Session
  if Session and Session.State() == "REVIEWING" then
    CobysCrestExchange.EventBus:Fire(E.SessionCommand, "cancel_review")
  end
end)

-------------------------------------------------------------------------------
-- Listening
-------------------------------------------------------------------------------
local listener = {}

local function OnMerchant(state)
  local Config = CobysCrestExchange.Config
  if state == "exchange" then
    -- A frame later: MERCHANT_SHOW can come before Blizzard's merchant window
    -- is shown, and the dock needs its position
    C_Timer.After(0, function()
      local obs = CobysCrestExchange.Observer.Current()
      if not (obs.merchant and obs.merchant.isExchange) then return end
      local tabShown = Views.Dock and Views.Dock.TabShown()
      local how = obs.season and Config.VendorOpening(Config.Get(Config.Options.VENDOR_OPEN), frame:IsShown(), tabShown)
      if how then
        Window.Show(how)
        Window.autoShown = true
      elseif frame:IsShown() and Views.Dock then
        Views.Dock.Place(frame)
      elseif tabShown then
        Views.Dock.ShowTab(frame)
      end
    end)
  elseif state == "closed" and (frame:IsShown() or (Views.Dock and Views.Dock.TabShown())) then
    local view = CobysCrestExchange.Session.View()
    local idle = not view.order and (view.state == "IDLE" or view.state == "SELECTING" or view.state == "COMPLETE")
    if Window.autoShown and idle then
      Window.Hide()
    elseif Views.Dock then
      if frame:IsShown() then Views.Dock.FloatFree(frame) end
      if Views.Dock.TabShown() then Views.Dock.FloatFree(Views.Dock.tab) end
    end
  end
end

function listener:ReceiveEvent(event, a)
  if event == E.MerchantChanged then OnMerchant(a) end
  if event == E.SelectionChanged and type(a) == "table" and a.resume then
    nav.page, nav.productKey, nav.tier = "amount", a.productKey, a.tier
  end
  if event == E.SessionChanged and a and a.state == "IDLE" and nav.page == "amount" then
    nav.page = "overview"
  end
  Window.Refresh()
end

CobysCrestExchange.EventBus:Register(listener, {
  E.ObservationsChanged, E.SessionChanged, E.QuoteChanged, E.MerchantChanged, E.ConfigChanged, E.SelectionChanged,
})

-- Title bar: the guide's "?" and the settings gear beside the close button
frame.HelpButton = UI.CreateHelpButton(frame, {
  name = "CobysCrestExchangeWindowHelpButton",
  tooltip = "What Coby's Crest Exchange can do",
  onClick = function() if Views.Guide then Views.Guide.Toggle() end end,
})
frame.SettingsButton = UI.CreateSettingsGearButton(frame, {
  point = { "RIGHT", frame.HelpButton, "LEFT", -2, 0 },
  height = 20,
  tooltip = "Coby's Crest Exchange settings",
  onClick = function() CobysCrestExchange.Config.ToggleSettings() end,
})
-- Collapse to a small tab beside the vendor window (the tab's + expands it)
frame.CollapseButton = UI.CreateIconButton(frame, {
  name = "CobysCrestExchangeCollapseButton",
  atlas = UI.FOLD_ATLAS.open,
  size = 18,
  point = { "RIGHT", frame.SettingsButton, "LEFT", -4, 0 },
  tooltip = "Collapse to a small tab beside the vendor window",
  onClick = function() Window.Collapse() end,
})
