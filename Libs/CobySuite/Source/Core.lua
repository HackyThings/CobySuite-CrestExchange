-- CobySuite: Shared library for all CobySuite addons
-- All shared utilities, UI factories, and infrastructure live here.
-- Individual addons (CobySniper, CobysLinkepedia, etc.) depend on this.

CobySuite_CobysCrestExchange = CobySuite_CobysCrestExchange or {}

-- Sub-namespace declarations (populated by individual modules)
CobySuite_CobysCrestExchange.Utilities = CobySuite_CobysCrestExchange.Utilities or {}
CobySuite_CobysCrestExchange.UI        = CobySuite_CobysCrestExchange.UI or {}
CobySuite_CobysCrestExchange.Debug     = CobySuite_CobysCrestExchange.Debug or {}
CobySuite_CobysCrestExchange.Config    = CobySuite_CobysCrestExchange.Config or {}
CobySuite_CobysCrestExchange.EventBus  = CobySuite_CobysCrestExchange.EventBus or {}
CobySuite_CobysCrestExchange.Chat      = CobySuite_CobysCrestExchange.Chat or {}
CobySuite_CobysCrestExchange.Slash     = CobySuite_CobysCrestExchange.Slash or {}
CobySuite_CobysCrestExchange.Tests     = CobySuite_CobysCrestExchange.Tests or {}

CobySuite_CobysCrestExchange.SortDir = { ASC = "asc", DESC = "desc" }

-- Where this copy of the library comes from. The monorepo's CobySuite addon
-- leaves it as is; a standalone build embeds the library under its own name
-- and replaces it from its Build.lua with { embedded = true, host = "<addon>",
-- commit = "<short sha>", dirty = <bool> }.
CobySuite_CobysCrestExchange.BuildInfo = CobySuite_CobysCrestExchange.BuildInfo or { embedded = false }

-- The library version for reports: "embedded in <host> at <commit>" in a
-- standalone build, else the CobySuite addon's TOC version. The addon name
-- below is the only string literal in shipped shared code that is exactly
-- the library's name (the standalone build checks this; Source/Tests/ is
-- stripped).
function CobySuite_CobysCrestExchange.LibraryVersionText()
  local info = CobySuite_CobysCrestExchange.BuildInfo
  if info and info.embedded then
    return ("embedded in %s at %s"):format(tostring(info.host or "?"), tostring(info.commit or "?"))
  end
  return C_AddOns.GetAddOnMetadata("CobySuite", "Version") or "?"
end
