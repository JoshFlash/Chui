-- Modules/Quest.lua
-- The quest panels: greeting, detail, progress, complete.
-- Text, clickable greeting rows, and one primary button (Space presses it).
-- The complete view lists the quest's rewards: you pick one of the choices (click,
-- or its number key) and the Complete button stays off until you have; each reward
-- has the item tooltip on hover. Anything not done yet (PvP accept confirm,
-- paid turn-ins) says so: close the panel and talk again holding the bypass
-- modifier.
--
-- Parity rules copied from QuestFrame_OnEvent (FrameXML 12.1.0): some
-- QUEST_DETAIL events never show QuestFrame at all. Those are forwarded to
-- Blizzard when engaged, and skipped in shadow mode.
local _, Chui = ...

local Quest = Chui:NewModule("Quest")
Quest.kind = "quest"
Quest.events = { "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
    "QUEST_ITEM_UPDATE" }

local Paint = Chui.Theme.Paint

local parts, rows = {}, {}

-- Joins non-empty paragraphs with a blank line between them.
local function Paragraphs(...)
    wipe(parts)
    for i = 1, select("#", ...) do
        local text = select(i, ...)
        if text and text ~= "" then parts[#parts + 1] = text end
    end
    return table.concat(parts, "\n\n")
end

function Quest:Show(title, body, primary, listRows, owner, keepScroll)
    local skin = Chui.Theme.Use(Chui.Theme.DialogueSkin())
    Chui.Host:Present(owner or self, {
        width = Chui.Theme.tokens.width.quest,
        title = title,
        subtitle = UnitName("npc"),
        body = body,
        primary = primary,
        rows = listRows,
        skin = skin,
        fixedHeight = true,
        keepScroll = keepScroll,
    })
end

-- Right-clicking an available quest (in a gossip list or a quest greeting)
-- accepts it as soon as its detail opens, without showing the panel. Asked
-- for just before the quest is selected, and good for a few seconds.
local AUTO_ACCEPT_WINDOW = 3

function Quest:RequestAutoAccept()
    self.autoAcceptUntil = GetTime() + AUTO_ACCEPT_WINDOW
end

-- A hint that follows the mouse pointer while it is over an available quest.
function Quest.ShowAcceptHint(row)
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    GameTooltip:SetText("Right-click to accept", 0.3, 0.9, 0.4)
    GameTooltip:AddLine("Left-click to read the quest", 0.8, 0.8, 0.8)
    GameTooltip:Show()
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
    Chui.Theme.Use(Chui.Theme.DialogueSkin()) -- before any Paint, so colours suit the skin
    if not Chui.Suppressor:ShouldRender("quest") then return end
    self.view = "greeting"
    local t0 = debugprofilestop()

    wipe(rows)
    local icons = Chui.Theme.tokens.icons
    for i = 1, GetNumAvailableQuests() do
        rows[#rows + 1] = {
            text = GetAvailableTitle(i),
            wrap = true,
            atlas = icons.offer.atlas, icon = icons.offer.file,
            clicks = "AnyUp", -- right-click accepts the quest as soon as it opens
            tooltip = Quest.ShowAcceptHint,
            onClick = function(button)
                if button ~= "LeftButton" and button ~= "RightButton" then return end
                if button == "RightButton" then self:RequestAutoAccept() end
                SelectAvailableQuest(i)
            end,
        }
    end
    for i = 1, GetNumActiveQuests() do
        local title, isComplete = GetActiveTitle(i)
        rows[#rows + 1] = {
            text = title,
            wrap = true,
            atlas = icons.turnin.atlas, icon = icons.turnin.file, muted = not isComplete,
            onClick = function() SelectActiveQuest(i) end,
        }
    end

    self:Show(UnitName("npc"), GetGreetingText(), nil, rows)
    Chui:Debug(("quest greeting render %.2f ms"):format(debugprofilestop() - t0))
end

function Quest:QUEST_DETAIL(questStartItemID)
    Chui.Theme.Use(Chui.Theme.DialogueSkin()) -- before any Paint, so colours suit the skin
    local S = Chui.Suppressor
    if not S:ShouldRender("quest") then return end

    if DetailIsNotAWindow(questStartItemID) then
        if S:IsEngaged("quest") then S:Forward("quest", "QUEST_DETAIL", questStartItemID) end
        return
    end
    -- Asked to accept this one on sight. A PvP quest still wants its
    -- confirmation, and an auto-accepted one is already taken.
    if self.autoAcceptUntil then
        local wanted = GetTime() <= self.autoAcceptUntil
        self.autoAcceptUntil = nil
        if wanted and not QuestFlagsPVP() and not QuestGetAutoAccept() then
            AcceptQuest()
            return
        end
    end
    self.view = "detail"
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
        Paint("accent", QUEST_OBJECTIVES) .. "\n" .. GetObjectiveText()
    ), primary)
    Chui:Debug(("quest detail render %.2f ms"):format(debugprofilestop() - t0))
end

