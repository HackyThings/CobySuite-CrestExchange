-------------------------------------------------------------------------------
-- CobysCrestExchange Settings Window
--
-- The suite's standard settings window (CobySuite.UI.CreateSettingsWindow,
-- the compact size preset, 640 x 460) with three categories (redesigned 2026-10-01,
-- Task #53):
--   Exchange      When visiting Vaskarn (three picture tiles: the window, its
--                 small tab, or nothing) and Keep at least (a button to the
--                 exchange window's Before you spend page, where reserves
--                 are edited; they are per character, so not settings)
--   Interact key  a card with the player's own Interact key and whether it
--                 can press the button now, the two Interact settings, and
--                 what the key does depending on the step
--   Window        Where it docks (four picture tiles) and Reset window
--                 position (acts at once)
-- Staged edits that Apply writes through Config.Set, Cancel, Defaults, and a
-- Guide footer button. Built at load, so opening it never creates frames in
-- combat; the controls are painted from config on every show, a
-- ConfigChanged event repaints an open window, and the key card repaints on
-- binding and combat changes. The addon is also listed under Options >
-- AddOns with a button that opens this window
-- (CobySuite.UI.RegisterSettingsCategory).
-------------------------------------------------------------------------------

local Config = CobysCrestExchange.Config
local Opt = Config.Options
local U = CobySuite_CobysCrestExchange.Utilities
local UI = CobySuite_CobysCrestExchange.UI

local function Views() return CobysCrestExchange.Views end

-- Window.NavBlock: nil, "receipt" or "busy" (whether Before you spend can show)
local function NavBlock()
  local Window = Views().Window
  return Window and Window.NavBlock and Window.NavBlock() or nil
end

-------------------------------------------------------------------------------
-- The mini scene on the picture tiles: Vaskarn's list as a grey panel, the
-- exchange window as a brand-blue one, its tab as a short blue strip. Drawn
-- once per tile, centered; previewPaint brightens the chosen tile's picture.
-------------------------------------------------------------------------------
local SCENE_H = 26
local LIST_W, PANEL_W, GAP = 22, 16, 3

local function Rect(host, color, w, h)
  local t = host:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(color[1], color[2], color[3], 1)
  t:SetSize(w, h)
  return t
end

-- kind: "right" | "left" | "tab" | "apart" | "both" | "closed"
local function Scene(kind)
  return function(frame)
    local brand = { U.HexToRGB(CobysCrestExchange.BRAND_COLOR) }
    local gray = U.Colors.LABEL_GRAY
    -- Textures and a font string only, on the kit's own preview frame: the
    -- first paint may come in combat, when no frame may be created
    local stage = frame
    frame.parts = {}
    local list = Rect(stage, gray, LIST_W, SCENE_H)
    list:SetPoint("CENTER", stage, "CENTER", 0, 0)
    local function Add(texture, faded)
      frame.parts[#frame.parts + 1] = { texture = texture, faded = faded }
      return texture
    end
    Add(list)
    if kind == "right" then
      Add(Rect(stage, brand, PANEL_W, SCENE_H)):SetPoint("LEFT", list, "RIGHT", GAP, 0)
    elseif kind == "left" then
      Add(Rect(stage, brand, PANEL_W, SCENE_H)):SetPoint("RIGHT", list, "LEFT", -GAP, 0)
    elseif kind == "both" then
      Add(Rect(stage, brand, PANEL_W, SCENE_H)):SetPoint("LEFT", list, "RIGHT", GAP, 0)
      Add(Rect(stage, brand, PANEL_W, SCENE_H), true):SetPoint("RIGHT", list, "LEFT", -GAP, 0)
    elseif kind == "apart" then
      Add(Rect(stage, brand, PANEL_W, SCENE_H - 6)):SetPoint("BOTTOMLEFT", list, "TOPRIGHT", GAP + 10, -(SCENE_H - 6))
    elseif kind == "tab" then
      Add(Rect(stage, brand, PANEL_W, 7)):SetPoint("TOPLEFT", list, "TOPRIGHT", GAP, 0)
    elseif kind == "closed" then
      local word = stage:CreateFontString(nil, "OVERLAY", U.Fonts.DATA)
      word:SetPoint("LEFT", list, "RIGHT", GAP + 2, 0)
      word:SetText("/ce")
      Add(word)
    end
  end
end

local function PaintScene(frame, selected)
  for _, part in ipairs(frame.parts or {}) do
    local alpha = selected and 1 or 0.55
    if part.faded then alpha = alpha * 0.5 end
    part.texture:SetAlpha(alpha)
  end
end

local function SceneTile(value, kind, title, description, tooltip)
  return { value = value, title = title, description = description, tooltip = tooltip,
    preview = Scene(kind), previewHeight = SCENE_H, previewPaint = PaintScene }
end

-------------------------------------------------------------------------------
-- The Interact key card (read only): the player's own key, from the live
-- binding; whether it can press the button, from the staged setting
-------------------------------------------------------------------------------
local function KeyCard(window)
  local InteractKey = Views().InteractKey
  local state, name = "none", nil
  if InteractKey then state, name = InteractKey.KeyState() end
  local card = { face = name or "?" }
  if state == "none" then
    card.state, card.stateText = "off", "Not set"
    card.title = "No Interact key"
    card.description = "Bind a key to Interact with Target in the game's key bindings to use this."
  elseif window:Get(Opt.USE_INTERACT_KEY) == false then
    card.state, card.stateText = "off", "Off"
    card.title = "Off"
    card.description = "Your Interact key does only what the game makes it do."
  elseif InCombatLockdown() then
    card.state, card.stateText = "warn", "In combat"
    card.title = "Unavailable in combat"
    card.description = "It works again as soon as combat ends."
  elseif state == "modified" then
    card.state, card.stateText = "warn", "Modifier"
    card.title = name .. " has a modifier"
    card.description = "A key held with Shift, Ctrl, Alt or Meta can't press the button. Click it instead, or bind a plain key."
  else
    card.title = name .. " can advance an exchange"
    card.state, card.stateText = "ok", "Bound"
    card.description = "One press per step, while the exchange window shows its button."
  end
  return card
end

local window = UI.CreateSettingsWindow({
  name    = "CobysCrestExchangeOptionsWindow",
  title   = U.WrapColor(CobysCrestExchange.BRAND_COLOR, "Coby's Crest Exchange") .. " Settings",
  icon    = CobysCrestExchange.ICON,
  config  = Config,
  size    = "compact",
  persist = {
    svTable = function() return COBYS_CREST_EXCHANGE_WINDOW_STATE end,
    key = "options",
  },
  watch   = { bus = CobysCrestExchange.EventBus, event = CobysCrestExchange.Events.ConfigChanged },
  message = function(text) CobysCrestExchange.Utilities.Message(text) end,
  footerButtons = {
    {
      text = "Guide", width = 80,
      tooltip = "Open the feature guide: how the exchange works, step by step.",
      onClick = function()
        if Views().Guide then Views().Guide.Toggle() end
      end,
    },
  },
  categories = {
    {
      key = "exchange", label = "Exchange",
      build = function(panel)
        panel:Section("When visiting Vaskarn", { icon = CobysCrestExchange.ICON })
        panel:Tiles{
          key = Opt.VENDOR_OPEN, columns = 3, height = 100,
          options = {
            SceneTile("window", "right", "Full window", "Opens beside his list, ready to use.",
              "Talking to Vaskarn opens the exchange window beside his list."),
            SceneTile("tab", "tab", "Small tab", "A tab waits beside his list. Click it to open.",
              "Talking to Vaskarn shows a small tab beside his list; click it when you want the exchange."),
            SceneTile("off", "closed", "Stay closed", "Nothing opens: /ce opens it when you want.",
              "Talking to Vaskarn opens nothing. Type /ce, or use the AddOns menu, when you want the exchange."),
          },
          description = "The collapse button on the window hides it to the tab for this visit only; this choice decides every visit.",
        }
        panel:Section("Keep at least", { atlas = "common-icon-checkmark" })
        panel:Button{
          text = "Set Keep at least...", width = 190, atlas = "common-icon-checkmark",
          tooltip = "Open the exchange window on Before you spend.",
          -- A review or an exchange under way holds the window on its own
          -- page; a finished exchange's receipt is closed first
          enabledWhen = function() return NavBlock() ~= "busy" end,
          description = function()
            if NavBlock() == "busy" then
              return "Finish or discard the exchange under way to change these amounts: the exchange window stays on it until then."
            end
            return "How many crests of each tier to keep on this character. Max and every exchange leave them alone."
          end,
          onClick = function(w)
            local Window = Views().Window
            local block = NavBlock()
            if not Window or block == "busy" then return w:RefreshState() end
            if block == "receipt" then
              CobysCrestExchange.EventBus:Fire(CobysCrestExchange.Events.SessionCommand, "done")
            end
            Window.Expand()
            Window.Go("before")
          end,
        }
      end,
    },
    {
      key = "key", label = "Interact key",
      build = function(panel)
        panel:StatusTiles{
          columns = 1, height = 58,
          options = {
            {
              face = function(w) return KeyCard(w).face end,
              title = function(w) return KeyCard(w).title end,
              description = function(w) return KeyCard(w).description end,
              state = function(w) return KeyCard(w).state end,
              stateText = function(w) return KeyCard(w).stateText end,
            },
          },
        }
        panel:Section("What your key does", { icon = "Interface\\Icons\\INV_Misc_Key_03" })
        panel:Checkbox{
          key = Opt.USE_INTERACT_KEY, label = "Press the exchange button with my Interact key",
          tooltip = "Your Interact key presses the exchange window's button for you, one press per step. Never in combat.",
          description = "Depending on the step, it buys, closes the vendor's window or opens the next pack.",
        }
        panel:Checkbox{
          key = Opt.HOLD_INTERACT_SETTING, label = "Turn on Enable Interact Key for the walk back", indent = 24,
          enabledWhen = function(get) return get(Opt.USE_INTERACT_KEY) ~= false end,
          tooltip = "Off: the addon never changes the game's Enable Interact Key setting. Target Vaskarn yourself before pressing the key.",
          description = "Between plan steps, switches Enable Interact Key on if it's off so your key can talk to Vaskarn, then restores your setting.",
        }
        panel:Section("When it's on, step by step")
        panel:Bullets{ items = {
          { title = "Buys the next packs", icon = CobysCrestExchange.ICON,
            lines = { "At Vaskarn, after you confirm the exchange." } },
          { title = "Closes Vaskarn's window", atlas = "common-icon-redx",
            lines = { "A pack used while a vendor is open would be sold." } },
          { title = "Opens the next pack", icon = "Interface\\Icons\\INV_Misc_Bag_08",
            lines = { "One pack per press, once the vendor's window is closed." } },
          { title = "Talks to Vaskarn", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
            lines = { "Only when a plan needs another visit to him." } },
        } }
      end,
    },
    {
      key = "window", label = "Window",
      build = function(panel)
        panel:Section("Where it docks", { icon = "Interface\\Icons\\INV_Misc_Map_01" })
        panel:Tiles{
          key = Opt.WINDOW_POSITION, columns = 2, height = 92,
          options = {
            SceneTile("right", "right", "Prefer right", "Right of his list, unless there's no room there."),
            SceneTile("left", "left", "Prefer left", "Left of his list, unless there's no room there."),
            SceneTile("auto", "both", "Automatic", "Whichever side has room, trying right first."),
            SceneTile("floating", "apart", "Saved position", "Where you last dragged it, even at Vaskarn."),
          },
          description = "When the side you prefer has no room, the window uses the other side, then its saved position. The small tab sits in the same place.",
        }
        panel:Button{
          text = "Reset window position", width = 180,
          enabledWhen = function() return Views().Dock ~= nil and Views().Dock.HasSavedSpot() end,
          description = "Takes effect immediately. Away from Vaskarn the window goes back to its starting spot, just above the middle of your screen.",
          onClick = function(w)
            if Views().Dock then Views().Dock.ResetPosition() end
            w:RefreshState()
          end,
        }
      end,
    },
  },
})

-- The key card follows the player's bindings and combat while it shows,
local watcher = CreateFrame("Frame")
for _, event in ipairs({ "UPDATE_BINDINGS", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
  watcher:RegisterEvent(event)
end
watcher:SetScript("OnEvent", function()
  if window:IsShown() then window:RefreshState() end
end)
-- and the crests-to-keep button follows the exchange's state
local sessionListener = {}
function sessionListener:ReceiveEvent()
  if window:IsShown() then window:RefreshState() end
end
CobysCrestExchange.EventBus:Register(sessionListener, { CobysCrestExchange.Events.SessionChanged })

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------
function Config.ToggleSettings()
  window:Toggle()
end

-- category: "exchange", "key" or "window" to open on that page (optional)
function Config.OpenSettings(category)
  window:Open()
  if category then window:SelectCategory(category) end
end

-- The window itself, for the Verify scenes (staging, Cancel, HasEdits)
Config.SettingsWindow = window
-- The Interact key card as the window would show it now (its state word in
-- stateText), for Verify's key-card check; reads only
function Config.KeyCard() return KeyCard(window) end

-------------------------------------------------------------------------------
-- Options > AddOns entry (registered once this addon has finished loading)
-------------------------------------------------------------------------------
EventUtil.ContinueOnAddOnLoaded("CobysCrestExchange", function()
  UI.RegisterSettingsCategory({
    name        = "Coby's Crest Exchange",
    brandColor  = CobysCrestExchange.BRAND_COLOR,
    version     = CobysCrestExchange.VERSION,
    description = {
      "A better crest exchange at Vaskarn: see what you can convert, pick an amount, and convert in a few clicks.",
      "The settings live in the addon's own settings window.",
    },
    slash       = "/ce settings",
    onOpen      = Config.OpenSettings,
  })
end)
