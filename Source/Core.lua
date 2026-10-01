CobysCrestExchange = {
  Debug = {},
  Config = {},
  Utilities = {},
}

CobysCrestExchange.BRAND_COLOR = "6C8EF5"
CobysCrestExchange.ICON = "Interface\\Icons\\inv_121_crest_myth"   -- the TOC's IconTexture: the Season 2 Myth Mistcrest

-------------------------------------------------------------------------------
-- EventBus event constants
-------------------------------------------------------------------------------
CobysCrestExchange.Events = {
  ConfigChanged       = "cobyscrestexchange_config_changed",        -- name, value, old
  ObservationsChanged = "cobyscrestexchange_observations_changed",  -- obs
  MerchantChanged     = "cobyscrestexchange_merchant_changed",      -- "exchange"|"other"|"closed", npcID
  SelectionChanged    = "cobyscrestexchange_selection_changed",     -- { tier, productKey, crests, capPacks, resume } or nil
  PreferenceChanged   = "cobyscrestexchange_preference_changed",    -- kind, key, value
  QuoteChanged        = "cobyscrestexchange_quote_changed",         -- quote or nil
  ReviewRequested     = "cobyscrestexchange_review_requested",      -- quote
  PlanReviewRequested = "cobyscrestexchange_plan_review_requested", -- plan
  PurchaseApproved    = "cobyscrestexchange_purchase_approved",     -- fingerprint, autoOpen
  SessionCommand      = "cobyscrestexchange_session_command",       -- command, arg
  OpenAttempted       = "cobyscrestexchange_open_attempted",        -- itemID
  SessionChanged      = "cobyscrestexchange_session_changed",       -- view
}

-------------------------------------------------------------------------------
-- Addon metadata
-------------------------------------------------------------------------------
local ADDON_NAME = "CobysCrestExchange"
local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.1"
CobysCrestExchange.VERSION = VERSION

-------------------------------------------------------------------------------
-- Slash commands
--
-- The suite's standard set (CobySuite.Slash.StandardCommands: show, settings,
-- guide, changelog, debug, and test in development builds only, with the
-- same aliases in every addon) plus this addon's own dump, registered through
-- CobySuite.Slash, which generates help and version. Every module is defined
-- in a later file, so each handler resolves it per call. The release build
-- leaves the Tests folder out, so CobysCrestExchange.Tests is nil there and
-- the test command does not exist.
-------------------------------------------------------------------------------
local function Views() return CobysCrestExchange.Views or {} end

local function ToggleWindow()
  if Views().Window then Views().Window.Toggle() end
end

CobySuite_CobysCrestExchange.Slash.Register({
  key = "COBYSCRESTEXCHANGE",
  slashes = { "/ce", "/crestex", "/crestexchange" },
  title = "Coby's Crest Exchange",
  version = VERSION,
  message = function(text) CobysCrestExchange.Utilities.Message(text) end,
  onEmpty = ToggleWindow,
  commands = CobySuite_CobysCrestExchange.Slash.StandardCommands({
    show = ToggleWindow,
    showHelp = "Open or close the exchange window",
    settings = function()
      if CobysCrestExchange.Config.ToggleSettings then CobysCrestExchange.Config.ToggleSettings() end
    end,
    guide = function() if Views().Guide then Views().Guide.Toggle() end end,
    changelog = function() if Views().WhatsNew then Views().WhatsNew.Toggle() end end,
    debug = function()
      if CobysCrestExchange.DebugWindow then CobysCrestExchange.DebugWindow:Toggle() end
    end,
    tests = function() return CobysCrestExchange.Tests end,
    extra = {
      {
        name = "dump", help = "Show a report of what the addon sees, selected for Ctrl+C (for bug reports)",
        run = function()
          if CobysCrestExchange.Capture then CobysCrestExchange.Capture.Show() end
        end,
      },
    },
  }),
})

-------------------------------------------------------------------------------
-- Startup sequence
-------------------------------------------------------------------------------
EventUtil.ContinueOnAddOnLoaded(ADDON_NAME, function()
  local ns = CobysCrestExchange
  if ns.Config.InitializeData then ns.Config.InitializeData() end
  if ns.Store then COBYS_CREST_EXCHANGE_DATA = ns.Store.Initialize(COBYS_CREST_EXCHANGE_DATA) end
  ns.Debug.Log("INIT", "Coby's Crest Exchange v%s loaded", VERSION)
end)

EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_LOGIN", function()
  local ns = CobysCrestExchange
  local season = ns.Seasons and ns.Seasons.Active(ns.Seams.Call("Interface"))
  if ns.Store then ns.Store.BindCharacter(season and season.key or "none") end
  if ns.Observer then ns.Observer.Start(season) end
  if ns.Session then ns.Session.Restore() end
  local Views = ns.Views
  if Views then
    if Views.Dock then Views.Dock.Hook() end
    if Views.WhatsNew then Views.WhatsNew.OnLogin() end
  end
  ns.Debug.Log("INIT", "PLAYER_LOGIN complete (season %s)", season and season.key or "unknown")
end)
