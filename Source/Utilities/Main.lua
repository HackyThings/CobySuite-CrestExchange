local Utilities = CobysCrestExchange.Utilities

---------------------------------------------------------------------------
-- Addon-specific: chat output (branded prefix)
---------------------------------------------------------------------------
Utilities.Message = CobySuite_CobysCrestExchange.Chat.NewMessenger({
  prefix = "[Coby's Crest Exchange]",
  color = CobysCrestExchange.BRAND_COLOR,
})
