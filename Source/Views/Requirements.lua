-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Requirements: why a trade is locked or missing
--
-- One trade: the achievement it needs and, since the unlock counts every
-- gear slot rather than average item level, the lowest slot watermarks
-- against the threshold (rings and trinkets are pairs; the game reports one
-- number for each pair); the game's own incomplete criteria; the Practicum
-- quest's progress for trades down; or "not offered" when no reason is
-- established. List mode shows every trade in two groups, trade up and trade
-- down, each a row with both crests' icons, an arrow, and its state.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Window = Views.Window
local Requirements = {}
Views.Requirements = Requirements
local T = Views.Text
local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local Seasons = CobysCrestExchange.Seasons
local Eligibility = CobysCrestExchange.Eligibility

local MAX_LINES = 22
local SLOT_ROWS = 7   -- the slot table shows seven, lowest first; the rest scroll
local SLOT_ROW_H = 18
local TABLE_MARK = "\0slots"   -- where the slot table goes among the reason lines

-- Each watermark slot's own paper doll icon (C_PaperDollInfo.GetInventorySlotInfo)
local SLOT_ICON_NAMES = {
  Head = "HeadSlot", Neck = "NeckSlot", Shoulder = "ShoulderSlot", Cloak = "BackSlot", Chest = "ChestSlot",
  Wrist = "WristSlot", Hand = "HandsSlot", Waist = "WaistSlot", Legs = "LegsSlot", Feet = "FeetSlot",
  Finger = "Finger0Slot", Trinket = "Trinket0Slot", Weapons = "MainHandSlot",
}
local slotIcons = {}
local function SlotIcon(slot)
  if slotIcons[slot] == nil then
    local name = SLOT_ICON_NAMES[slot]
    local ok, _, texture = pcall(C_PaperDollInfo.GetInventorySlotInfo, name)
    slotIcons[slot] = name and ok and texture or false
  end
  return slotIcons[slot] or 134400
end
local LIST_ROWS = 8
local ROW_H = 24
local LIST_TOP = -50
local FROM_W = 80     -- the widest tier name ("Adventurer") with room to spare

local function StateLine(result)
  if result.state == "available" then return U.WrapColor(U.Colors.SUCCESS_GREEN, "Open") end
  if result.state == "locked" then
    local r = result.reasons[1]
    if r.kind == "achievement" then return U.WrapColor(U.Colors.WARNING_RED, "Needs " .. tostring(r.name)) end
    if r.kind == "practicum" then return U.WrapColor(U.Colors.WARNING_RED, "Needs Upgrade Practicum") end
    return U.WrapColor(U.Colors.WARNING_RED, "Locked")
  end
  if result.state == "not_offered" then return U.WrapColor(U.Colors.CAUTION_ORANGE, "Not offered right now") end
  if result.state == "unsupported" then return U.WrapColor(U.Colors.CAUTION_ORANGE, "Sold, not supported yet") end
  if result.state == "away" then return U.WrapColor(U.Colors.LABEL_GRAY, "Check at Vaskarn") end
  return "?"
end

local function TradeName(season, product)
  return string.format("%s to %s", T.Tier(season, product.from), T.Tier(season, product.to))
end

-- The state's icon beside its words: a check for open, a lock for locked
local function StateIcon(result)
  if result.state == "available" then return "checkmark-minimal" end
  if result.state == "locked" then return "AdventureMapIcon-Lock" end
  return nil
end

