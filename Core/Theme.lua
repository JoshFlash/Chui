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

-- The active skin can swap any of these for colours that read on its
-- background (see Theme.skins below).
function Theme.Paint(name, text)
    local skin = Theme.skins and Theme.skins[Theme.active]
    local hex = (skin and skin.hex and skin.hex[name]) or HEX[name]
    return "|cff" .. hex .. text .. "|r"
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
        tab     = 24, -- height of a header tab button
        edge    = 2,  -- panel border thickness, in physical pixels
        plate   = 44, -- minimum height of the NPC-name plate (art skins)
        plateCap = 42, -- width of each end of the plate
        plateMargin = 10, -- space above and below the name on its plate
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
        quest   = 480,
    },
}

-- Skins: a panel's look. `dark` is the token set above. `parchment` is paper
-- with ink-coloured text; its art comes from Media/Skins.lua, and `surface`
-- (with `edge`) is what is drawn if that art isn't available. A view calls
-- Theme.Use(name) before it builds its text, so Theme.Paint picks colours that
-- read on the skin, and passes skin = name to Host:Present.
Theme.skins = {
    dark = {
        text = Theme.tokens.text,
        surface = Theme.tokens.surface.base,
        edge = Theme.tokens.edge.accent,
        highlight = Theme.tokens.surface.raised,
        selected = { 0.788, 0.643, 0.361, 0.22 }, -- the chosen row, e.g. a quest reward
        thumb = { Theme.tokens.edge.accent[1], Theme.tokens.edge.accent[2], Theme.tokens.edge.accent[3], 0.6 },
    },
    parchment = {
        art = "parchment",
        text = {
            primary   = { 0.15, 0.14, 0.10, 1 }, -- dark ink
            secondary = { 0.38, 0.30, 0.22, 1 },
        },
        surface = { 0.80, 0.68, 0.50, 1 },
        -- Multiplies the paper art's colours: below 1 darkens, and uneven
        -- values shift the hue. This is a warmer, browner paper.
        paperTint = { 0.76, 0.72, 0.67, 0.96 },
        edge = { 0.03, 0.02, 0.01, 0.95 }, -- very dark brown
        edgeWidth = 5, -- the frame the paper is cut off at
        highlight = { 0.72, 0.62, 0.48, 0.24 },
        selected = { 0.42, 0.28, 0.08, 0.28 },
        thumb = { 0.40, 0.28, 0.15, 0.7 },
        hex = {
            accent = "7a4b12", muted = "6b5a44", dim = "8a7c68",
            good = "2f6b3a", warn = "8a5a00", bad = "9a2b2b",
        },
    },
}
Theme.active = "dark"

function Theme.Use(name)
    Theme.active = Theme.skins[name] and name or "dark"
    return Theme.active
end

-- The skin dialogue panels (gossip, quests) use, from the settings.
function Theme.DialogueSkin()
    return Chui.cfg.parchment and "parchment" or "dark"
end
