-- Media/Fonts.lua
-- Fonts Chui ships in Media/Fonts. Data only: add one entry per font file and
-- it appears in Chui's font picker (Chui settings > Appearance).
--
--   key      short unique id stored in the profile (never change it later)
--   name     what the picker shows
--   path     Interface\AddOns\Chui\Media\Fonts\<file>.ttf (or .otf)
--   locales  client locales the font has glyphs for. Leave it out only for a
--            font that covers every script. In any other locale the font is
--            hidden and Chui uses the game's own font, so text never turns
--            into empty boxes. Latin-only fonts: enUS, enGB, deDE, esES,
--            esMX, frFR, itIT, ptBR. Add ruRU only if it has Cyrillic.
--            koKR, zhCN and zhTW need a font with those scripts.
--
-- Only ship fonts whose licence allows redistribution (SIL OFL, for example),
-- and keep each font's licence file next to it in Media/Fonts.
local _, Chui = ...

Chui.Media = Chui.Media or {}

local LATIN = { "enUS", "enGB", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR" }
local LATIN_CYRILLIC = { "enUS", "enGB", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU" }

-- Glyph coverage below was read from each font's character map. See
-- Media/Fonts/NOTICE.txt for who made each font and under what licence.
Chui.Media.fonts = {
    {
        key = "opendyslexic",
        name = "OpenDyslexic",
        path = "Interface\\AddOns\\Chui\\Media\\Fonts\\OpenDyslexic.otf",
        locales = LATIN_CYRILLIC,
    },
    {
        key = "classicabook",
        name = "Classica-Book",
        path = "Interface\\AddOns\\Chui\\Media\\Fonts\\Classica-Book.ttf",
        locales = LATIN,
    },
}
