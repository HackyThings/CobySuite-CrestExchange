-------------------------------------------------------------------------------
-- CobysCrestExchange Views.BeforeYouSpend: facts to check, nothing assumed
--
-- Two sections, each with a header:
--   Your upgrade tracks   one bar per track: how far your equipped items on
--                         it are upgraded, and how many ranks are left. Ranks
--                         are not a crest cost (discounts and watermarks
--                         change what a rank costs), and nothing here labels
--                         crests as spare.
--   Keep at least         a reserve per tier, with its crest icon, which Max
--                         and every exchange from that tier respect: one
--                         row of five columns, held just above Back so the
--                         docked panel never needs to scroll
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = Views.Window
local T = Views.Text
local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local Gear = CobysCrestExchange.Gear
local Store = CobysCrestExchange.Store
local E = CobysCrestExchange.Events

local MAX_TRACKS = 5
local ROW_H = 20

-- A section header: icon, title and a rule to the right edge, in a
-- full-width row the caller places by both top (or bottom) corners, so the
-- rule's two ends sit at the same height (Task #236)
local function Header(host, atlas, text)
  local row = CreateFrame("Frame", nil, host)
  row:SetHeight(16)
  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetAtlas(atlas)
  icon:SetSize(16, 16)
  icon:SetPoint("LEFT", 0, 0)
  local title = row:CreateFontString(nil, "OVERLAY", U.Fonts.HEADING)
  title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  title:SetText(text)
  local line = row:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  local gold = U.Colors.STATUS_GOLD
  line:SetColorTexture(gold[1], gold[2], gold[3], 0.35)
  line:SetPoint("LEFT", title, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", row, "RIGHT", -4, 0)
  return row
end

local function BuildTracks(host, page)
  page.TracksHead = Header(host, "common-icon-forwardarrow", "Your upgrade tracks")
  page.TracksHead:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -4)
  page.TracksHead:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -4)
  page.bars = {}
  for i = 1, MAX_TRACKS do
    local bar = CreateFrame("StatusBar", nil, host)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.35, 0.55, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetHeight(ROW_H - 4)
    bar:SetPoint("TOPLEFT", page.TracksHead, "BOTTOMLEFT", 2, -6 - (i - 1) * ROW_H)
    bar:SetPoint("RIGHT", host, "RIGHT", -6, 0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.5)
    bar.Text = bar:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
    bar.Text:SetPoint("LEFT", 6, 0)
    bar.Right = bar:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
    bar.Right:SetPoint("RIGHT", -6, 0)
    page.bars[i] = bar
  end
  page.TrackNote = host:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  page.TrackNote:SetPoint("TOPLEFT", page.TracksHead, "BOTTOMLEFT", 2, -6 - MAX_TRACKS * ROW_H)
  page.TrackNote:SetPoint("RIGHT", host, "RIGHT", -6, 0)
  page.TrackNote:SetJustifyH("LEFT")
  page.TrackNote:SetTextColor(0.65, 0.65, 0.65)
end

local KEEP_COL = 74   -- one tier's column: its name over its icon and box

local function BuildReserves(host, page)
  -- Held above Back: header, then a name row, then the icon and box row
  local row = CreateFrame("Frame", nil, host)
  row:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 2, 34)
  row:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 34)
  row:SetHeight(38)
  page.KeepRow = row
  -- What the boxes do and how they save, over them (Task #236)
  page.KeepNote = host:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  page.KeepNote:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 2, 6)
  page.KeepNote:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", -4, 6)
  page.KeepNote:SetJustifyH("LEFT")
  page.KeepNote:SetTextColor(0.65, 0.65, 0.65)
  page.KeepNote:SetText("Max and exchanges keep at least these. Leaving a box saves it.")
  page.KeepHead = Header(host, "common-icon-checkmark", "Keep at least")
  page.KeepHead:SetPoint("BOTTOMLEFT", page.KeepNote, "TOPLEFT", 0, 6)
  page.KeepHead:SetPoint("BOTTOMRIGHT", page.KeepNote, "TOPRIGHT", 4, 6)
  page.reserves = {}
  for i = 1, 5 do
    local label = row:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
    label:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * KEEP_COL, 0)
    label:SetWidth(KEEP_COL - 4)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    local input = UI.CreateNumberInput(row, { width = 44, maxLetters = 5,
      point = { "LEFT", icon, "RIGHT", 4, 0 },
      parse = function(text) if text == "" then return 0 end local n = tonumber(text); return n and n == math.floor(n) and n or nil end,
      validate = function(n) return n >= 0 and n <= 100000 end,
      onCommit = function(n, box)
        if box.currencyID then
          Store.SetReserve(box.currencyID, n)
          CobysCrestExchange.EventBus:Fire(E.PreferenceChanged, "reserve", box.currencyID, n)
        end
      end })
    input:SetNumeric(true)   -- digits only
    page.reserves[i] = { icon = icon, label = label, input = input }
  end
