-------------------------------------------------------------------------------
-- CobysCrestExchange Debug Logger: thin wrapper around CobySuite.Debug.NewLogger
-------------------------------------------------------------------------------

CobysCrestExchange.Debug = CobySuite_CobysCrestExchange.Debug.NewLogger({
  addonName = "CobysCrestExchange",
  categories = {
    "INIT", "CONFIG", "DIAG", "MERCHANT", "SESSION", "STORE", "UI",
  },
  savedVariable = "COBYS_CREST_EXCHANGE_DEBUG_LOG",
  sessionHeader = function(lines)
    CobySuite_CobysCrestExchange.Debug.AppendConfigSnapshot(lines, "COBYS_CREST_EXCHANGE_CONFIG")
  end,
})
