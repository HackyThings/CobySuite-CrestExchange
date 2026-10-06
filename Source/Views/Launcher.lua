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

-- The suite's one tooltip shape (CobySuite.UI.LauncherTooltip), with a line
-- for an unfinished exchange
local function TooltipOpts()
  local Store = CobysCrestExchange.Store
  local order = Store and Store.GetOrder()
  return CobySuite_CobysCrestExchange.UI.LauncherTooltip({
    title = "Coby's Crest Exchange", brandColor = CobysCrestExchange.BRAND_COLOR, icon = CobysCrestExchange.ICON,
    status = order and "You have an unfinished exchange." or nil,
    leftClick = "Open the exchange window", rightClick = "Open settings",
  })
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

function CobysCrestExchange_OnAddonCompartmentClick(_, button)
  launcher:OnCompartmentClick(button)
end

function CobysCrestExchange_OnAddonCompartmentEnter(_, menuItem)
  launcher:OnCompartmentEnter(menuItem)
end

function CobysCrestExchange_OnAddonCompartmentLeave()
  launcher:OnCompartmentLeave()
end
