-- Dev/Trace.lua  (development only; the packager comments it out of releases)
-- /chui trace records NPC interaction events and Blizzard frame show/hide in
-- arrival order. GetTime() is constant within one rendered frame, so lines
-- sharing an f= value arrived in the same frame. The log is also kept in
-- ChuiDB.trace so it can be copied from SavedVariables after a /reload.
local _, Chui = ...

local EVENTS = {
    "GOSSIP_SHOW", "GOSSIP_CLOSED", "GOSSIP_CONFIRM", "GOSSIP_CONFIRM_CANCEL", "GOSSIP_ENTER_CODE",
    "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
    "QUEST_ACCEPTED", "QUEST_ITEM_UPDATE",
    "MERCHANT_SHOW", "MERCHANT_CLOSED",
    "TRAINER_SHOW", "TRAINER_CLOSED",
    "ITEM_TEXT_BEGIN", "ITEM_TEXT_READY", "ITEM_TEXT_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
}
local FRAMES = { "GossipFrame", "QuestFrame", "MerchantFrame", "ClassTrainerFrame", "ChuiHostFrame" }
local MAX_LINES = 400

local tracing, hooked = false, {}
local startMs
local listener = CreateFrame("Frame")

local interactionNames
local function InteractionName(value)
    if not interactionNames then
        interactionNames = {}
        for name, v in pairs(Enum.PlayerInteractionType) do interactionNames[v] = name end
    end
    return interactionNames[value] or tostring(value)
end

-- Midnight can hand addons "secret" values that must not be inspected.
local function Arg(v)
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    return tostring(v)
end

local function Log(text)
    local line = ("f=%.3f %+8.1fms  %s"):format(GetTime(), debugprofilestop() - startMs, text)
    local log = Chui.adb.global.trace
    log[#log + 1] = line
    if #log > MAX_LINES then table.remove(log, 1) end
    print(Chui.Theme.Paint("muted", "[trace]"), line)
end

listener:SetScript("OnEvent", function(_, event, ...)
    local n = select("#", ...)
    local args = {}
    for i = 1, n do args[i] = Arg((select(i, ...))) end
    local detail = table.concat(args, " ")
    if event:find("^PLAYER_INTERACTION_MANAGER") then
        detail = detail .. " (" .. InteractionName((...)) .. ")"
    end
    Log(event .. (detail ~= "" and ("  " .. detail) or ""))
end)

local function HookFrames()
    for _, name in ipairs(FRAMES) do
        local frame = _G[name]
        if frame and not hooked[name] then
            hooked[name] = true
            -- Observation only (HookScript), and silent unless tracing.
            frame:HookScript("OnShow", function() if tracing then Log(name .. ":OnShow") end end)
            frame:HookScript("OnHide", function() if tracing then Log(name .. ":OnHide") end end)
        end
    end
end

Chui:RegisterCommand("trace", "[clear] - dev: toggle the NPC event trace", function(arg)
    if arg == "clear" then
        wipe(Chui.adb.global.trace)
        Chui:Print("trace cleared")
        return
    end
    tracing = not tracing
    if tracing then
        startMs = debugprofilestop()
        HookFrames() -- ClassTrainerFrame only exists after a trainer loads it
        for _, event in ipairs(EVENTS) do listener:RegisterEvent(event) end
        Chui.adb.global.trace[#Chui.adb.global.trace + 1] = ("--- trace started %s ---"):format(date("%Y-%m-%d %H:%M:%S"))
    else
        listener:UnregisterAllEvents()
    end
    Chui:Print("trace", tracing and "on" or "off")
end)
