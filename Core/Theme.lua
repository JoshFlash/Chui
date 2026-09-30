-- Core/Theme.lua
-- Design tokens (Section 9.1). Views and the Host read these and never use
-- literal colours or sizes, so alternative themes stay data-only.
-- Colours are {r, g, b, a} in 0..1, converted from the hex values in the doc.
local _, Chui = ...

local Theme = {}
Chui.Theme = Theme

-- Text colours for chat output and in-panel text, by name. WoW colours text
-- with an escape, |cAARRGGBB<text>|r (AA is opacity, always ff here), which is
-- unreadable in code. Use Theme.Paint("accent", "text") instead of writing the
-- escape by hand. `accent` is the same gold as the panel border.
local HEX = {
    accent = "c9a45c", -- gold
    muted  = "9aa3b5", -- secondary text
    dim    = "808080", -- de-emphasised, e.g. trivial quests
    good   = "4fbf6b",
    warn   = "e0b040",
    bad    = "d05a5a",
}

function Theme.Paint(name, text)
    return "|cff" .. HEX[name] .. text .. "|r"
end

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
        safe    = 24, -- minimum gap between the panel and the screen edge
        scrollbar = 3, -- scroll indicator width
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
        offer  = { atlas = "QuestNormal", file = "Interface\\GossipFrame\\AvailableQuestIcon" },
        turnin = { atlas = "QuestTurnin", file = "Interface\\GossipFrame\\ActiveQuestIcon" },
        option = { file = "Interface\\GossipFrame\\GossipGossipIcon" },
    },
    width = {
        default = 480,
        gossip  = 480,
        quest   = 540,
    },
}
