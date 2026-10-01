local Config = CobysCrestExchange.Config

---------------------------------------------------------------------------
-- Shared config base via CobySuite.Config.New
---------------------------------------------------------------------------
local base = CobySuite_CobysCrestExchange.Config.New({
  savedVariable = "COBYS_CREST_EXCHANGE_CONFIG",
  options = {
    SHOW_PANEL_AT_VENDOR = "showPanelAtVendor",   -- open the exchange window beside Vaskarn's list
    WINDOW_POSITION      = "windowPosition",      -- where it docks: auto, right, left, floating
    USE_INTERACT_KEY     = "useInteractKey",      -- the Interact key presses the one button and talks to Vaskarn
  },
  defaults = {
    ["showPanelAtVendor"] = true,
    ["windowPosition"] = "right",
    ["useInteractKey"] = true,
  },
  -- Set refuses a failing value and InitializeData puts the default back for
  -- a failing saved one (a hand-edited or damaged file)
  validate = {
    ["showPanelAtVendor"] = { type = "boolean" },
    ["windowPosition"] = { type = "string", values = { "auto", "right", "left", "floating" } },
    ["useInteractKey"] = { type = "boolean" },
  },
  debug = CobysCrestExchange.Debug,
  onSet = function(name, old, value)
    CobysCrestExchange.EventBus:Fire(CobysCrestExchange.Events.ConfigChanged, name, value, old)
  end,
  onReset = function()
    CobysCrestExchange.EventBus:Fire(CobysCrestExchange.Events.ConfigChanged)
  end,
})

-- Install onto CobysCrestExchange.Config namespace
Config.Options       = base.Options
Config.Defaults      = base.Defaults
Config.IsValidOption = base.IsValidOption
Config.CheckValue    = base.CheckValue
Config.Get           = base.Get
Config.Set           = base.Set
Config.Reset         = base.Reset

---------------------------------------------------------------------------
-- InitializeData: wraps base with addon-specific SavedVariable init
---------------------------------------------------------------------------
function Config.InitializeData()
  base.InitializeData()

  if type(COBYS_CREST_EXCHANGE_WINDOW_STATE) ~= "table" then
    COBYS_CREST_EXCHANGE_WINDOW_STATE = {}
  end

  CobysCrestExchange.Debug.Log("CONFIG", "Config initialized")
end
