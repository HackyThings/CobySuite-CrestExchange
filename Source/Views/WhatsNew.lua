-------------------------------------------------------------------------------
-- Views.WhatsNew: the changelog window and what its login shows, on the
-- shared CobySuite.UI.CreateWhatsNewWindow (the suite's standard setup, as
-- Recollect's): one collapsible section per version of Data/Changelog.lua,
-- /ce changelog any time. At login COBYS_CREST_EXCHANGE_WINDOW_STATE.lastVersion
-- says what the player last ran: none (a fresh install) opens the feature
-- guide, an older version this window with every version since then open,
-- else nothing; either waits for combat to end. Core.lua's PLAYER_LOGIN
-- calls OnLogin, which builds the window out of combat.
-------------------------------------------------------------------------------
local Views = CobysCrestExchange.Views
local U = CobySuite_CobysCrestExchange.Utilities

local WhatsNew = {}
Views.WhatsNew = WhatsNew

local changelog = CobySuite_CobysCrestExchange.UI.CreateWhatsNewWindow({
  name = "CobysCrestExchangeChangelogWindow",
  title = CobySuite_CobysCrestExchange.Utilities.WrapColor(CobysCrestExchange.BRAND_COLOR, "Coby's Crest Exchange") .. ": What's New",
  icon = CobysCrestExchange.ICON,
  intro = "What changed in each version of Coby's Crest Exchange, newest first. Click a version to open or close it.",
  footer = "Open this window any time with " .. U.WrapColor(U.Colors.HELP_COMMAND, "/ce changelog"),
  entries = CobysCrestExchange.Data.Changelog,
  version = CobysCrestExchange.VERSION,
  state = function() return COBYS_CREST_EXCHANGE_WINDOW_STATE end,
  onFirstRun = function() if Views.Guide then Views.Guide.Show() end end,
  combatMessage = function(text) CobysCrestExchange.Utilities.Message(text) end,
  onShow = function(what) CobysCrestExchange.Debug.Log("UI", "Login shows the %s", what) end,
})

function WhatsNew.Toggle() changelog:Toggle() end
function WhatsNew.OnLogin() changelog:OnLogin() end
