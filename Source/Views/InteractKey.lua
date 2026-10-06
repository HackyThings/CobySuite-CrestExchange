-------------------------------------------------------------------------------
-- CobysCrestExchange Views.InteractKey: your Interact key runs the exchange
--
-- Talking to Vaskarn can't start from a click: the game only opens an NPC's
-- window from the Interact key binding (INTERACTTARGET, which runs the
-- restricted C_PlayerInteractionManager.InteractUnit("anyinteract")). So the
-- player's own Interact key does the whole exchange (Cobanyte, 2026-09-30:
-- remove friction), the pattern other established addons use:
--   * while the one button has something to press (open a pack, close the
--     vendor's window, buy the next step), an override binding owned by our
--     own frame makes the Interact key click it (SetOverrideBindingClick);
--   * when the plan waits for Vaskarn, the override is cleared, so the same
--     key talks to him again as it always does;
--   * while the plan waits for Vaskarn and the one button is showing, the
--     game's "Enable Interact Key" setting (CVar softTargetInteract, Any) is
--     switched on if it was off, so the key reaches the NPC you stand near
--     without changing your target; your own value is saved (COBYS_CREST_EXCHANGE_WINDOW_STATE.softInteractPrev,
--     so a reload or a crash still restores it) and put back as soon as the
--     plan stops waiting, and at logout; a change you make during the wait
--     stands and is never overwritten.
-- Only out of combat (bindings and this CVar can't change in combat lockdown;
-- PLAYER_REGEN_ENABLED syncs again). Two settings, both on by default (split
-- 2026-10-01, Task #53): "Press the exchange button with my Interact key"
-- turns all of it off; "Turn on Enable Interact Key for the walk back" turns
-- off only the CVar hold. InteractKey.Decide is the rule, Sync applies it.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local InteractKey = {}
Views.InteractKey = InteractKey

local BUTTON = "CobysCrestExchangeOpenButton"
local CLICK_MODES = { open = true, close = true, buy = true }
local ANY = Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any

local owner = CreateFrame("Frame")
local bound   -- the key our override binding is on, or nil

local function Enabled()
  local Config = CobysCrestExchange.Config
  return Config.Get(Config.Options.USE_INTERACT_KEY) ~= false
end

local function HoldAllowed()
  local Config = CobysCrestExchange.Config
  return Config.Get(Config.Options.HOLD_INTERACT_SETTING) ~= false
end

-- The player's Interact key, or nil when none is bound
function InteractKey.Key()
  local key = GetBindingKey("INTERACTTARGET")
  if key == nil or key == "" then return nil end
  return key
end

-- A key held with Shift, Ctrl, Alt or Meta can't click the button: its
-- modified clicks are blanked on purpose (shift-type* and the rest), so a
-- modified Interact key is never bound and the mouse does the clicking
local MODIFIERS = { SHIFT = true, CTRL = true, ALT = true, META = true }
local function Plain(key)
  local first = key and key:match("^(%u+)%-.")
  return key ~= nil and not (first and MODIFIERS[first])
end

-- The key's short name for a label ("F"), or nil
function InteractKey.Name()
  local key = Enabled() and InteractKey.Key()
  return key and GetBindingText(key, 1) or nil
end

-- The name only when the key really clicks the button (bound and plain)
function InteractKey.ClickName()
  return bound and GetBindingText(bound, 1) or nil
end

-- The player's Interact key for the settings card: "none", "modified" (it
-- has Shift, Ctrl, Alt or Meta, so it can't click the button) or "ok", and
-- the key's short name
function InteractKey.KeyState()
  local key = InteractKey.Key()
  if not key then return "none" end
  return Plain(key) and "ok" or "modified", GetBindingText(key, 1)
end

-- Whether the key is clicking the one button right now
function InteractKey.IsBound() return bound ~= nil end

local function State() return COBYS_CREST_EXCHANGE_WINDOW_STATE end

-- Our own writes, told apart from the player's: CVAR_UPDATE fires
-- synchronously during SetCVar (ConsoleDocumentation: SynchronousEvent)
local writing = false
-- The player changed the setting during this wait for Vaskarn: no new hold
-- until the wait ends
local declined = false
local exercise = {}   -- the Taint suite's Exercise and Undo (InteractKey._test)
local function Write(value)
  writing = true
  pcall(SetCVar, "softTargetInteract", value)
  writing = false
end

-- "Enable Interact Key" on while the plan waits for Vaskarn; the player's
-- own value back afterwards
local function HoldSoftInteract(on)
  local state = State()
  if not (ANY and state) then return end
  if on then
    if state.softInteractPrev == nil and not declined then
      local now = tonumber(GetCVar("softTargetInteract"))
      if now and now ~= ANY then
        state.softInteractPrev = now
        Write(ANY)
      end
    end
  else
    -- Only the end of the wait (no longer NEXT_STEP) lets a later one hold
    -- again; the window closing or collapsing mid-wait doesn't
    local Session = CobysCrestExchange.Session
    if not (Session and Session.State() == "NEXT_STEP") then declined = false end
  end
  if not on and state.softInteractPrev ~= nil then
    -- Only a hold we still own is given back (a change the player made
    -- meanwhile ends the hold: see CVAR_UPDATE below)
    if tonumber(GetCVar("softTargetInteract")) == ANY then
      Write(state.softInteractPrev)
    end
    state.softInteractPrev = nil
  end
end

-- Point the override binding at a key (nil clears it)
local function Apply(want)
  if want == bound then return end
  ClearOverrideBindings(owner)
  if want then SetOverrideBindingClick(owner, true, want, BUTTON, "LeftButton") end
  bound = want
end

-- The rule (pure): on and hold are the two settings, key the player's
-- Interact key (or nil), action the one button's next action (or nil while
-- it isn't showing). Returns the key our override binding should be on (or
-- nil), and whether Enable Interact Key should be held on now.
function InteractKey.Decide(on, hold, key, action)
  local want = on and key and Plain(key) and action and CLICK_MODES[action.mode] and action.enabled and key or nil
  local holdNow = (on and hold and action ~= nil and action.mode == "talk") and true or false
  return want, holdNow
end

-- Whether Enable Interact Key is, or will be, on while a plan waits for
-- Vaskarn: the player has it on already, or the hold is allowed and the
-- player hasn't changed it themselves during this wait (then no new hold is
-- taken until the wait ends: see CVAR_UPDATE below). TalkRule is the rule
-- alone, for the Interact suite on any client.
function InteractKey.TalkRule(settingOn, holdAllowed, declinedNow)
  return settingOn and true or (holdAllowed and not declinedNow) and true or false
