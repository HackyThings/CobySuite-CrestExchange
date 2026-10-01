-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Launcher: the addon compartment entry
--
-- CobySuite.UI.CreateLauncher with no minimap button or broker: the
-- compartment menu (the TOC's AddonCompartmentFunc lines) opens or closes the
-- exchange window on a left click and the settings on a right click. Its tooltip
-- mentions an unfinished exchange.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Launcher = {}
Views.Launcher = Launcher

local function TooltipOpts()
  local body = { "A better crest exchange at Vaskarn: see what you can convert, pick an amount, and convert in a few clicks." }
  local Store = CobysCrestExchange.Store
  local order = Store and Store.GetOrder()
  if order then body[#body + 1] = "You have an unfinished exchange." end
  return {
    brandColor = CobysCrestExchange.BRAND_COLOR,
    title = "Coby's Crest Exchange",
    subtitle = "v" .. CobysCrestExchange.VERSION,
    body = body,
    keys = {
      { key = "Click", desc = "Exchange window" },
      { key = "Right-click", desc = "Settings" },
      { key = "/ce help", desc = "Command list" },
    },
  }
end

local launcher = CobySuite_CobysCrestExchange.UI.CreateLauncher({
  name = "CobysCrestExchange",
  minimapButton = false,
  broker = false,
  onLeftClick = function() Views.Window.Toggle() end,
  onRightClick = function() CobysCrestExchange.Config.ToggleSettings() end,
  compartmentTooltipAnchor = "ANCHOR_LEFT",
  tooltip = TooltipOpts,
})
Launcher.launcher = launcher

function CobysCrestExchange_OnAddonCompartmentClick(_, button)
  launcher:OnCompartmentClick(button)
end

function CobysCrestExchange_OnAddonCompartmentEnter(_, menuItem)
  launcher:OnCompartmentEnter(menuItem)
end

function CobysCrestExchange_OnAddonCompartmentLeave()
  launcher:OnCompartmentLeave()
end