function Quest:QUEST_PROGRESS()
    Chui.Theme.Use(Chui.Theme.DialogueSkin()) -- before any Paint, so colours suit the skin
    if not Chui.Suppressor:ShouldRender("quest") then return end
    self.view = "progress"
    local t0 = debugprofilestop()

    local completable = IsQuestCompletable()
    self:Show(GetTitleText(), Paragraphs(
        GetProgressText(),
        completable and Paint("good", "Ready to turn in.") or Paint("warn", "Not complete yet.")
    ), { text = CONTINUE, onClick = CompleteQuest, enabled = completable })
    Chui:Debug(("quest progress render %.2f ms"):format(debugprofilestop() - t0))
end

---------------------------------------------------------------------------
-- Quest rewards: read them, draw them as rows, choose one.
---------------------------------------------------------------------------
local REWARD_ICON_SIZE = 30
local UNUSABLE_TINT = { 1, 0.3, 0.3 }

local function QualityName(name, quality)
    name = name or "..." -- item names arrive asynchronously; QUEST_ITEM_UPDATE redraws
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.color then
        return color.color:WrapTextInColorCode(name)
    elseif color and color.hex then
        return color.hex .. name .. "|r"
    end
    return name
end

-- API reads -> a plain table. `choices` are the items you pick one of;
-- `rewards` are the ones you get regardless.
function Quest:ReadRewards()
    local state = {
        choices = {}, rewards = {},
        xp = GetRewardXP and GetRewardXP() or 0,
        money = GetRewardMoney and GetRewardMoney() or 0,
        title = GetRewardTitle and GetRewardTitle(),
        moneyToGet = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0,
        text = GetRewardText(),
        heading = GetTitleText(),
    }
    local function read(kind, count, list)
        for i = 1, count do
            local name, icon, number, quality, usable = GetQuestItemInfo(kind, i)
            list[i] = {
                kind = kind, index = i, name = name, icon = icon, count = number,
                quality = quality, usable = usable ~= false, link = GetQuestItemLink(kind, i),
            }
        end
    end
    read("choice", GetNumQuestChoices(), state.choices)
    read("reward", GetNumQuestRewards(), state.rewards)
    return state
end

-- One reward row. `onSelect` makes it a choice; without it the row is just
-- an item to look at. Hovering shows the item's own tooltip (the fixture, which
-- has no real quest, shows just the name).
local function RewardRow(item, live, selected, number, onSelect)
    return {
        text = QualityName(item.name, item.quality),
        icon = item.icon,
        iconSize = REWARD_ICON_SIZE,
        count = item.count,
        tint = not item.usable and UNUSABLE_TINT or nil,
        selectable = onSelect ~= nil or selected,
        selected = selected,
        number = number,
        clicks = "LeftButtonUp",
        onClick = function()
            -- Shift-click links the item, ctrl-click previews it, as on any item.
            if live and item.link and HandleModifiedItemClick(item.link) then return end
            if onSelect then onSelect() end
        end,
        tooltip = function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            if live then
                GameTooltip:SetQuestItem(item.kind, item.index)
            else
                GameTooltip:SetText(item.name or "?")
            end
        end,
    }
end