end

local function Build(host)
  local page = {}
  BuildTracks(host, page)
  BuildReserves(host, page)
  page.Back = UI.CreateButton(host, { text = "Back", size = { 90, 22 }, point = { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 },
    onClick = function() Window.Go("overview") end })
  return page
end

-- The tracks in ladder order (the game lists them in its own order); a track
-- the season doesn't name goes last
local function LadderOrder(season, order)
  local rank = {}
  for i, tier in ipairs(season and season.tiers or {}) do rank[tier.label] = i end
  local sorted = {}
  for i, name in ipairs(order) do sorted[i] = name end
  table.sort(sorted, function(a, b)
    local ra, rb = rank[a] or 99, rank[b] or 99
    if ra ~= rb then return ra < rb end
    return a < b
  end)
  return sorted
end

local function RefreshTracks(page, season)
  local tracks, order, unknown = Gear.Tracks()
  order = LadderOrder(season, order)
  local last = 0
  for i, bar in ipairs(page.bars) do
    local name = order[i]
    local t = name and tracks[name]
    bar:SetShown(t ~= nil)
    if t then
      last = i
      bar:SetValue(t.maxLevels > 0 and t.levels / t.maxLevels or 0)
      bar:SetStatusBarColor(t.ranksLeft == 0 and 0.25 or 0.35, t.ranksLeft == 0 and 0.75 or 0.55, t.ranksLeft == 0 and 0.3 or 1)
      bar.Text:SetText(string.format("%s: %s %s", name, T.Count(t.items), T.Plural(t.items, "item", "items")))
      bar.Right:SetText(t.ranksLeft == 0 and "all maxed" or (T.Count(t.ranksLeft) .. " " .. T.Plural(t.ranksLeft, "rank", "ranks") .. " left"))
    end
  end
  local notes = {}
  if #order == 0 then notes[#notes + 1] = "No upgrade tracks found on your equipped items." end
  if unknown > 0 then
    notes[#notes + 1] = string.format("%d equipped %s no readable upgrade track.", unknown, T.Plural(unknown, "item has", "items have"))
  end
  notes[#notes + 1] = "Ranks left are not a crest cost: discounts and your highest item levels change what a rank costs."
  page.TrackNote:SetText(table.concat(notes, " "))
  -- Right under the last bar: fewer tracks (or none) leave no empty rows above it
  page.TrackNote:SetPoint("TOPLEFT", page.TracksHead, "BOTTOMLEFT", 2, -6 - last * ROW_H)
end

local page = Window.AddPage("before", Build)
function page:Refresh(ctx)
  RefreshTracks(self, ctx.season)
  for i, entry in ipairs(self.reserves) do
    local tier = ctx.season and ctx.season.tiers[i]
    for _, region in ipairs({ entry.icon, entry.label, entry.input }) do region:SetShown(tier ~= nil) end
    if tier then
      local t = ctx.obs.tiers[tier.key]
      entry.icon:SetTexture(t and t.currency.icon or 134400)
      entry.label:SetText(T.Tier(ctx.season, tier.key))
      entry.input.currencyID = tier.currencyID
      if not entry.input:HasFocus() then entry.input:SetCommittedValue(Store.GetReserve(tier.currencyID)) end
    end
  end
end
