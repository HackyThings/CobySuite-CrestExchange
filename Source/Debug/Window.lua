-------------------------------------------------------------------------------
-- CobysCrestExchange Debug Window: thin wrapper around CobySuite.Debug.NewWindow
-------------------------------------------------------------------------------

CobysCrestExchange.DebugWindow = CobySuite_CobysCrestExchange.Debug.NewWindow({
  windowName = "CobysCrestExchangeDebugWindow",
  title = CobySuite_CobysCrestExchange.Utilities.WrapColor(CobysCrestExchange.BRAND_COLOR, "Coby's Crest Exchange") .. " debug log",
  icon = CobysCrestExchange.ICON,
  logger = CobysCrestExchange.Debug,
})
