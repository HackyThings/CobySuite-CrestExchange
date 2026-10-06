-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Ladder: the crest ladder, drawn as a graph
--
-- Five tiles stacked like the ladder itself (Myth on top), each with its
-- crest's icon, name, a big number and a small line under it, joined by the
-- trades between them. A link can show what a trade does ("6 packs: 180
-- Champion to 60 Hero") and its state: idle, locked, pending, current (dots
-- flow up along it), or done (a check). A tile can glow (the tier you're
-- after) and carry a small "Spend" checkbox (a plan's source tiers).
--
-- The widget only draws: callers build the model (Ladder.Render) from their
-- page's data. Everything is created when the ladder is made (at load), and
-- animations only play or stop later, so nothing is built in combat.
--
--   local ladder = Ladder.Create(parent, { top = -40, nodeH = 40, gap = 26,
--     onClick = function(tierKey) end, onSpend = function(tierKey, on) end })
--   ladder:Render({
--     season = season,
--     nodes = { [tierKey] = { value = "120", valueColor = {r,g,b}, sub = "Room 45", icon = fileID,
--                             glow = bool, dim = bool, spend = nil|true|false,
--                             meter = nil|{ frac, packed, full, used, limit, label } (a cap meter behind
--                             the text; a full one also gets a still check and MAX in the status column,
--                             Task #269) } },
--     links = { [upperTierKey] = { state = "idle"|"locked"|"pending"|"current"|"done", label = "...",
--                                  down = true for a trade down (the arrow and dots point down),
--                                  tooltip = function(tip), onClick = function() } },
--   })
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Ladder = {}
Views.Ladder = Ladder

local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities
local GOLD = U.Colors.STATUS_GOLD
local WHITE = U.Colors.HIGHLIGHT_WHITE

local FALLBACK_ICON = 134400   -- the question-mark icon
local DOTS = 3
local FLOW_TIME = 1.1

local function Hex(season, tierKey) return Views.Text.TierColor(season, tierKey) end

local RGB = CobySuite_CobysCrestExchange.Utilities.HexToRGB

-------------------------------------------------------------------------------
-- Building
-------------------------------------------------------------------------------
local METER_INSET = 3   -- inside the CONTENT backdrop's edge
-- The cap meter's fills (Task #269): a part-filled bar, the unopened packs' band
-- after it, and a full cap's whole bar
local METER_ALPHA, PACKS_ALPHA, FULL_ALPHA = 0.16, 0.08, 0.22
-- A tall tile's columns, from its right edge: the count and its "Held" caption,
-- then the status (check and MAX) in a region reserved on every tile so it never
-- moves with the count's width
local NAME_X, NAME_TOP, DETAIL_TOP, STATUS_FROM_RIGHT = 44, -6, -23, -80
local COUNT_W, STATUS_W = 64, 48
local TALL_NAME_RIGHT, TALL_DETAIL_RIGHT = -136, -84
local SAGE = U.Colors.SAGE_GREEN
local SHADOW = { 0, 0, 0, 0.85 }

-- The meter's widths from the tile's width now (the floating window resizes);
-- a width of 0 can't be set, so an empty part hides. A full cap fills the whole
-- bar and has no packs band
local function SizeMeter(node)
  local m = node.meter
  local width = (node:GetWidth() or 0) - 2 * METER_INSET
  if not m or width <= 0 then
    node.Meter:Hide()
    node.MeterPacks:Hide()
    return
  end
  local fill, packs = width * (m.full and 1 or m.frac), m.full and 0 or width * m.packed
  node.Meter:SetWidth(math.max(0.01, fill))
  node.Meter:SetShown(fill >= 1)
  node.MeterPacks:SetWidth(math.max(0.01, packs))
  node.MeterPacks:SetShown(packs >= 1)
end

local function Shadowed(text)
  text:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], SHADOW[4])
  text:SetShadowOffset(1, -1)
end

-- One line, never wrapped or shrunk; the tooltip holds the full figures
local function OneLine(text, justify)
  text:SetJustifyH(justify)
  text:SetWordWrap(false)
end

-- A tall tile's layout (the overview, 40 high): name over the detail line on the
-- left, the held count over its caption on the right, and the status region
-- between them
local function BuildTallLayout(node)
  node.Name:SetPoint("TOPLEFT", node, "TOPLEFT", NAME_X, NAME_TOP)
  node.Name:SetPoint("TOPRIGHT", node, "TOPRIGHT", TALL_NAME_RIGHT, NAME_TOP)
  node.Name:SetHeight(14)
  node.Sub:SetPoint("TOPLEFT", node, "TOPLEFT", NAME_X, DETAIL_TOP)
  node.Sub:SetPoint("TOPRIGHT", node, "TOPRIGHT", TALL_DETAIL_RIGHT, DETAIL_TOP)
  node.Sub:SetHeight(12)
  node.Value:SetPoint("TOPRIGHT", node, "TOPRIGHT", -10, -4)
  node.Value:SetSize(COUNT_W, 18)
  node.Held = node:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  node.Held:SetPoint("TOPRIGHT", node, "TOPRIGHT", -10, DETAIL_TOP)
  node.Held:SetSize(COUNT_W, 12)
  node.Held:SetText(Views.Text.HELD_CAPTION)
  node.Held:SetTextColor(U.Colors.LABEL_GRAY[1], U.Colors.LABEL_GRAY[2], U.Colors.LABEL_GRAY[3])
  node.Status = CreateFrame("Frame", nil, node)
  node.Status:SetSize(STATUS_W, 14)
  node.Status:SetPoint("RIGHT", node, "RIGHT", STATUS_FROM_RIGHT, 0)
  node.Check = node:CreateTexture(nil, "ARTWORK")
  node.Check:SetAtlas("checkmark-minimal", false)
  node.Check:SetSize(14, 14)
  node.Check:SetPoint("LEFT", node.Status, "LEFT", 0, 0)
  node.Check:SetDesaturated(true)
  node.Check:SetVertexColor(SAGE[1], SAGE[2], SAGE[3], 1)
  node.Check:Hide()
  node.MaxText = node:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  -- Height only: a fixed width cut the word to "M..." in game (Task #269); with
  -- one anchor the string sizes to its text, which fits the status region
  node.MaxText:SetHeight(14)
  node.MaxText:SetPoint("LEFT", node.Check, "RIGHT", 4, 0)
  node.MaxText:SetJustifyV("MIDDLE")
  node.MaxText:SetText(Views.Text.MAX_BADGE)
  node.MaxText:SetTextColor(SAGE[1], SAGE[2], SAGE[3], 1)
  node.MaxText:Hide()
  for _, text in ipairs({ node.Name, node.Sub, node.Value, node.Held, node.MaxText }) do Shadowed(text) end
  OneLine(node.Name, "LEFT")
  OneLine(node.Sub, "LEFT")
  OneLine(node.Value, "RIGHT")
  OneLine(node.Held, "RIGHT")
  OneLine(node.MaxText, "LEFT")
end

local function BuildNode(ladder, parent, opts)
  local node = CreateFrame("Button", nil, parent, "BackdropTemplate")
  node:SetHeight(opts.nodeH)
  node:SetBackdrop(U.Backdrops.CONTENT)
  node.tall = opts.nodeH >= 34
  local bg = node.tall and U.Colors.WINDOW_BG or { 0.06, 0.06, 0.08, 0.95 }
  node.border = node.tall and U.Colors.CONTENT_BORDER or { 0.4, 0.4, 0.4, 0.9 }
  node:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
  node.Icon = node:CreateTexture(nil, "ARTWORK")
  node.Icon:SetSize(opts.nodeH - 10, opts.nodeH - 10)
  node.Icon:SetPoint("LEFT", 6, 0)
  node.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  node.Name = node:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  node.Sub = node:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  node.Value = node:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  local lg = node.tall and U.Colors.LIGHT_GRAY or { 0.75, 0.75, 0.75 }
  node.Sub:SetTextColor(lg[1], lg[2], lg[3])
  if node.tall then
    BuildTallLayout(node)
  else
    -- A compact tile: the name and the line under it share one line
    node.Name:SetPoint("LEFT", node.Icon, "RIGHT", 8, 0)
    node.Sub:SetPoint("LEFT", node.Name, "RIGHT", 10, 0)
    node.Value:SetPoint("RIGHT", -10, 0)
    node.Value:SetJustifyH("RIGHT")
  end
  -- A cap meter behind the tile's text (the overview, Task #247): the cap
  -- used in the tier's color, then a fainter band for unopened crests
  node.Meter = node:CreateTexture(nil, "BACKGROUND", nil, 2)
  node.Meter:SetPoint("TOPLEFT", METER_INSET, -METER_INSET)
  node.Meter:SetPoint("BOTTOMLEFT", METER_INSET, METER_INSET)
  node.Meter:Hide()
  node.MeterPacks = node:CreateTexture(nil, "BACKGROUND", nil, 2)
  node.MeterPacks:SetPoint("TOPLEFT", node.Meter, "TOPRIGHT", 0, 0)
  node.MeterPacks:SetPoint("BOTTOMLEFT", node.Meter, "BOTTOMRIGHT", 0, 0)
  node.MeterPacks:Hide()
  node:HookScript("OnSizeChanged", function(self) SizeMeter(self) end)
  -- A soft pulse behind the tile for the tier you're after
  node.Glow = node:CreateTexture(nil, "BACKGROUND", nil, 1)
  node.Glow:SetPoint("TOPLEFT", 3, -3)
  node.Glow:SetPoint("BOTTOMRIGHT", -3, 3)
  node.Glow:SetBlendMode("ADD")
  node.Glow:Hide()
  node.GlowAnim = node.Glow:CreateAnimationGroup()
  node.GlowAnim:SetLooping("BOUNCE")
  local pulse = node.GlowAnim:CreateAnimation("Alpha")
  pulse:SetFromAlpha(0.15)
  pulse:SetToAlpha(0.45)
  pulse:SetDuration(0.9)
  UI.AddHoverHighlight(node)
  node:SetScript("OnClick", function(self)
    if ladder.opts.onClick and self.tierKey then ladder.opts.onClick(self.tierKey) end
  end)
  node.Spend = UI.CreateCheckbox(node, { size = 20, label = "Spend", labelSide = "left",
    point = { "RIGHT", node, "RIGHT", -100, 0 },
    tooltip = "Checked: this plan may spend the crests you already have in this tier. Unchecked: crests made here along the way are used, and your balance stays as it is.",
    onChange = function(checked)
      if ladder.opts.onSpend and node.tierKey then ladder.opts.onSpend(node.tierKey, checked) end
    end })
  node.Spend:Hide()
  return node
end

local function BuildDot(link, i, opts)
  local dot = link:CreateTexture(nil, "OVERLAY")
  dot:SetSize(6, 6)
  dot:SetColorTexture(1, 1, 1, 1)
  dot:SetPoint("BOTTOM", link.Line, "BOTTOM", 0, 0)
  dot:SetAlpha(0)
  local group = dot:CreateAnimationGroup()
  group:SetLooping("REPEAT")
  local move = group:CreateAnimation("Translation")
  move:SetOffset(0, opts.gap)
  dot.Move = move
  move:SetDuration(FLOW_TIME)
  move:SetStartDelay((i - 1) * FLOW_TIME / DOTS)
  local fadeIn = group:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0)
  fadeIn:SetToAlpha(1)
  fadeIn:SetDuration(FLOW_TIME * 0.3)
  fadeIn:SetStartDelay((i - 1) * FLOW_TIME / DOTS)
  local fadeOut = group:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(1)
  fadeOut:SetToAlpha(0)
  fadeOut:SetDuration(FLOW_TIME * 0.3)
  fadeOut:SetStartDelay((i - 1) * FLOW_TIME / DOTS + FLOW_TIME * 0.7)
  dot.Anim = group
  return dot
end

local function BuildLink(parent, lower, upper, opts)
  local link = CreateFrame("Frame", nil, parent)
  link:SetPoint("TOPLEFT", upper, "BOTTOMLEFT", 0, 0)
  link:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  link:SetHeight(opts.gap)
  local x = 6 + (opts.nodeH - 10) / 2
  link.Line = link:CreateTexture(nil, "ARTWORK")
  link.Line:SetWidth(2)
  link.Line:SetPoint("TOP", upper, "BOTTOMLEFT", x, 0)
  link.Line:SetPoint("BOTTOM", lower, "TOPLEFT", x, 0)
  link.Arrow = link:CreateTexture(nil, "OVERLAY")
  link.Arrow:SetAtlas("NPE_ArrowUp")
  link.Arrow:SetSize(14, 14)
  link.Arrow:SetPoint("CENTER", link.Line, "CENTER", 0, 0)
  link.Mark = link:CreateTexture(nil, "OVERLAY")
  link.Mark:SetSize(14, 14)
  link.Mark:SetPoint("LEFT", link.Line, "RIGHT", 10, 0)
  link.Label = link:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  link.Label:SetPoint("LEFT", link.Mark, "RIGHT", 4, 0)
  link.Label:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
  link.Label:SetJustifyH("LEFT")
  link.Label:SetWordWrap(false)
  link.Dots = {}
  for i = 1, DOTS do link.Dots[i] = BuildDot(link, i, opts) end
  -- A link a page gives a tooltip (and maybe a click) takes the mouse; others don't
  UI.AddDynamicTooltip(link, function(tip, self) if self.tooltip then self.tooltip(tip) end end, { fillable = true })
  link:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and self.onClick and self:IsMouseOver() then self.onClick() end
  end)
  link:EnableMouse(false)
  return link
end

function Ladder.Create(parent, opts)
  opts = opts or {}
  -- The tiles span the ladder's width
  opts.nodeH, opts.gap, opts.top = opts.nodeH or 40, opts.gap or 26, opts.top or 0
  local ladder = { opts = opts, nodes = {}, links = {} }
  ladder.frame = CreateFrame("Frame", nil, parent)
  ladder.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, opts.top)
  ladder.frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, opts.top)
  ladder.frame:SetHeight(5 * opts.nodeH + 4 * opts.gap)
  -- Myth (5) on top, Adventurer (1) at the bottom
  for i = 5, 1, -1 do
    local node = BuildNode(ladder, ladder.frame, opts)
    node:SetPoint("TOPLEFT", ladder.frame, "TOPLEFT", 0, -(5 - i) * (opts.nodeH + opts.gap))
    node:SetPoint("RIGHT", ladder.frame, "RIGHT", -2, 0)
    ladder.nodes[i] = node
  end
  for i = 2, 5 do ladder.links[i] = BuildLink(ladder.frame, ladder.nodes[i - 1], ladder.nodes[i], opts) end
  return setmetatable(ladder, { __index = Ladder })