-- The complete view. `owner` is only passed by the fixture, whose Complete
-- button must not touch the game.
function Quest:ShowComplete(state, owner)
    Chui.Theme.Use(Chui.Theme.DialogueSkin()) -- before any Paint, so colours suit the skin
    local live = owner == nil
    local choices = #state.choices
    -- One choice is picked for you, as in Blizzard's own window.
    local selected = choices == 1 and 1 or self.selectedChoice

    wipe(rows)
    local function choose(index)
        self.selectedChoice = index
        self:ShowComplete(state, owner)
    end

    if choices > 0 then
        local heading = choices > 1 and "Choose your reward" or "Your reward"
        rows[#rows + 1] = { text = Paint("accent", heading), inert = true, height = 30 }
        for i, item in ipairs(state.choices) do
            rows[#rows + 1] = RewardRow(item, live, selected == i, i <= 9 and i or nil,
                choices > 1 and function() choose(i) end or nil)
        end
    end
    if #state.rewards > 0 then
        rows[#rows + 1] = { text = Paint("accent", "You will also receive"), inert = true, height = 30 }
        for _, item in ipairs(state.rewards) do
            rows[#rows + 1] = RewardRow(item, live, false, nil, nil)
        end
    end

    -- Experience, money and title go with the quest's own text.
    local summary = {}
    if (state.xp or 0) > 0 then summary[#summary + 1] = ("Experience: %d"):format(state.xp) end
    if (state.money or 0) > 0 then summary[#summary + 1] = "Money: " .. GetMoneyString(state.money, true) end
    if state.title and state.title ~= "" then summary[#summary + 1] = "Title: " .. state.title end

    -- The Complete button waits for a choice, and for a paid turn-in's
    -- confirmation, which isn't built yet.
    local note, primary
    if state.moneyToGet and state.moneyToGet > 0 then
        note = Paint("warn", "This turn-in costs gold and needs a confirmation (not built yet). Use the bypass modifier for now.")
    end
    local ready = note == nil and (choices <= 1 or selected ~= nil)
    primary = {
        text = COMPLETE_QUEST,
        enabled = ready,
        onClick = function()
            if live then
                GetQuestReward(selected or 0)
            else
                Chui:Print(("test: Complete pressed, reward choice %s"):format(tostring(selected)))
            end
        end,
    }

    self:Show(state.heading, Paragraphs(state.text, table.concat(summary, "\n"), note), primary, rows, owner, true)
end

function Quest:QUEST_COMPLETE()
    Chui.Theme.Use(Chui.Theme.DialogueSkin()) -- before any Paint, so colours suit the skin
    if not Chui.Suppressor:ShouldRender("quest") then return end
    self.view = "complete"
    self.selectedChoice = nil
    local t0 = debugprofilestop()
    self:ShowComplete(self:ReadRewards())
    Chui:Debug(("quest complete render %.2f ms"):format(debugprofilestop() - t0))
end

-- Item names and icons load after the event; draw the rewards again, keeping
-- the choice already made.
function Quest:QUEST_ITEM_UPDATE()
    if self.view == "complete" and Chui.Host:IsShownFor(self) then
        self:ShowComplete(self:ReadRewards())
    end
end

function Quest:QUEST_FINISHED()
    self.view = nil
    Chui.Host:Dismiss(self)
end

---------------------------------------------------------------------------
-- Fixture for /chui test quest: a long detail page with Accept, so scrolling,
-- the fixed footer and the Space key can all be tried without a quest giver.
-- Uses a stand-in owner so closing it doesn't call CloseQuest().
---------------------------------------------------------------------------
local FIXTURE_PARAGRAPHS = {
    "The road north of the ford has been quiet for three seasons, and quiet is exactly what worries me. "
        .. "Caravans that once came every week now come never, and the last rider to pass through swore the "
        .. "watchfires at the pass had been put out from the inside.",
    "I would send one of my own, but every hand I have is tied to the harvest, and the captain will not "
        .. "spare a single spear until the snows. That leaves you. You have the look of someone who has "
        .. "walked into worse and walked out again, and I am past being proud about who I ask.",
    "Go to the pass. Do not stop at the ford, and do not trust the old bridge, which has not held weight "
        .. "since the flood. Follow the drainage ditch along the east wall instead; it is wet, foul, and "
        .. "nobody is watching it. When you reach the watchtower, count the fires. There should be seven.",
    "If there are fewer than seven, come back at once and tell no one but me. If there are more, well. "
        .. "Then something has been lighting them that is not one of ours, and I would very much like to "
        .. "know what warms itself on a border it has no business crossing.",
    "Whatever you find, bring proof. A banner, a blade, a scrap of cloth, I do not care. The council will "
        .. "not move on a story, and I am tired of being the only voice at the table that remembers what "
        .. "the last silence cost us.",
    "I cannot pay much now, but there is a chest under my bed that has been waiting for a reason. "
        .. "Come back alive, and it is yours.",
}

local fixtureOwner = {}

function Quest:ShowFixture()
    Chui.Theme.Use(Chui.Theme.DialogueSkin()) -- before any Paint, so colours suit the skin
    local t0 = debugprofilestop()
    self:Show("The Silent Pass", Paragraphs(
        table.concat(FIXTURE_PARAGRAPHS, "\n\n"),
        Paint("accent", QUEST_OBJECTIVES) .. "\nLight the seventh watchfire at the Silent Pass."
    ), {
        text = ACCEPT,
        onClick = function() Chui:Print("test: Accept pressed (nothing is accepted)") end,
    }, nil, fixtureOwner)
    Chui:Debug(("quest fixture render %.2f ms"):format(debugprofilestop() - t0))
end

-- /chui test reward: the quest-complete view with four rewards to choose
-- from and two you always get, so choosing, the check mark, the number keys
-- and the tooltips can all be tried without handing in a quest.
function Quest:ShowRewardFixture()
    self.selectedChoice = nil
    local function item(name, icon, quality, count, usable)
        return { kind = "choice", index = 1, name = name, icon = "Interface\\Icons\\" .. icon, count = count,
            quality = quality, usable = usable ~= false }
    end
    self:ShowComplete({
        heading = "The Silent Pass",
        text = "You counted the fires, and you brought proof. The council will listen now. Take your pick of what "
            .. "I have kept for you; the rest of it is yours either way.",
        xp = 1850,
        money = 12750,
        title = "Warden of the Pass",
        moneyToGet = 0,
        choices = {
            item("Warden's Longsword", "INV_Sword_04", 3, 1),
            item("Wayfarer's Cloak", "INV_Misc_Cape_18", 3, 1),
            item("Sentinel's Shield", "INV_Shield_05", 3, 1, false),
            item("Pouch of Silver Dust", "INV_Misc_Dust_01", 2, 5),
        },
        rewards = {
            item("Healing Potion", "INV_Potion_54", 1, 3),
            item("Honeyed Bread", "INV_Misc_Food_35", 1, 5),
        },
    }, fixtureOwner)
end

-- The player closed our panel. Known gap vs Blizzard's QuestFrame_OnHide:
-- auto-accept quests also remove their tracker pop-up there (M1).
function Quest:OnHostClosed()
    CloseQuest()
end