local function AchievementLines(lines, r, out)
  if r.completed and not r.earnedByMe then
    lines[#lines + 1] = string.format("%s is done on another character; this trade needs it on this one.", tostring(r.name))
  else
    lines[#lines + 1] = string.format("Needs the achievement %s on this character.", U.WrapColor(U.Colors.STATUS_GOLD, tostring(r.name)))
  end
  lines[#lines + 1] = string.format("Every gear slot must have reached item level %d at some point. Average item level doesn't count.", r.threshold)
  -- The slots go in the table (lowest first, as Watermarks sorts them), then
  -- the weapons as one last row: the best set reached, as the unlock counts it
  local slots = {}
  for _, row in ipairs(r.watermarks or {}) do
    if not row.weapon then
      slots[#slots + 1] = { slot = row.slot, label = T.Slot(row.slot), yours = row.char, needs = r.threshold, ok = row.ok }
    end
  end
  if r.weaponsOk ~= nil then
    slots[#slots + 1] = { slot = "Weapons", label = "Weapons", yours = r.weapons and r.weapons.char, needs = r.threshold,
      ok = r.weaponsOk }
  end
  if #slots > 0 then
    out.slots = slots
    lines[#lines + 1] = TABLE_MARK
  end
  for _, text in ipairs(r.criteria or {}) do
    lines[#lines + 1] = "  - " .. text
  end
end

-- The reason's lines, and out.slots for the slot table (TABLE_MARK marks its place)
local function ReasonLines(result, out)
  local lines = {}
  if result.state == "available" then
    lines[#lines + 1] = "This trade is open."
    return lines
  end
  for _, r in ipairs(result.reasons) do
    if r.kind == "achievement" then
      AchievementLines(lines, r, out)
    elseif r.kind == "practicum" then
      if r.have and r.need then
        lines[#lines + 1] = string.format("Trading down needs Vaskarn's quest Upgrade Practicum. Progress: %d / %d.", r.have, r.need)
        lines[#lines + 1] = "If the count stopped moving, logging out and back in has helped some players."
      elseif r.inLog then
        lines[#lines + 1] = "Trading down needs Vaskarn's quest Upgrade Practicum, which is in your quest log."
      else
        lines[#lines + 1] = "Trading down needs Vaskarn's quest Upgrade Practicum. Pick it up from him."
      end
    elseif r.kind == "filter" then
      lines[#lines + 1] = "His merchant list is filtered; set the filter to All to see every trade."
    elseif r.kind == "unknown_item" and r.sold then
      lines[#lines + 1] = "Vaskarn sells this trade, but this version doesn't know its pack yet, so it can't buy it for you. Buy it from his list for now; a /ce dump here includes it in a report so it can be added."
    elseif r.kind == "unknown_item" then
      lines[#lines + 1] = "This version doesn't know this trade's pack yet. Type /ce dump at Vaskarn to include it in a report."
    elseif r.kind == "unknown_achievement" then
      lines[#lines + 1] = "The game didn't report the unlock achievement."
    end
  end
  if result.state == "not_offered" and #lines == 0 then
    lines[#lines + 1] = "The known requirements look complete, but Vaskarn isn't offering this trade right now. Reopen his window, or check his merchant filter."
  elseif result.state == "away" then
    lines[#lines + 1] = "Whether he offers it shows when you talk to Vaskarn."
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Unlocks are earned per character, so only this character's item levels count."
  return lines
end

local function Build(host)
  local page = {}
  page.Title = host:CreateFontString(nil, "OVERLAY", U.Fonts.HEADING)
  page.Title:SetPoint("TOPLEFT", 4, -4)
  page.Status = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Status:SetPoint("TOPLEFT", 4, -26)
  page.Body = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.Body:SetPoint("TOPLEFT", 6, -50)
  page.Body:SetPoint("TOPRIGHT", -6, -50)
  page.Body:SetJustifyH("LEFT")
  page.Body:SetSpacing(2)
  -- Each slot's highest item level against the unlock's, on the shared table
  local green, red = U.Colors.SUCCESS_GREEN, U.Colors.WARNING_RED
  local function Level(n) return n and T.Count(n) or "?" end
  page.Slots = UI.CreateSortTable(host, {
    pool = SLOT_ROWS, rowHeight = SLOT_ROW_H, minStretch = 120,
    columns = {
      { key = "slot", label = "Slot", stretch = true, sortable = false,
        icon = function(row) return SlotIcon(row.slot) end, text = function(row) return row.label end },
      { key = "yours", label = "Yours", width = 64, justify = "RIGHT", sortable = false,
        tooltip = "The highest item level you have ever had in this slot on this character",
        text = function(row) return Level(row.yours) end, color = function(row) return row.ok and green or red end },
      { key = "needs", label = "Needs", width = 64, justify = "RIGHT", sortable = false,
        text = function(row) return Level(row.needs) end },
    },
  })
  page.Slots.frame:Hide()
  page.After = host:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  page.After:SetJustifyH("LEFT")
  page.After:SetSpacing(2)
  page.ListButtons = {}
  page.GroupHeads = {}
  for i = 1, 2 do
    local head = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
    head:SetTextColor(unpack(U.Colors.STATUS_GOLD))
    page.GroupHeads[i] = head
  end
  for i = 1, LIST_ROWS do
    local b = CreateFrame("Button", nil, host)
    b:SetHeight(ROW_H - 2)
    U.AddAlternatingRowBg(b, i)
    UI.AddHoverHighlight(b)
    b.FromIcon = b:CreateTexture(nil, "ARTWORK")
    b.FromIcon:SetSize(18, 18)
    b.FromIcon:SetPoint("LEFT", 6, 0)
    b.From = b:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
    b.From:SetPoint("LEFT", b.FromIcon, "RIGHT", 5, 0)
    -- A fixed column, so the arrow and the second crest line up in every row
    b.From:SetWidth(FROM_W)
    b.From:SetJustifyH("LEFT")
    b.From:SetWordWrap(false)
    b.Arrow = b:CreateTexture(nil, "ARTWORK")
    b.Arrow:SetAtlas("NPE_ArrowUp")
    b.Arrow:SetRotation(-math.pi / 2)
    b.Arrow:SetSize(12, 12)
    b.Arrow:SetPoint("LEFT", b.From, "RIGHT", 4, 0)
    b.ToIcon = b:CreateTexture(nil, "ARTWORK")
    b.ToIcon:SetSize(18, 18)
    b.ToIcon:SetPoint("LEFT", b.Arrow, "RIGHT", 8, 0)
    b.To = b:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
    b.To:SetPoint("LEFT", b.ToIcon, "RIGHT", 5, 0)
    b.StateIcon = b:CreateTexture(nil, "OVERLAY")
    b.StateIcon:SetSize(14, 14)
    b.StateIcon:SetPoint("RIGHT", -6, 0)
    b.Right = b:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
    b.Right:SetPoint("RIGHT", b.StateIcon, "LEFT", -5, 0)
    b:SetScript("OnClick", function(self)
      if self.key then Window.Go("requirements", { reqKey = self.key, from = "list" }) end
    end)
    page.ListButtons[i] = b
  end
  page.ListNote = host:CreateFontString(nil, "OVERLAY", U.Fonts.SMALL)
  page.ListNote:SetJustifyH("LEFT")
  page.ListNote:SetSpacing(2)
  page.ListNote:SetTextColor(U.Colors.LABEL_GRAY[1], U.Colors.LABEL_GRAY[2], U.Colors.LABEL_GRAY[3])
  page.Back = UI.CreateButton(host, { text = "Back", size = { 90, 22 }, point = { "BOTTOMLEFT", host, "BOTTOMLEFT", 0, 4 },
    onClick = function()
      local nav = Window.nav
      if nav.reqKey and nav.from == "list" then return Window.Go("requirements", nil, { "reqKey", "from" }) end
      if nav.reqKey and nav.from == "source" then return Window.Go("source") end
      if nav.reqKey and nav.from == "overview" then return Window.Go("overview", nil, { "reqKey", "from" }) end
      Window.Go("overview")
    end })
  page.Copy = UI.CreateButton(host, { text = "Copy details", size = { 120, 22 },
    point = { "BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 4 }, onClick = function() CobysCrestExchange.Capture.Show() end })
  return page
end

local page = Window.AddPage("requirements", Build)
function page:Refresh(ctx)
  local season = ctx.season
  if not season then return end
  local key = ctx.nav.reqKey
  if not key then return self:RefreshList(ctx) end
  for _, b in ipairs(self.ListButtons) do b:Hide() end
  for _, head in ipairs(self.GroupHeads) do head:Hide() end
  self.ListNote:Hide()
  local product = Seasons.ProductByKey(season, key)
  if not product then return Window.Go("requirements", nil, { "reqKey", "from" }) end
  local result = Eligibility.ForTrade(season, product, ctx.obs)
  self.Title:SetText(TradeName(season, product))
  self.Status:SetText(StateLine(result))
  local out = {}
  local lines = ReasonLines(result, out)
  while #lines > MAX_LINES do table.remove(lines) end
  -- The lines before the slot table in Body, the rest under it in After
  local before, after, mark = {}, {}, false
  for _, line in ipairs(lines) do
    if line == TABLE_MARK then mark = true
    elseif mark then
      if #after > 0 or line ~= "" then after[#after + 1] = line end   -- the table's own gap replaces a blank line
    else before[#before + 1] = line end
  end
  self.Body:SetText(table.concat(before, "\n"))
  local shown = mark and out.slots ~= nil
  self.Slots.frame:SetShown(shown)
  local above = self.Body
  if shown then
    self.Slots.frame:ClearAllPoints()
    self.Slots.frame:SetPoint("TOPLEFT", self.Body, "BOTTOMLEFT", -2, -8)
    self.Slots.frame:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
    -- As tall as its rows, up to SLOT_ROWS (the header is 20 and a gap of 2;
    -- 2 more so pixel rounding never drops the last row: run 2 showed 6 of 7)
    self.Slots.frame:SetHeight(24 + math.min(#out.slots, SLOT_ROWS) * SLOT_ROW_H)
    self.Slots:SetRows(out.slots)
    above = self.Slots.frame
  end
  self.After:ClearAllPoints()
  self.After:SetPoint("TOPLEFT", above, "BOTTOMLEFT", shown and 2 or 0, -8)
  self.After:SetPoint("RIGHT", self.frame, "RIGHT", -6, 0)
  self.After:SetText(table.concat(after, "\n"))
  self.After:Show()
end

-- Every trade, trade up first then trade down, each group under its own heading
local GROUPS = { { kind = "up", title = "Trade up" }, { kind = "down", title = "Trade down" } }

function page:RefreshList(ctx)
  local season = ctx.season
  self.Title:SetText("Trades and what unlocks them")
  self.Status:SetText(U.WrapColor(U.Colors.LABEL_GRAY, "Click a trade to see exactly what it needs."))
  self.Body:SetText("")
  self.Slots.frame:Hide()
  self.After:Hide()
  local all = Eligibility.All(season, ctx.obs)
  local y, used = LIST_TOP, 0
  for g, group in ipairs(GROUPS) do
    local head = self.GroupHeads[g]
    local any = false
    for _, entry in ipairs(all) do if entry.product.kind == group.kind then any = true end end
    head:SetShown(any)
    if any then
      head:ClearAllPoints()
      head:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, y)
      head:SetText(group.title)
      y = y - 16
      for _, entry in ipairs(all) do
        if entry.product.kind == group.kind and used < LIST_ROWS then
          used = used + 1
          local b, product = self.ListButtons[used], entry.product
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y)
          b:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, y)
          b.key = product.key
          local from, to = ctx.obs.tiers[product.from], ctx.obs.tiers[product.to]
          b.FromIcon:SetTexture(from and from.currency.icon or 134400)
          b.ToIcon:SetTexture(to and to.currency.icon or 134400)
          b.From:SetText(T.Tier(season, product.from))
          b.To:SetText(T.Tier(season, product.to))
          b.Right:SetText(StateLine(entry.result))
          local atlas = StateIcon(entry.result)
          b.StateIcon:SetShown(atlas ~= nil)
          if atlas then b.StateIcon:SetAtlas(atlas) end
          b:Show()
          y = y - ROW_H
        end
      end
      y = y - 8
    end
  end
  for i = used + 1, LIST_ROWS do self.ListButtons[i]:Hide() end
  self.ListNote:ClearAllPoints()
  self.ListNote:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6, y - 4)
  self.ListNote:SetPoint("RIGHT", self.frame, "RIGHT", -6, 0)
  self.ListNote:SetText("Trading up needs the achievement of the tier you spend, earned on this character. "
    .. "Trading down needs Vaskarn's quest Upgrade Practicum.")
  self.ListNote:Show()
end

-------------------------------------------------------------------------------
-- For other pages: a locked trade's reason in a few words, and a tooltip
-- with what exactly is missing (the overview's ladder links use both)
-------------------------------------------------------------------------------
local TIP_SLOTS = 4
local RED, WHITE, GRAY = U.Colors.WARNING_RED, U.Colors.HIGHLIGHT_WHITE, { 0.6, 0.6, 0.6 }

local function Line(tip, text, c) tip:AddLine(text, c[1], c[2], c[3], true) end

function Requirements.ShortReason(result)
  local r = result.reasons and result.reasons[1]
  if r and r.kind == "achievement" then return "needs " .. tostring(r.name) end
  if r and r.kind == "practicum" then return "needs Upgrade Practicum" end
  return "locked"
end

local function AchievementTip(tip, r)
  if r.completed and not r.earnedByMe then
    Line(tip, string.format("%s is done on another character, but this trade needs it on this one.", tostring(r.name)), RED)
  else
    Line(tip, string.format("Needs the achievement %s on this character.", tostring(r.name)), RED)
  end
  Line(tip, string.format("Every gear slot must have reached item level %d at some point; average item level doesn't count.", r.threshold), WHITE)
  -- The slots holding it back, lowest first
  local low = {}
  for _, row in ipairs(r.watermarks or {}) do
    if not row.weapon and row.ok == false then low[#low + 1] = row end
  end
  table.sort(low, function(a, b) return (a.char or 0) < (b.char or 0) end)
  if #low > 0 then tip:AddLine(" ") end
  for i = 1, math.min(TIP_SLOTS, #low) do
    local row = low[i]
    tip:AddDoubleLine(T.Slot(row.slot), string.format("%s of %d", row.char and tostring(row.char) or "?", r.threshold),
      0.8, 0.8, 0.8, RED[1], RED[2], RED[3])
  end
  if #low > TIP_SLOTS then Line(tip, string.format("and %d more %s below it", #low - TIP_SLOTS, T.Plural(#low - TIP_SLOTS, "slot", "slots")), RED) end
  if r.weaponsOk == false then
    tip:AddDoubleLine("Weapons", "below " .. r.threshold, 0.8, 0.8, 0.8, RED[1], RED[2], RED[3])
  end
end

function Requirements.AddTooltip(tip, season, product, result)
  tip:AddLine(TradeName(season, product) .. ": locked")
  for _, r in ipairs(result.reasons or {}) do
    if r.kind == "achievement" then
      AchievementTip(tip, r)
    elseif r.kind == "practicum" then
      if r.have and r.need then
        Line(tip, string.format("Needs Vaskarn's quest Upgrade Practicum: %d of %d done.", r.have, r.need), RED)
      else
        Line(tip, "Needs Vaskarn's quest Upgrade Practicum.", RED)
      end
    end
  end
  tip:AddLine(" ")
  Line(tip, "Click for everything this trade needs.", GRAY)
end