end

function InteractKey.TalkReady()
  local on = ANY ~= nil and tonumber(GetCVar("softTargetInteract")) == ANY
  return InteractKey.TalkRule(on, HoldAllowed(), declined)
end

-- What the key should do now, from the one button's next action
function InteractKey.Sync()
  if InCombatLockdown() then return end
  local button = _G[BUTTON]
  local Session = CobysCrestExchange.Session
  -- A Verify scene shows sample state: the key keeps its own job
  if Session and Session.SceneLocked and Session.SceneLocked() then
    Apply(nil)
    HoldSoftInteract(false)
    return
  end
  local action = button and button:IsVisible() and Session and Session.NextAction() or nil
  local on = Enabled()
  local want, holdNow = InteractKey.Decide(on, HoldAllowed(), on and InteractKey.Key() or nil, action)
  Apply(want)
  HoldSoftInteract(holdNow)
end

owner:RegisterEvent("PLAYER_REGEN_DISABLED")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:RegisterEvent("UPDATE_BINDINGS")
owner:RegisterEvent("PLAYER_ENTERING_WORLD")
owner:RegisterEvent("PLAYER_LOGOUT")
owner:RegisterEvent("CVAR_UPDATE")
owner:SetScript("OnEvent", function(_, event, name)
  if event == "CVAR_UPDATE" then
    -- The player changed Enable Interact Key while we held it: their choice
    -- stands, and nothing is given back over it
    local state = State()
    if not writing and type(name) == "string" and name:lower() == "softtargetinteract"
      and state and state.softInteractPrev ~= nil then
      state.softInteractPrev = nil
      declined = true
      -- The talk prompts now ask for a target (TalkReady)
      if Views.Window then Views.Window.Refresh() end
    end
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    -- Combat is about to lock bindings: the Interact key goes back to its own
    -- job for the fight (this event comes just before the lockdown)
    if bound then ClearOverrideBindings(owner); bound = nil end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" and exercise.pending then
    -- A Taint suite cleanup that combat held back finishes now
    exercise.pending = nil
    InteractKey._test.Undo()
  end
  if event == "PLAYER_LOGOUT" then
    -- Override bindings end with the session; the CVar is the player's
    if not InCombatLockdown() then HoldSoftInteract(false) end
    return
  end
  InteractKey.Sync()
end)

-- The button showing or hiding (the window opened, closed or collapsed, or
-- the page changed) changes what the key should do
function InteractKey.Watch(button)
  button:HookScript("OnShow", InteractKey.Sync)
  button:HookScript("OnHide", InteractKey.Sync)
end

-- For the Taint suite: run the real binding and CVar calls, then undo them.
-- With Enable Interact Key already on, a known other value is set first so the
-- hold really writes and gives back; the player's own value is put back last.
InteractKey._test = {
  Plain = Plain,
  -- The Interact suite: a decline as the CVAR_UPDATE branch records it
  SetDeclined = function(value) declined = value and true or false end,
  Exercise = function()
    local key = InteractKey.Key()
    local state = State()
    if not key or not Plain(key) or InCombatLockdown() or not ANY or not state or state.softInteractPrev ~= nil then
      return false
    end
    exercise.original = GetCVar("softTargetInteract")
    if tonumber(exercise.original) == ANY then Write(Enum.SoftTargetEnableFlags.Gamepad) end
    Apply(key)
    HoldSoftInteract(true)
    -- both really ran: our binding is on the key, and the setting is held at Any
    return bound == key and state.softInteractPrev ~= nil and tonumber(GetCVar("softTargetInteract")) == ANY
  end,
  Undo = function()
    if InCombatLockdown() then exercise.pending = true; return end
    Apply(nil)
    HoldSoftInteract(false)
    if exercise.original ~= nil then Write(exercise.original) end
    exercise.original = nil
  end,
}

local listener = {}
function listener:ReceiveEvent() InteractKey.Sync() end
CobysCrestExchange.EventBus:Register(listener, {
  CobysCrestExchange.Events.SessionChanged,
  CobysCrestExchange.Events.ObservationsChanged,
  CobysCrestExchange.Events.ConfigChanged,
})
