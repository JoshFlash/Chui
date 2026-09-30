-- Core/Suppressor.lua
-- Keeps Blizzard's NPC windows from showing while Chui owns an interaction
-- type, and gives them back exactly (Section 6). The specs below rest on
-- FrameXML 12.1.0: gossip shows from CustomGossipFrameManager (not
-- GossipFrame), quest from QuestFrame's own OnEvent, and the merchant from the
-- player interaction manager, which calls MerchantFrame_MerchantShow through a
-- reference captured at load (so hooking or replacing it does nothing).
--
-- Two mechanisms, chosen per interaction type by how Blizzard shows it:
--
--   "events"       The Blizzard frame shows itself from its own OnEvent.
--                  Engage = UnregisterEvent on that frame; Release = the
--                  exact inverse. Blizzard's code never runs while engaged,
--                  and runs untouched (no taint) while released.
--
--   "interaction"  The frame is shown by the player interaction manager, an
--                  anonymous frame we can't unregister. Engage installs a
--                  showCondition through Blizzard's own gate,
--                  SetPlayerInteractionConditions. Installed once, then
--                  toggled by a flag; only a /reload removes it.
--
-- Engagement only changes while idle (no NPC window of any kind is open),
-- so an interaction never switches UI halfway through.
local _, Chui = ...

local Suppressor = {}
Chui.Suppressor = Suppressor

---------------------------------------------------------------------------
-- Specs: data, not code. A patch that changes how a frame is shown should
-- be a one-line fix here.
---------------------------------------------------------------------------
local SPECS = {
    gossip = {
        method = "events",
        -- CustomGossipFrameManager, not GossipFrame, listens for these and
        -- routes to GossipFrame or a custom frame (NPE guide, Torghast...).
        frame = "CustomGossipFrameManager",
        events = { "GOSSIP_SHOW", "GOSSIP_CLOSED" },
        visible = { "GossipFrame" },
        closeEvents = { "GOSSIP_CLOSED" },
    },
    quest = {
        method = "events",
        frame = "QuestFrame",
        -- QUEST_ITEM_UPDATE, QUEST_LOG_UPDATE and the portrait events stay
        -- registered: QuestFrame ignores them while hidden.
        events = { "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED" },
        visible = { "QuestFrame" },
        closeEvents = { "QUEST_FINISHED" },
    },
    merchant = {
        method = "interaction",
        frame = "MerchantFrame",
        interaction = "Merchant", -- key in Enum.PlayerInteractionType
        visible = { "MerchantFrame" },
        closeEvents = { "MERCHANT_CLOSED" },
    },
}

local engaged = {}    -- kind -> true while Chui owns the kind
local active = {}     -- kind -> true while the owning module is enabled
local broken = {}     -- kind -> reason, when the self-check failed
local installed = {}  -- kind -> true once an interaction condition exists
local forwarding = {} -- kind -> true while Blizzard handles a forwarded interaction

---------------------------------------------------------------------------
-- Self-check (Section 6.3): refuse to half-suppress on an unexpected build.
---------------------------------------------------------------------------
local function Check(spec)
    local frame = _G[spec.frame]
    if not frame then
        return false, spec.frame .. " not found"
    end
    if spec.method == "events" then
        for _, event in ipairs(spec.events) do
            if not frame:IsEventRegistered(event) then
                return false, spec.frame .. " no longer listens for " .. event
            end
        end
    else
        if type(SetPlayerInteractionConditions) ~= "function" then
            return false, "SetPlayerInteractionConditions is missing"
        end
        if not (Enum.PlayerInteractionType and Enum.PlayerInteractionType[spec.interaction]) then
            return false, "unknown interaction type " .. spec.interaction
        end
    end
    return true
end

local function Engage(kind)
    if engaged[kind] then return true end
    local spec = SPECS[kind]
    local ok, reason = Check(spec)
    if not ok then return false, reason end

    if spec.method == "events" then
        local frame = _G[spec.frame]
        for _, event in ipairs(spec.events) do
            frame:UnregisterEvent(event)
        end
    elseif not installed[kind] then
        SetPlayerInteractionConditions(Enum.PlayerInteractionType[spec.interaction], {
            showCondition = function() return not engaged[kind] end,
        })
        installed[kind] = true
    end

    engaged[kind] = true
    Chui:Debug("engaged", kind)
    return true
end

local function Release(kind)
    if not engaged[kind] then return end
    local spec = SPECS[kind]
    if spec.method == "events" then
        local frame = _G[spec.frame]
        for _, event in ipairs(spec.events) do
            frame:RegisterEvent(event)
        end
    end
    engaged[kind] = false
    forwarding[kind] = nil
    Chui:Debug("released", kind)
end

---------------------------------------------------------------------------
-- State queries
---------------------------------------------------------------------------
function Suppressor:IsEngaged(kind)
    return engaged[kind] == true
end

local function Wanted(kind)
    return active[kind] and Chui.db.suppress[kind] and not broken[kind]
end

-- Should the module draw its panel for this interaction?
--   engaged                  -> yes, Chui owns it
--   not wanted (shadow mode) -> yes, alongside Blizzard's window
--   wanted but bypassed      -> no, Blizzard's window only
function Suppressor:ShouldRender(kind)
    return engaged[kind] or not Wanted(kind)
end

local function IsIdle()
    local host = Chui.Host.frame
    if host and host:IsShown() then return false end
    for _, spec in pairs(SPECS) do
        for _, name in ipairs(spec.visible) do
            local frame = _G[name]
            if frame and frame:IsShown() then return false end
        end
    end
    local custom = CustomGossipFrameManager and CustomGossipFrameManager.customFrame
    if custom and custom:IsShown() then return false end
    return true
