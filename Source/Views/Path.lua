-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Path: a small, sideways picture of one route
--
-- The tiers a route touches, left to right in the order crests flow, as crest icons
-- joined by arrows with dots flowing along them, and under each icon what
-- happens to it: "-60" spent, "+20" received, "passes" for a tier the plan
-- only goes through. Built once at load (up to five stops); Render shows the
-- stops a route needs, centered.
--
--   local path = Path.Create(parent, { height = 58 })
--   path:Render(season, { { tierKey, icon, text, color } ... })   or path:Render(nil)
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Path = {}
Views.Path = Path

local U = CobySuite_CobysCrestExchange.Utilities

local STOPS = 5
local ICON = 28
local STEP = 72          -- center to center
local FLOW = 1.0

local function BuildStop(frame)
  local stop = CreateFrame("Frame", nil, frame)
  stop:SetSize(ICON, ICON)
  stop.Icon = stop:CreateTexture(nil, "ARTWORK")
  stop.Icon:SetAllPoints()
  stop.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  stop.Ring = stop:CreateTexture(nil, "BORDER")
  stop.Ring:SetPoint("TOPLEFT", -2, 2)
  stop.Ring:SetPoint("BOTTOMRIGHT", 2, -2)
  stop.Name = stop:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  stop.Name:SetPoint("TOP", stop, "BOTTOM", 0, -2)
  stop.Text = stop:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
  stop.Text:SetPoint("TOP", stop.Name, "BOTTOM", 0, -1)
  return stop
end

local function BuildArrow(frame, i)
  local arrow = CreateFrame("Frame", nil, frame)
  arrow:SetSize(STEP - ICON - 8, 10)
  arrow.Line = arrow:CreateTexture(nil, "ARTWORK")
  arrow.Line:SetHeight(2)
  arrow.Line:SetPoint("LEFT")
  arrow.Line:SetPoint("RIGHT", -6, 0)
  arrow.Line:SetColorTexture(1, 0.82, 0, 0.7)
  arrow.Head = arrow:CreateTexture(nil, "OVERLAY")
  arrow.Head:SetAtlas("NPE_ArrowUp")
  arrow.Head:SetRotation(-math.pi / 2)
  arrow.Head:SetSize(12, 12)
  arrow.Head:SetPoint("RIGHT", 2, 0)
  arrow.Dot = arrow:CreateTexture(nil, "OVERLAY")
  arrow.Dot:SetSize(5, 5)
  arrow.Dot:SetColorTexture(1, 0.9, 0.4, 1)
  arrow.Dot:SetPoint("LEFT")
  local group = arrow.Dot:CreateAnimationGroup()
  group:SetLooping("REPEAT")
  local move = group:CreateAnimation("Translation")
  move:SetOffset(STEP - ICON - 18, 0)
  move:SetDuration(FLOW)
  move:SetStartDelay((i - 1) * 0.2)
  local fade = group:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0)
  fade:SetDuration(FLOW * 0.3)
  fade:SetStartDelay((i - 1) * 0.2 + FLOW * 0.7)
  arrow.Anim = group
  return arrow
end

function Path.Create(parent, opts)
  opts = opts or {}
  local path = { stops = {}, arrows = {} }
  path.frame = CreateFrame("Frame", nil, parent)
  path.frame:SetHeight(opts.height or 58)
  for i = 1, STOPS do path.stops[i] = BuildStop(path.frame) end
  for i = 1, STOPS - 1 do path.arrows[i] = BuildArrow(path.frame, i) end
  return setmetatable(path, { __index = Path })
end

function Path:Render(season, stops)
  local n = stops and #stops or 0
  for i = 1, STOPS do self.stops[i]:SetShown(i <= n) end
  for i = 1, STOPS - 1 do
    local shown = i < n
    self.arrows[i]:SetShown(shown)
    if shown then self.arrows[i].Anim:Play() else self.arrows[i].Anim:Stop() end
  end
  if n == 0 then return end
  local total = (n - 1) * STEP
  for i, data in ipairs(stops) do
    local stop = self.stops[i]
    stop:ClearAllPoints()
    stop:SetPoint("TOP", self.frame, "TOP", -total / 2 + (i - 1) * STEP, 0)
    stop.Icon:SetTexture(data.icon or 134400)
    local hex = Views.Text.TierColor(season, data.tierKey)
    local r, g, b = U.HexToRGB(hex)
    stop.Ring:SetColorTexture(r, g, b, 0.9)
    stop.Name:SetText(U.WrapColor(hex, Views.Text.TierLabel(season, data.tierKey)))
    stop.Text:SetText(data.text or "")
    local c = data.color
    if c then stop.Text:SetTextColor(c[1], c[2], c[3]) else stop.Text:SetTextColor(0.8, 0.8, 0.8) end
    if i < n then
      local arrow = self.arrows[i]
      arrow:ClearAllPoints()
      arrow:SetPoint("LEFT", stop, "RIGHT", 4, 0)
    end
  end
end

function Path:Stop()
  for _, arrow in ipairs(self.arrows) do arrow.Anim:Stop() end
end
