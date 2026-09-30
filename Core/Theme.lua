-- Core/Theme.lua
-- Design tokens (Section 9.1). Views and the Host read these and never use
-- literal colours or sizes, so alternative themes stay data-only.
-- Colours are {r, g, b, a} in 0..1, converted from the hex values in the doc.
local _, Chui = ...

local Theme = {}
Chui.Theme = Theme

Theme.tokens = {
    surface = {
        base   = { 0.106, 0.122, 0.161, 0.94 }, -- #1B1F29 @ 94%
        raised = { 0.137, 0.161, 0.220, 1 },    -- #232938
    },
    edge = {
        accent = { 0.788, 0.643, 0.361, 1 },    -- #C9A45C
    },
    text = {
        primary   = { 0.914, 0.890, 0.827, 1 }, -- #E9E3D3
        secondary = { 0.604, 0.639, 0.710, 1 }, -- #9AA3B5
    },
    space = {
        unit    = 4,
        tight   = 4,  -- title to subtitle
        section = 12, -- between regions
        pad     = 16, -- panel inner padding
        row     = 34, -- height of a clickable row
        icon    = 24, -- row icon size
    },
    -- Blizzard font objects, so locale glyph coverage stays correct.
    font = {
        title    = "GameFontNormalHuge",
        subtitle = "GameFontHighlight",
        body     = "GameFontHighlightLarge",
        row      = "GameFontHighlightLarge",
    },
    -- Row icons. An atlas is preferred; the file is used when the atlas is
    -- missing on a client. Gossip options bring their own icon file ID.
    icons = {
        offer  = { atlas = "QuestNormal", file = "Interface\GossipFrame\AvailableQuestIcon" },
        turnin = { atlas = "QuestTurnin", file = "Interface\GossipFrame\ActiveQuestIcon" },
        option = { file = "Interface\GossipFrame\GossipGossipIcon" },
    },
    width = {
        default = 480,
        gossip  = 480,
        quest   = 540,
    },
}