end

local MODIFIER_TESTS = {
    SHIFT = IsShiftKeyDown,
    CTRL = IsControlKeyDown,
    ALT = IsAltKeyDown,
}

function Suppressor:BypassHeld()
    local test = MODIFIER_TESTS[Chui.db.bypassKey]
    return test ~= nil and test()
end

---------------------------------------------------------------------------
-- Sync: bring every kind in line with config, module state and the bypass
-- modifier. Called on modifier changes, after interactions close, and when
-- settings change. Does nothing while any NPC window is open.
--
-- The bypass works by releasing BEFORE the interaction starts (the modifier
-- goes down while idle), so for "events" kinds Blizzard's own, untainted
-- handler shows the default window.
---------------------------------------------------------------------------
function Suppressor:Sync()
    if not IsIdle() then return end
    local bypass = self:BypassHeld()
    for kind, spec in pairs(SPECS) do
        local want = Wanted(kind)
        -- "interaction" kinds show from tainted execution once the condition
        -- is installed; ShowUIPanel refuses that in combat and the merchant
        -- would close. So in combat the bypass is ignored for them.
        if want and bypass and not (spec.method == "interaction" and InCombatLockdown()) then
            want = false
        end
        if want then
            local ok, reason = Engage(kind)
            if not ok then
                broken[kind] = reason
                Chui:Print(("Can't take over the %s window on this game version (%s). Using the default window.")
                    :format(kind, reason))
            end
        else
            Release(kind)
        end
    end
end

-- Module enable/disable. Disabling releases at once, even mid-interaction.
function Suppressor:SetModuleActive(kind, on)
    if not SPECS[kind] then return end
    active[kind] = on or nil
    if not on then
        Release(kind)
        if installed[kind] then
            -- The condition can't be uninstalled; it now always says "show".
            Chui:Print(("The %s window is Blizzard's again. /reload to fully detach Chui from it."):format(kind))
        end
    end
    self:Sync()
end

---------------------------------------------------------------------------
-- Forwarding: hand one interaction to Blizzard while engaged. Used for
-- cases Chui deliberately doesn't draw (custom gossip frames, quest
-- auto-popups). The matching close event is forwarded automatically.
-- Runs Blizzard's handler from addon code (tainted); fine out of combat.
-- In combat CheckProtectedFunctionsAllowed() makes the show fail ("Interface
-- action failed"), and gossip then closes itself.
---------------------------------------------------------------------------
local function Dispatch(kind, event, ...)
    local spec = SPECS[kind]
    if spec.method ~= "events" then return false end
    local frame = _G[spec.frame]
    local onEvent = frame and frame:GetScript("OnEvent")
    if not onEvent then return false end
    onEvent(frame, event, ...)
    return true
end

function Suppressor:Forward(kind, event, ...)
    forwarding[kind] = true
    return Dispatch(kind, event, ...)
end

-- Fail-open replay after a module error. Suppression is already released.
function Suppressor:Replay(kind, event, ...)
    return Dispatch(kind, event, ...)
end

---------------------------------------------------------------------------
-- Init: one tracker frame for modifier changes and close events.
---------------------------------------------------------------------------
function Suppressor:Init()
    local closeKind = {}
    local tracker = CreateFrame("Frame")
    tracker:RegisterEvent("MODIFIER_STATE_CHANGED")
    tracker:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- Safety net for hand-offs the close events don't cover (for example a
    -- gossip option that continues into the flight map).
    tracker:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    for kind, spec in pairs(SPECS) do
        for _, event in ipairs(spec.closeEvents) do
            closeKind[event] = kind
            tracker:RegisterEvent(event)
        end
    end

    local function SyncSoon() Suppressor:Sync() end

    tracker:SetScript("OnEvent", function(_, event, ...)
        if event == "MODIFIER_STATE_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
            Suppressor:Sync()
            return
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            C_Timer.After(0, SyncSoon)
            return
        end

        local kind = closeKind[event]
        if forwarding[kind] and engaged[kind] then
            Dispatch(kind, event, ...)
            forwarding[kind] = nil
        end

        -- GOSSIP_CLOSED(true) means the NPC is handing over to another panel
        -- (usually quest detail); don't re-sync in the gap.
        if event == "GOSSIP_CLOSED" and (...) then return end

        -- Blizzard hides its frames from its own handlers for this event,
        -- which may run after ours, so check idleness on the next frame.
        -- Bookkeeping only; nothing the player sees waits on this.
        C_Timer.After(0, SyncSoon)
    end)
end

---------------------------------------------------------------------------
-- Diagnostics
---------------------------------------------------------------------------
function Suppressor:PrintStatus()
    Chui:Print(("bypass key %s (%s), idle %s, combat %s"):format(
        Chui.db.bypassKey, self:BypassHeld() and "held" or "up",
        tostring(IsIdle()), tostring(InCombatLockdown())))
    for kind, spec in pairs(SPECS) do
        print(("  %-9s %-11s wanted=%s engaged=%s%s%s"):format(
            kind, spec.method,
            tostring(Chui.db.suppress[kind] or false),
            tostring(engaged[kind] or false),
            installed[kind] and " condition-installed" or "",
            broken[kind] and (" BROKEN: " .. broken[kind]) or ""))
    end
end

function Suppressor:IsKnownKind(kind)
    return SPECS[kind] ~= nil
end
