-------------------------------------------------------------------------------
-- CobysCrestExchange Settings Window
--
-- The suite's standard settings window (CobySuite.UI.CreateSettingsWindow):
-- two sidebar categories, Exchange (Show at Vaskarn, Use my Interact key)
-- and Window (Position, Reset position), staged edits that Apply writes
-- through Config.Set, Cancel, Defaults, and a Guide footer button. Built at load, so opening it
-- never creates frames in combat; the controls are painted from config on
-- every show, and a ConfigChanged event repaints an open window. The addon
-- is also listed under Options > AddOns with a button that opens this window
-- (CobySuite.UI.RegisterSettingsCategory).
-------------------------------------------------------------------------------

local Config = CobysCrestExchange.Config
local Opt = Config.Options
local U = CobySuite_CobysCrestExchange.Utilities
local UI = CobySuite_CobysCrestExchange.UI

local WINDOW_W = 560
local WINDOW_H = 360

local window = UI.CreateSettingsWindow({
  name    = "CobysCrestExchangeOptionsWindow",
  title   = U.WrapColor(CobysCrestExchange.BRAND_COLOR, "Coby's Crest Exchange") .. " Settings",
  icon    = CobysCrestExchange.ICON,
  config  = Config,
  width   = WINDOW_W,
  height  = WINDOW_H,
  persist = {
    svTable = function() return COBYS_CREST_EXCHANGE_WINDOW_STATE end,
    key = "options",
  },
  watch   = { bus = CobysCrestExchange.EventBus, event = CobysCrestExchange.Events.ConfigChanged },
  message = function(text) CobysCrestExchange.Utilities.Message(text) end,
  footerButtons = {
    {
      text = "Guide", width = 80,
      tooltip = "Open the feature guide: how the exchange works, step by step.",
      onClick = function()
        local Views = CobysCrestExchange.Views
        if Views and Views.Guide then Views.Guide.Toggle() end
      end,
    },
  },
  -- Two categories, so the window shows its left navigation bar like every
  -- suite addon's settings (the suite's standard setup)
  categories = {
    {
      key = "exchange", label = "Exchange",
      build = function(panel)
        panel:Section("At Vaskarn")
        panel:Checkbox{
          key = Opt.SHOW_PANEL_AT_VENDOR, label = "Show at Vaskarn",
          tooltip = "Open the exchange window when you talk to Vaskarn. Off: open it yourself with /ce.",
        }
        panel:Checkbox{
          key = Opt.USE_INTERACT_KEY, label = "Use my Interact key",
          tooltip = "While an exchange runs, your Interact key (the Interact with target key binding) presses the exchange button: buy, close the vendor, open each pack. When a plan needs Vaskarn again, the same key talks to him, and the game's Enable Interact Key setting is switched on until then if it was off. Never in combat.",
        }
        panel:Description("Reserves (\"Keep at least\") are set in the exchange window, beside each trade and under Before you spend.")
      end,
    },
    {
      key = "window", label = "Window",
      build = function(panel)
        panel:Section("Where the window sits")
        panel:Dropdown{
          key = Opt.WINDOW_POSITION, label = "Position", inline = true, width = 180,
          tooltip = "Where the exchange window (or its collapsed tab) sits while Vaskarn's list is open: right of it by default, or left. Automatic uses whichever side fits. Where I put it keeps the spot you drag it to.",
          labels = { "Right of the vendor", "Left of the vendor", "Automatic", "Where I put it" },
          values = { "right", "left", "auto", "floating" },
        }
        panel:Button{
          text = "Reset position", width = 160,
          tooltip = "Forget where you dragged the exchange window. At Vaskarn it docks beside his list anyway, unless Position is Where I put it.",
          onClick = function()
            local Views = CobysCrestExchange.Views
            if Views and Views.Dock then Views.Dock.ResetPosition() end
          end,
        }
      end,
    },
  },
})

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------
function Config.ToggleSettings()
  window:Toggle()
end

function Config.OpenSettings()
  window:Open()
end

-------------------------------------------------------------------------------
-- Options > AddOns entry (registered once this addon has finished loading)
-------------------------------------------------------------------------------
EventUtil.ContinueOnAddOnLoaded("CobysCrestExchange", function()
  UI.RegisterSettingsCategory({
    name        = "Coby's Crest Exchange",
    brandColor  = CobysCrestExchange.BRAND_COLOR,
    version     = CobysCrestExchange.VERSION,
    description = {
      "A better crest exchange at Vaskarn: see what you can convert, pick an amount, and convert in a few clicks.",
      "The settings live in the addon's own settings window.",
    },
    slash       = "/ce settings",
    onOpen      = Config.OpenSettings,
  })
end)
