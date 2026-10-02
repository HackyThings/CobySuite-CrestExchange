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
--     nodeW = 210, onClick = function(tierKey) end, onSpend = function(tierKey, on) end })
--   ladder:Render({
--     season = season,
--     nodes = { [tierKey] = { value = "120", valueColor = {r,g,b}, sub = "Room 45", icon = fileID,
--                             glow = bool, dim = bool, spend = nil|true|false } },
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
local function BuildNode(ladder, parent, opts)
  local node = CreateFrame("Button", nil, parent, "BackdropTemplate")
  node:SetHeight(opts.nodeH)
  if opts.nodeW then node:SetWidth(opts.nodeW) end
  node:SetBackdrop(U.Backdrops.CONTENT)
  node:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
  node.Icon = node:CreateTexture(nil, "ARTWORK")
  node.Icon:SetSize(opts.nodeH - 10, opts.nodeH - 10)
  node.Icon:SetPoint("LEFT", 6, 0)
  node.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  node.Name = node:CreateFontString(nil, "OVERLAY", U.Fonts.BODY)
  node.Sub = node:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  if opts.nodeH < 34 then
    -- A compact tile: the name and the line under it share one line
    node.Name:SetPoint("LEFT", node.Icon, "RIGHT", 8, 0)
    node.Sub:SetPoint("LEFT", node.Name, "RIGHT", 10, 0)
  else
    node.Name:SetPoint("TOPLEFT", node.Icon, "TOPRIGHT", 8, -1)
    node.Sub:SetPoint("BOTTOMLEFT", node.Icon, "BOTTOMRIGHT", 8, 1)
  end
  node.Sub:SetTextColor(0.75, 0.75, 0.75)
  node.Value = node:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  node.Value:SetPoint("RIGHT", -10, 0)
  node.Value:SetJustifyH("RIGHT")
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
  -- nodeW nil: the tiles span the ladder's width
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
    if not opts.nodeW then node:SetPoint("RIGHT", ladder.frame, "RIGHT", -2, 0) end
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
  node.Name:SetText(U.WrapColor(hex, tier.label))
  node.Sub:SetText(data.sub or "")
  node.Value:SetText(data.value or "")
  local vc = data.valueColor
  if vc then node.Value:SetTextColor(vc[1], vc[2], vc[3]) else node.Value:SetTextColor(WHITE[1], WHITE[2], WHITE[3]) end
  node:SetAlpha(data.dim and 0.55 or 1)
  if data.glow then
    node:SetBackdropBorderColor(r, g, b, 1)
    node.Glow:SetColorTexture(r, g, b, 1)
    node.Glow:Show()
    if not node.GlowAnim:IsPlaying() then node.GlowAnim:Play() end
  else
    node:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
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

-- Stop every animation (the page hides)
function Ladder:StopAll()
  for _, node in ipairs(self.nodes) do node.GlowAnim:Stop() end
  for i = 2, 5 do
    for _, dot in ipairs(self.links[i].Dots) do dot.Anim:Stop() end
  end
end