end

-------------------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------------------
local function DrawNode(node, season, tier, data)
  node.tierKey = tier.key
  local hex = Hex(season, tier.key)
  local r, g, b = RGB(hex)
  node.Icon:SetTexture(data.icon or FALLBACK_ICON)
  node.Icon:SetDesaturated(data.dim == true)
  local m = data.meter
  node.meter = m
  -- A cap reached is the meter's say (full), never a guess from the bar
  local capped = m ~= nil and m.full == true
  node.Name:SetText(U.WrapColor(hex, tier.label))
  node.Sub:SetText(m and Views.Text.MeterLine(m) or data.sub or "")
  node.Value:SetText(data.value or "")
  local vc = data.valueColor
  if vc then node.Value:SetTextColor(vc[1], vc[2], vc[3]) else node.Value:SetTextColor(WHITE[1], WHITE[2], WHITE[3]) end
  node:SetAlpha(data.dim and 0.55 or 1)
  if m then
    node.Meter:SetColorTexture(r, g, b, capped and FULL_ALPHA or METER_ALPHA)
    node.MeterPacks:SetColorTexture(r, g, b, PACKS_ALPHA)
  end
  SizeMeter(node)
  if node.Check then
    node.Check:SetShown(capped)
    node.MaxText:SetShown(capped)
  end
  local border = node.border
  if data.glow then
    node:SetBackdropBorderColor(r, g, b, 1)
    node.Glow:SetColorTexture(r, g, b, 1)
    node.Glow:Show()
    if not node.GlowAnim:IsPlaying() then node.GlowAnim:Play() end
  else
    node:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    node.GlowAnim:Stop()
    node.Glow:Hide()
  end
  if data.spend == nil then
    node.Spend:Hide()
  else
    node.Spend:Show()
    node.Spend:SetChecked(data.spend == true)
  end
