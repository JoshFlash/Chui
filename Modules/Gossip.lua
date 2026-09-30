-- Modules/Gossip.lua
-- Gossip, still a read-only stub. Two modes:
--   shadow (default)  Blizzard's GossipFrame does the work; Chui draws a copy.
--   suppressed        /chui suppress gossip on. GossipFrame never shows; Chui
--                     replicates the bits of Blizzard's show logic that are
--                     not just drawing (auto-select, custom gossip frames).
-- Rows are clickable. Confirm, code entry and number keys arrive later in M1.
local _, Chui = ...

local Gossip = Chui:NewModule("Gossip")
Gossip.kind = "gossip"
Gossip.events = { "GOSSIP_SHOW", "GOSSIP_CLOSED" }

local Paint = Chui.Theme.Paint

---------------------------------------------------------------------------
-- State: API reads -> plain table (Section 3, "State in, pixels out")
---------------------------------------------------------------------------
Gossip.state = {}

local function ByOrderIndex(a, b)
    return (a.orderIndex or 0) < (b.orderIndex or 0)
end

function Gossip:BuildState()
    local s = self.state
    s.title = UnitName("npc") or UNKNOWN
    s.subtitle = GetMinimapZoneText()
    s.text = C_GossipInfo.GetText() or ""
    s.available = C_GossipInfo.GetAvailableQuests()
    s.active = C_GossipInfo.GetActiveQuests()
    s.options = C_GossipInfo.GetOptions()
    table.sort(s.options, ByOrderIndex)
    return s
end

-- Exact copy of Blizzard's rule in GossipFrameSharedMixin:HandleShow
-- (Section 10.2, auto-select parity). Never adds auto-selection of its own.
function Gossip:IsAutoSelect(s)
    return #s.available == 0 and #s.active == 0 and #s.options == 1
        and not C_GossipInfo.ForceGossip()
        and s.options[1].selectOptionWhenOnlyOption
end

---------------------------------------------------------------------------
-- View: state -> Host content. Pure function of the state table, so the
-- /chui test fixture renders exactly like a real NPC.
---------------------------------------------------------------------------
local rows = {}

-- `owner` is only passed by the fixture, whose rows must not call the game.
function Gossip:Render(s, owner)
    wipe(rows)
    local live = owner == nil

    local icons = Chui.Theme.tokens.icons
    for _, q in ipairs(s.available) do
        rows[#rows + 1] = {
            text = q.isTrivial and Paint("dim", q.title) or q.title,
            atlas = icons.offer.atlas, icon = icons.offer.file, muted = q.isTrivial,
            onClick = live and function() C_GossipInfo.SelectAvailableQuest(q.questID) end,
        }
    end
    for _, q in ipairs(s.active) do
        rows[#rows + 1] = {
            text = q.title,
            atlas = icons.turnin.atlas, icon = icons.turnin.file, muted = not q.isComplete,
            onClick = live and function() C_GossipInfo.SelectActiveQuest(q.questID) end,
        }
    end
    for _, o in ipairs(s.options) do
        rows[#rows + 1] = {
            text = o.name,
            icon = o.icon or icons.option.file,
            onClick = live and function() C_GossipInfo.SelectOptionByIndex(o.orderIndex) end,
        }
    end

    Chui.Host:Present(owner or self, {
        width = Chui.Theme.tokens.width.gossip,
        title = s.title,
        subtitle = s.subtitle,
        body = s.text,
        rows = rows,
    })
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function Gossip:GOSSIP_SHOW(textureKit)
    local S = Chui.Suppressor
    if not S:ShouldRender("gossip") then return end -- bypassed: Blizzard's window
    local engaged = S:IsEngaged("gossip")
    local t0 = debugprofilestop()

    -- Custom gossip UIs (new-player guide, Torghast level picker...) stay
    -- Blizzard's. When engaged, Blizzard didn't get the event, so forward it.
    if textureKit and CustomGossipFrameManager:GetHandler(textureKit) then
        if engaged then S:Forward("gossip", "GOSSIP_SHOW", textureKit) end
        return
    end

    local state = self:BuildState()
    if self:IsAutoSelect(state) then
        -- In shadow mode Blizzard already did this; don't select twice.
        if engaged then C_GossipInfo.SelectOptionByIndex(state.options[1].orderIndex) end
        return
    end

    self:Render(state)
    Chui:Debug(("gossip render %.2f ms"):format(debugprofilestop() - t0))
end

function Gossip:GOSSIP_CLOSED()
    Chui.Host:Dismiss(self)
end

-- The player closed our panel: end the interaction on the game side too.
function Gossip:OnHostClosed()
    C_GossipInfo.CloseGossip()
end

---------------------------------------------------------------------------
-- Fixture for /chui test (no NPC needed). Uses a stand-in owner so closing
-- the test panel doesn't call CloseGossip().
---------------------------------------------------------------------------
local FIXTURE = {
    title = "Innkeeper Velra",
    subtitle = "Silvermoon City",
    text = table.concat({
        "Welcome, traveler. The fire is warm and the beds are clean.",
        "You look like you have been on the road a long while. Sit, rest, and let me take that pack. "
            .. "We get all kinds through here: couriers from the capital, caravan guards between shifts, "
            .. "the odd scholar chasing a rumour about the old vaults under the hill.",
        "If you are after work, there is always something. The front needs supplies, the stables need "
            .. "hands, and there is a standing bounty on whatever has been scaring the herds at night. "
            .. "Ask around, but mind the prices, and never trust a man who will not sit with his back to the wall.",
        "And if you only want a room, that is easily done. Breakfast is included, the bells are silent "
            .. "until the second hour, and nobody will ask you a single question you do not want to answer.",
    }, "\n\n"),
    available = {
        { title = "A Fresh Start" },
        { title = "The Missing Shipment", isTrivial = true },
        { title = "Whispers in the Vaults" },
    },
    active = {
        { title = "Supplies for the Front", isComplete = true },
        { title = "Herd Trouble", isComplete = false },
    },
    options = {
        { name = "Make this inn your home." },
        { name = "Let me browse your goods." },
        { name = "I'd like to rent a room." },
        { name = "I need to send a letter." },
        { name = "Can you teach me to cook?" },
        { name = "What news from the capital?" },
        { name = "Who else is staying here?" },
        { name = "Tell me about the old vaults." },
        { name = "Where can I find the stable master?" },
        { name = "I'm looking for a guild." },
        { name = "Do you have any rumours?" },
        { name = "I'd like to hear a story." },
        { name = "Show me the way to the market." },
        { name = "Never mind." },
    },
}
local fixtureOwner = {}

function Gossip:ShowFixture()
    local t0 = debugprofilestop()
    self:Render(FIXTURE, fixtureOwner)
    Chui:Debug(("fixture render %.2f ms"):format(debugprofilestop() - t0))
end
