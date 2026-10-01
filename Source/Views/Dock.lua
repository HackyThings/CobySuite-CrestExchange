-------------------------------------------------------------------------------
-- CobysCrestExchange Views.Dock: where the exchange window sits, and its tab
--
-- At the exchange vendor the window docks to the right of Blizzard's
-- merchant window by default (the Position setting: Right, Left, Automatic
-- which tries right then left, or Where I put it). A side that doesn't fit
-- on screen falls back to the other side, then to the saved spot. A known
-- neighbor panel docked at the merchant's right edge (Crest Xmute Helper's)
-- is stepped around by docking to that panel's right instead. Neighbors
-- and the merchant window are only read (IsShown, GetLeft, GetRight) and
-- hooked; nothing of theirs is moved or hidden.
--
-- Away from the vendor, and with "Where I put it", the window uses its saved
-- spot (dragging it saves it). At the vendor the dock always wins, so a drag
-- there lasts for that visit only. The window never jumps while an exchange
-- is under way, and when the vendor closes it stays exactly where it is on
-- screen (FloatFree).
--
-- The tab: collapsing the window leaves a small tab in its place (beside the
-- vendor window at Vaskarn); clicking it expands the window again. The
-- collapsed choice is remembered (COBYS_CREST_EXCHANGE_WINDOW_STATE.
-- exchangeCollapsed), so the next visit opens as the tab.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local Dock = {}
Views.Dock = Dock

local UI = CobySuite_CobysCrestExchange.UI
local U = CobySuite_CobysCrestExchange.Utilities

local GAP = 4
local NEIGHBOURS = { "CrestXmutePanel" }

local function State() return COBYS_CREST_EXCHANGE_WINDOW_STATE end

local function AtVendor()
  return MerchantFrame ~= nil and MerchantFrame:IsShown()
    and CobysCrestExchange.Observer.Current().merchant.isExchange == true
end

local function Position()
  local Config = CobysCrestExchange.Config
  return Config.Get(Config.Options.WINDOW_POSITION) or "right"
end

-- Dock a frame beside the merchant window per the Position setting (the
-- shared UI.DockBeside: the preferred side first, past a neighbor panel at
-- the merchant's right edge); false when not docked
local function DockBeside(frame)
  local position = Position()
  if position == "floating" or not AtVendor() then return false end
  return CobySuite_CobysCrestExchange.UI.DockBeside(frame, MerchantFrame, { gap = GAP, prefer = position, neighbours = NEIGHBOURS }) and true or false
end

local function Busy()
  local Session = CobysCrestExchange.Session
  local state = Session and Session.State()
  return state and state ~= "IDLE" and state ~= "SELECTING" and state ~= "COMPLETE"
end

-- Docked beside the vendor the window is a fixed panel: its width, the
-- vendor window's height, no resize grip. Floating on its own, it can be
-- resized again (its saved size comes back with RestoreState).
local DOCKED_WIDTH = 400

local function SetResizable(win, resizable)
  if not win.ResizeGrip then return end
  win:SetResizable(resizable)
  win.ResizeGrip:SetShown(resizable)
end

function Dock.Place(win)
  if win:IsShown() and Busy() then return end
  if DockBeside(win) then
    local height = MerchantFrame:GetHeight()
    win:SetSize(DOCKED_WIDTH, (height and height > 0) and height or win:GetHeight())
    SetResizable(win, false)
  else
    SetResizable(win, true)
    win:RestoreState()
  end
end

-- Keep a frame exactly where it is on screen, no longer tied to the merchant
-- (a window floating free can be resized again)
function Dock.FloatFree(frame)
  local left, top = frame:GetLeft(), frame:GetTop()
  if not left or not top then return end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  SetResizable(frame, true)
end

function Dock.ResetPosition()
  local state = State()
  if state then state.exchange = nil end
  local Window = Views.Window
  if Window and Window.frame:IsShown() then Dock.Place(Window.frame) end
end

-------------------------------------------------------------------------------
-- The collapsed tab
-------------------------------------------------------------------------------
local tab = UI.CreateButton(UIParent, {
  name = "CobysCrestExchangeTab",
  text = "Crest Exchange",
  size = { 150, 26 },
})
tab:SetFrameStrata("MEDIUM")
tab:SetToplevel(true)
tab:SetClampedToScreen(true)
tab:Hide()
tab.Plus = tab:CreateTexture(nil, "OVERLAY")
tab.Plus:SetAtlas(UI.FOLD_ATLAS.closed)
tab.Plus:SetSize(16, 16)
tab.Plus:SetPoint("LEFT", 6, 0)
tab:SetScript("OnClick", function() if Views.Window then Views.Window.Expand() end end)
UI.AddDynamicTooltip(tab, function(tip)
  tip:AddLine(U.WrapColor(CobysCrestExchange.BRAND_COLOR, "Coby's Crest Exchange"))
  local Session = CobysCrestExchange.Session
  local view = Session and Session.View()
  local status = view and Views.Text and Views.Text.TabStatus(view)
  if status then tip:AddLine(status, 1, 1, 1, true) end
  tip:AddLine("Click to expand.", unpack(U.Colors.INFO_BLUE))
end)
Dock.tab = tab

function Dock.IsCollapsed()
  local state = State()
  return state ~= nil and state.exchangeCollapsed == true
end

function Dock.SetCollapsed(collapsed)
  local state = State()
  if state then state.exchangeCollapsed = collapsed and true or nil end
end

-- Show the tab: beside the vendor window at Vaskarn, else where the window's top left was
function Dock.ShowTab(win)
  if not DockBeside(tab) then
    local left, top = win and win:GetLeft(), win and win:GetTop()
    tab:ClearAllPoints()
    if left and top then
      tab:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    else
      tab:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
  end
  tab:Show()
end

function Dock.HideTab() tab:Hide() end

function Dock.TabShown() return tab:IsShown() end

-- The merchant window can be dragged and closed: when it closes, whatever
-- was docked to it stays where it is on screen
function Dock.Hook()
  if Dock.hooked or not MerchantFrame then return end
  Dock.hooked = true
  MerchantFrame:HookScript("OnHide", function()
    for _, frame in ipairs({ Views.Window and Views.Window.frame, tab }) do
      if frame and frame:IsShown() then
        local _, relativeTo = frame:GetPoint(1)
        if relativeTo and relativeTo ~= UIParent then Dock.FloatFree(frame) end
      end
    end
  end)
end
