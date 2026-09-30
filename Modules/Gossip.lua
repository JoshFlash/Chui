-- Modules/Gossip.lua
-- Scaffold gossip module, running in "shadow mode": Blizzard's GossipFrame
-- still appears and still does the work. Chui shows a read-only centered
-- copy beside it. This proves the event -> state -> render -> present
-- pipeline end to end without suppressing anything yet.
--
-- Next steps (M0/M1): suppress GossipFrame (Strategy A), make rows clickable
-- (SelectOption / SelectAvailableQuest / SelectActiveQuest), confirm and
-- code-entry rows, number keys, the click guard.
local _, Chui = ...

local Gossip = Chui:NewModule("Gossip")
Gossip.events = { "GOSSIP_SHOW", "GOSSIP_CLOSED" }

local GOLD, GREY = "|cffffd100", "|cff808080"

---------------------------------------------------------------------------
-- State: API reads -> plain table (Section 3, "State in, pixels out")
---------------------------------------------------------------------------
Gossip.state = {}

function Gossip:BuildState()
    local s = self.state
    s.title = UnitName("npc") or UNKNOWN
    s.subtitle = GetMinimapZoneText()
    s.text = C_GossipInfo.GetText() or ""
    s.available = C_GossipInfo.GetAvailableQuests()
    s.active = C_GossipInfo.GetActiveQuests()
    s.options = C_GossipInfo.GetOptions()
    table.sort(s.options, function(a, b)
        return (a.orderIndex or 0) < (b.orderIndex or 0)
    end)
    return s
end

---------------------------------------------------------------------------
-- View: state -> Host content. Pure function of the state table, so the
-- /chui test fixture renders exactly like a real NPC.
---------------------------------------------------------------------------
local buf = {}

function Gossip:Render(s, owner)
    wipe(buf)
    if s.text ~= "" then
        buf[#buf + 1] = s.text
        buf[#buf + 1] = ""
    end

    local n = 0
    for _, q in ipairs(s.available) do
        n = n + 1
        local color = q.isTrivial and GREY or ""
        buf[#buf + 1] = ("%d.  %s!|r  %s%s|r"):format(n, GOLD, color, q.title)
    end
    for _, q in ipairs(s.active) do
        n = n + 1
        local icon = q.isComplete and GOLD or GREY
        buf[#buf + 1] = ("%d.  %s?|r  %s"):format(n, icon, q.title)
    end
    for _, o in ipairs(s.options) do
        n = n + 1
        buf[#buf + 1] = ("%d.  %s"):format(n, o.name)
    end

    Chui.Host:Present(owner or self, {
        width = Chui.Theme.tokens.width.gossip,
        title = s.title,
        subtitle = s.subtitle,
        body = table.concat(buf, "\n"),
    })
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function Gossip:GOSSIP_SHOW()
    local t0 = debugprofilestop()
    self:Render(self:BuildState())
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
    text = "Welcome, traveler. The fire is warm and the beds are clean.",
    available = { { title = "A Fresh Start" } },
    active = { { title = "Supplies for the Front", isComplete = true } },
    options = {
        { name = "Make this inn your home." },
        { name = "Let me browse your goods." },
        { name = "I'd like to rent a room." },
    },
}
local fixtureOwner = {}

function Gossip:ShowFixture()
    local t0 = debugprofilestop()
    self:Render(FIXTURE, fixtureOwner)
    Chui:Debug(("fixture render %.2f ms"):format(debugprofilestop() - t0))
end
