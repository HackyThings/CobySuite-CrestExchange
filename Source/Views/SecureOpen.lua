-------------------------------------------------------------------------------
-- CobysCrestExchange Views.SecureOpen: the one exchange button
-- (CobysCrestExchangeOpenButton)
--
-- Opening an item from the bags needs a real click, so this is a
-- UIPanelButtonTemplate + InsecureActionButtonTemplate button: a plain
-- (unprotected) button whose click runs Blizzard's secure item action
-- (type "item", item "item:<packID>", which /use resolves by item ID, never
-- by bag slot). The attributes come from the shared UI.ConfigureSecureClicker
-- (the setup verified on Coby's Currency Searcher's transfer): LeftButtonUp,
-- useOnKeyDown false (else the ActionButtonUseKeyDown setting would fire it
-- on press only), modified clicks blanked; no onClick of ours (it would
-- replace the template's handler).
--
-- It is the one button that runs an exchange or a plan, always in the same
-- place, doing what Session.NextAction() says comes next:
--   Open next pack             the secure item use (the only mode that uses an item)
--   Close the vendor's window  a pack used with a vendor open is sold, so
--                              this press closes it (HideUIPanel, the panel
--                              manager's secure path) and opens nothing; the
--                              next press opens
--   Buy step N of M            a plan's next step, at Vaskarn; it ignores
--                              presses for half a second after it appears
--                              (an open step reads Start step N of M and
--                              needs no vendor)
--   Talk to Vaskarn ...        disabled: only the player can open his window
-- For every mode but Open, PreClick blanks the click's item action (type "")
-- and runs the mode's own action instead; PostClick re-arms. For Open,
-- PreClick still asks Session.MayOpen() and blanks the action on no.
-- Opening needs the vendor closed and buying needs it open, so a burst of
-- presses can't run from the last Open into the next Buy: the player has to
-- talk to Vaskarn in between. In combat the template itself refuses to act.
-------------------------------------------------------------------------------

local Views = CobysCrestExchange.Views
local SecureOpen = {}
Views.SecureOpen = SecureOpen

local UI = CobySuite_CobysCrestExchange.UI
local E = CobysCrestExchange.Events

local function Arm(button, itemID)
  button:SetAttribute("type", "item")
  if itemID then button:SetAttribute("item", "item:" .. itemID) end
end

function SecureOpen.Create(parent, point)
  local button = UI.CreateButton(parent, {
    name = "CobysCrestExchangeOpenButton",
    text = "Open next pack",
    size = { 220, 28 },
    point = point,
    template = "UIPanelButtonTemplate, InsecureActionButtonTemplate",
  })
  UI.ConfigureSecureClicker(button, { blockModified = true })
  Arm(button, nil)

  button:SetScript("PreClick", function(self)
    local Session = CobysCrestExchange.Session
    -- A Verify scene shows sample state: the press does nothing at all
    if Session.SceneLocked() then
      self:SetAttribute("type", "")
      self.blanked = true
      return
    end
    local mode = self.mode or "open"
    if mode ~= "open" then
      -- Not an item use: blank the secure action and do this mode's own step
      self:SetAttribute("type", "")
      self.blanked = true
      if InCombatLockdown() then return end
      if mode == "close" then
        if MerchantFrame and MerchantFrame:IsShown() then HideUIPanel(MerchantFrame) end
      elseif mode == "buy" then
        if GetTime() >= (self.readyAt or 0) then CobysCrestExchange.EventBus:Fire(E.SessionCommand, "next_step") end
      end
      if Views.Window then Views.Window.Refresh() end
      return
    end
    local ok, why = Session.MayOpen()
    local itemID = Session.OpenItemID()
    if not ok or not itemID then
      self:SetAttribute("type", "")
      self.blanked = true
      self.lastRefusal = why
      if Views.Window then Views.Window.Refresh() end
      return
    end
    self:SetAttribute("item", "item:" .. itemID)
    self.lastRefusal = nil
    CobysCrestExchange.EventBus:Fire(E.OpenAttempted, itemID)
  end)
  button:SetScript("PostClick", function(self)
    if self.blanked then
      self.blanked = false
      Arm(self, nil)
    end
  end)
  SecureOpen.button = button
  if Views.InteractKey then Views.InteractKey.Watch(button) end
  return button
end

local BUY_GUARD = 0.5   -- Buy step ignores presses this long after it appears

-- The label with the key that presses it ("Open next pack  (F)"), when the
-- Interact key is doing it
local function KeyLabel(text, mode)
  local key = Views.InteractKey
  if not key then return text end
  if mode == "talk" then
    local name = key.Name()
    return name and Views.Text.TalkKey(name, not key.TalkReady()) or text
  end
  local name = key.ClickName()
  return name and string.format("%s  (%s)", text, name) or text
end

-- The debug log notes each change of what the button says and why it is
-- greyed (only on a change, so a refresh never repeats it)
local lastSaid
local function Note(text, enabled, why)
  local said = string.format("%s, %s%s", tostring(text), enabled and "enabled" or "greyed", why and (": " .. tostring(why)) or "")
  if said == lastSaid then return end
  lastSaid = said
  CobysCrestExchange.Debug.Log("UI", "Button: %s", said)
end

local function Paint(view)
  local button = SecureOpen.button
  if not button then return end
  local order = view.order
  local scene = CobysCrestExchange.Session.SceneLocked()
  if scene and not InCombatLockdown() then
    button:SetAttribute("type", "")
    button:SetAttribute("item", nil)
  elseif order and order.itemID and not InCombatLockdown() then
    Arm(button, order.itemID)
  end
  local state = view.state
  local action = CobysCrestExchange.Session.NextAction()
  local mode = action and action.mode or "open"
  if mode == "buy" and button.mode ~= "buy" then
    button.readyAt = GetTime() + BUY_GUARD
    C_Timer.After(BUY_GUARD + 0.05, function() if Views.Window then Views.Window.Refresh() end end)
  end
  button.mode = mode
  if action and mode ~= "open" then
    -- The log notes the label as shown, key and target wording included
    local shown = KeyLabel(action.label, mode)
    button:SetText(shown)
    local guarded = mode == "buy" and GetTime() < (button.readyAt or 0)
    button:SetEnabled(action.enabled and not guarded)
    Note(shown, action.enabled and not guarded, action.reason or (guarded and "just appeared" or nil))
    return
  end
  if state == "COMPLETE" or (order and (view.openQuota or 0) <= 0) then
    -- An exchange ended early says so rather than claiming every pack opened
    local r = state == "COMPLETE" and view.receipt
    local unopened = r and r.outcome == "left" and r.unopened or 0
    button:SetText(unopened > 0 and "Packs left unopened" or "All packs opened")
    button:Disable()
    Note(unopened > 0 and "Packs left unopened" or "All packs opened", false, state)
    return
  end
  button:SetText(KeyLabel("Open next pack", "open"))
  -- Greyed under a Verify scene's lock too: view.canOpen is the sample's own
  -- state (the page's text shows it), not whether this button may act
  -- (in game 2026-10-01: the Window suite's scene-lock test found it enabled)
  local enabled = state == "READY_TO_OPEN" and view.canOpen == true and not scene
  button:SetEnabled(enabled)
  local why
  if not enabled then
    why = scene and "scene" or state
    if state == "READY_TO_OPEN" and not scene then why = select(2, CobysCrestExchange.Session.MayOpen()) or state end
  end
  Note("Open next pack", enabled, why)
end

-- Called on every progress refresh: the button, then what the Interact key does
function SecureOpen.Update(view)
  Paint(view)
  if Views.InteractKey then Views.InteractKey.Sync() end
end
