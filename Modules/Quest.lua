-- Modules/Quest.lua
-- Stub for the quest panels: greeting, detail, progress, complete.
-- Text only, plus one primary button for the simple cases so a suppressed
-- quest flow can be exercised end to end. Anything the stub can't do yet
-- (reward choice, PvP confirm, expensive turn-in) says so: close the panel
-- and talk again holding the bypass modifier.
--
-- Parity rules copied from QuestFrame_OnEvent (FrameXML 12.1.0): some
-- QUEST_DETAIL events never show QuestFrame at all. Those are forwarded to
-- Blizzard when engaged, and skipped in shadow mode.
local _, Chui = ...

local Quest = Chui:NewModule("Quest")
Quest.kind = "quest"
Quest.events = { "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED" }

local ACCENT = "|cffc9a45c%s|r"
local GOOD, WARN = "|cff4fbf6b%s|r", "|cffe0b040%s|r"

local parts, lines = {}, {}

-- Joins non-empty paragraphs with a blank line between them.
local function Paragraphs(...)
    wipe(parts)
    for i = 1, select("#", ...) do
        local text = select(i, ...)
        if text and text ~= "" then parts[#parts + 1] = text end
    end
    return table.concat(parts, "\n\n")
end

function Quest:Show(title, body, primary)
    Chui.Host:Present(self, {
        width = Chui.Theme.tokens.width.quest,
        title = title,
        subtitle = UnitName("npc"),
        body = body,
        primary = primary,
    })
end

-- QUEST_DETAIL cases where Blizzard shows no quest window: the quest
-- becomes a tracker pop-up (item-started or area-trigger auto-accept), or
-- it belongs to the adventure map.
local function DetailIsNotAWindow(questStartItemID)
    return QuestIsFromAdventureMap()
        or (questStartItemID ~= nil and questStartItemID ~= 0)
        or (QuestGetAutoAccept() and QuestIsFromAreaTrigger())
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function Quest:QUEST_GREETING()
    if not Chui.Suppressor:ShouldRender("quest") then return end
    local t0 = debugprofilestop()

    wipe(lines)
    local n = 0
    for i = 1, GetNumAvailableQuests() do
        n = n + 1
        lines[n] = ("%d.  |cffffd100!|r  %s"):format(n, GetAvailableTitle(i))
    end
    for i = 1, GetNumActiveQuests() do
        local title, isComplete = GetActiveTitle(i)
        n = n + 1
        lines[n] = ("%d.  %s?|r  %s"):format(n, isComplete and "|cffffd100" or "|cff808080", title)
    end

    self:Show(UnitName("npc"), Paragraphs(GetGreetingText(), table.concat(lines, "\n")))
    Chui:Debug(("quest greeting render %.2f ms"):format(debugprofilestop() - t0))
end

function Quest:QUEST_DETAIL(questStartItemID)
    local S = Chui.Suppressor
    if not S:ShouldRender("quest") then return end

    if DetailIsNotAWindow(questStartItemID) then
        if S:IsEngaged("quest") then S:Forward("quest", "QUEST_DETAIL", questStartItemID) end
        return
    end
    local t0 = debugprofilestop()

    local primary
    if QuestFlagsPVP() then
        primary = { text = ACCEPT, enabled = false } -- needs PvP confirm (M1)
    elseif QuestGetAutoAccept() then
        -- Already accepted by the server; Blizzard's button reads OK.
        primary = { text = OKAY, onClick = AcknowledgeAutoAcceptQuest }
    else
        primary = { text = ACCEPT, onClick = AcceptQuest }
    end

    self:Show(GetTitleText(), Paragraphs(
        GetQuestText(),
        ACCENT:format(QUEST_OBJECTIVES) .. "\n" .. GetObjectiveText()
    ), primary)
    Chui:Debug(("quest detail render %.2f ms"):format(debugprofilestop() - t0))
end

function Quest:QUEST_PROGRESS()
    if not Chui.Suppressor:ShouldRender("quest") then return end
    local t0 = debugprofilestop()

    local completable = IsQuestCompletable()
    self:Show(GetTitleText(), Paragraphs(
        GetProgressText(),
        completable and GOOD:format("Ready to turn in.") or WARN:format("Not complete yet.")
    ), { text = CONTINUE, onClick = CompleteQuest, enabled = completable })
    Chui:Debug(("quest progress render %.2f ms"):format(debugprofilestop() - t0))
end

function Quest:QUEST_COMPLETE()
    if not Chui.Suppressor:ShouldRender("quest") then return end
    local t0 = debugprofilestop()

    local choices = GetNumQuestChoices()
    local money = GetQuestMoneyToGet()
    local note, primary
    if choices > 1 then
        note = WARN:format(("%d reward choices: reward picking arrives in M1. Use the bypass modifier for now."):format(choices))
    elseif money and money > 0 then
        note = WARN:format("This turn-in costs gold and needs a confirmation (M1). Use the bypass modifier for now.")
    end
    if not note then
        -- Same rule as QuestRewardCompleteButton_OnClick: one choice is picked
        -- automatically, no choices means index 0.
        local choice = choices == 1 and 1 or 0
        primary = { text = COMPLETE_QUEST, onClick = function() GetQuestReward(choice) end }
    else
        primary = { text = COMPLETE_QUEST, enabled = false }
    end

    self:Show(GetTitleText(), Paragraphs(GetRewardText(), note), primary)
    Chui:Debug(("quest complete render %.2f ms"):format(debugprofilestop() - t0))
end

function Quest:QUEST_FINISHED()
    Chui.Host:Dismiss(self)
end

-- The player closed our panel. Known gap vs Blizzard's QuestFrame_OnHide:
-- auto-accept quests also remove their tracker pop-up there (M1).
function Quest:OnHostClosed()
    CloseQuest()
end