end

local LINK_STATES = {
  idle    = { line = { 0.35, 0.35, 0.35, 0.8 }, arrow = 0.35, mark = nil },
  locked  = { line = { 0.35, 0.2, 0.2, 0.8 }, arrow = 0.25, mark = "AdventureMapIcon-Lock" },
  pending = { line = { 0.6, 0.6, 0.6, 0.9 }, arrow = 0.7, mark = nil, flow = true },
  current = { line = { GOLD[1], GOLD[2], GOLD[3], 1 }, arrow = 1, mark = nil, flow = true },
  done    = { line = { 0.2, 0.8, 0.2, 1 }, arrow = 0.8, mark = "checkmark-minimal" },
}

local function SetDirection(link, down, gap)
  if link.down == down then return end
  link.down = down
  link.Arrow:SetRotation(down and math.pi or 0)
  for _, dot in ipairs(link.Dots) do
    dot.Anim:Stop()
    dot:ClearAllPoints()
    dot:SetPoint(down and "TOP" or "BOTTOM", link.Line, down and "TOP" or "BOTTOM", 0, 0)
    dot.Move:SetOffset(0, down and -gap or gap)
  end
end

local function DrawLink(link, season, toKey, data, gap)
  SetDirection(link, data and data.down == true or false, gap)
  local state = LINK_STATES[data and data.state or "idle"] or LINK_STATES.idle
  local c = state.line
  link.Line:SetColorTexture(c[1], c[2], c[3], c[4])
  link.Arrow:SetAlpha(state.arrow)
  if state.mark then
    link.Mark:SetAtlas(state.mark)
    link.Mark:Show()
  else
    link.Mark:Hide()
  end
  link.Label:SetText(data and data.label or "")
  link.tooltip, link.onClick = data and data.tooltip, data and data.onClick
  link:EnableMouse(link.tooltip ~= nil or link.onClick ~= nil)
  local r, g, b = RGB(Hex(season, toKey))
  for _, dot in ipairs(link.Dots) do
    if state.flow then
      dot:SetColorTexture(r, g, b, 1)
      if not dot.Anim:IsPlaying() then dot.Anim:Play() end
    else
      dot.Anim:Stop()
      dot:SetAlpha(0)
    end
  end
end

function Ladder:Render(model)
  local season = model and model.season
  if not season then
    self.frame:Hide()
    return
  end
  self.frame:Show()
  for i, tier in ipairs(season.tiers) do
    DrawNode(self.nodes[i], season, tier, model.nodes and model.nodes[tier.key] or {})
  end
  for i = 2, #season.tiers do
    DrawLink(self.links[i], season, season.tiers[i].key, model.links and model.links[season.tiers[i].key], self.opts.gap)
  end
end

-- Stop every animation (the ladder is no longer shown)
function Ladder:StopAll()
  for _, node in ipairs(self.nodes) do node.GlowAnim:Stop() end
  for i = 2, 5 do
    for _, dot in ipairs(self.links[i].Dots) do dot.Anim:Stop() end
  end
end
