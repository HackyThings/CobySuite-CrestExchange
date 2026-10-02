local Config = CobysCrestExchange.Config

---------------------------------------------------------------------------
-- Opening at Vaskarn (Task #53, 2026-10-01): one explicit setting, "When
-- visiting Vaskarn", replaces the old Show at Vaskarn checkbox and the
-- collapsed state the window used to remember. Collapsing and expanding
-- the window change only what shows now, never this setting.
---------------------------------------------------------------------------

-- The saved settings from before the change: Show at Vaskarn off becomes
-- Stay closed, a remembered collapse becomes Show a small tab. Both old keys
-- are removed, so this runs once. saved: the config's SavedVariable (its
-- defaults already filled); windowState: COBYS_CREST_EXCHANGE_WINDOW_STATE.
function Config.MigrateOpening(saved, windowState)
  if type(saved) ~= "table" then return end
  local shown = saved.showPanelAtVendor
  local collapsed = type(windowState) == "table" and windowState.exchangeCollapsed or nil
  if shown == nil and collapsed == nil then return end
  if shown == false then
    saved.vendorOpen = "off"
  elseif collapsed == true then
    saved.vendorOpen = "tab"
  end
  saved.showPanelAtVendor = nil
  if type(windowState) == "table" then windowState.exchangeCollapsed = nil end
end

-- What talking to Vaskarn brings up: "window", "tab", or nil (nothing:
-- Stay closed, or the window or its tab is already up, which the dock only
-- moves beside his list)
function Config.VendorOpening(setting, windowShown, tabShown)
  if windowShown or tabShown or setting == "off" then return nil end
  if setting == "tab" then return "tab" end
  return "window"
end

---------------------------------------------------------------------------
-- Shared config base via CobySuite.Config.New
---------------------------------------------------------------------------
local base = CobySuite_CobysCrestExchange.Config.New({
  savedVariable = "COBYS_CREST_EXCHANGE_CONFIG",
  options = {
    VENDOR_OPEN           = "vendorOpen",            -- what talking to Vaskarn brings up: window, tab, off
    WINDOW_POSITION       = "windowPosition",        -- where it docks: auto, right, left, floating
    USE_INTERACT_KEY      = "useInteractKey",        -- the Interact key presses the one button
    HOLD_INTERACT_SETTING = "holdInteractSetting",   -- Enable Interact Key held on while a plan waits for Vaskarn
  },
  defaults = {
    ["vendorOpen"] = "window",
    ["windowPosition"] = "right",
    ["useInteractKey"] = true,
    ["holdInteractSetting"] = true,
  },
  -- Set refuses a failing value and InitializeData puts the default back for
  -- a failing saved one (a hand-edited or damaged file)
  validate = {
    ["vendorOpen"] = { type = "string", values = { "window", "tab", "off" } },
    ["windowPosition"] = { type = "string", values = { "auto", "right", "left", "floating" } },
    ["useInteractKey"] = { type = "boolean" },
    ["holdInteractSetting"] = { type = "boolean" },
  },
  -- After the defaults are filled and before the stale keys are removed, so
  -- the old keys are still there to read
  migrations = function(saved)
    Config.MigrateOpening(saved, COBYS_CREST_EXCHANGE_WINDOW_STATE)
  end,
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
