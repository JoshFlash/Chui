-- Core/Fonts.lua
-- Chui's font objects and the font picker's data.
--
-- Views never use Blizzard's font objects directly. They use one Chui font
-- object per role (title, subtitle, body, row), each copied from the Blizzard
-- object in Theme.tokens.font and then optionally re-faced and re-sized. Every
-- text that uses a Chui object updates the moment Apply() changes it.
local _, Chui = ...

local Fonts = {}
Chui.Fonts = Fonts

local LATIN = { "enUS", "enGB", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR" }
local LATIN_CYRILLIC = { "enUS", "enGB", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU" }

-- Fonts that ship with the game, so they need no files from us. "default" has
-- no path: it keeps Blizzard's own objects, which the client already switches
-- per locale.
local BUILTIN = {
    { key = "default", name = "Default (game font)" },
    { key = "friz", name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF", locales = LATIN },
    { key = "arialn", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF", locales = LATIN_CYRILLIC },
    { key = "morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF", locales = LATIN },
    { key = "skurri", name = "Skurri", path = "Fonts\\SKURRI.TTF", locales = LATIN },
}

Fonts.MIN_SCALE, Fonts.MAX_SCALE = 0.85, 1.4

-- role -> name of the Chui font object, e.g. title -> "ChuiFontTitle"
Fonts.name = {}
local objects = {}
for role, base in pairs(Chui.Theme.tokens.font) do
    local name = "ChuiFont" .. role:sub(1, 1):upper() .. role:sub(2)
    local object = CreateFont(name)
    object:CopyFontObject(base)
    objects[role] = object
    Fonts.name[role] = name
end

local function SupportsLocale(entry)
    if not entry.locales then return true end
    local locale = GetLocale()
    for _, code in ipairs(entry.locales) do
        if code == locale then return true end
    end
    return false
end

local function Entries()
    local all = {}
    for _, entry in ipairs(BUILTIN) do all[#all + 1] = entry end
    for _, entry in ipairs((Chui.Media and Chui.Media.fonts) or {}) do all[#all + 1] = entry end
    return all
end

-- Fonts the picker offers: the ones that can draw this client's language.
function Fonts:List()
    local list = {}
    for _, entry in ipairs(Entries()) do
        if SupportsLocale(entry) then list[#list + 1] = entry end
    end
    return list
end

function Fonts:Find(key)
    for _, entry in ipairs(self:List()) do
        if entry.key == key then return entry end
    end
end

-- Paths compare equal whatever the slash style or case.
local function Same(a, b)
    local function norm(p) return (tostring(p):lower():gsub("\\", "/")) end
    return norm(a) == norm(b)
end

-- Re-face and re-size every Chui font object from the active profile. An
-- unknown or unsupported face falls back to the game font. Whether a file
-- loaded is judged by the face the object reports afterwards, not by what
-- SetFont returns, since that return value isn't reliable. Returns the path
-- the body font ended up with.
function Fonts:Apply()
    local settings = Chui.db.font
    local entry = self:Find(settings.face)
    local path = entry and entry.path
    local scale = Chui.Layout.Clamp(settings.scale or 1, self.MIN_SCALE, self.MAX_SCALE)
    local failed

    for role, base in pairs(Chui.Theme.tokens.font) do
        local object = objects[role]
        object:CopyFontObject(base)
        local basePath, size, flags = _G[base]:GetFont()
        if path or scale ~= 1 then
            local wanted = path or basePath
            local result = object:SetFont(wanted, size * scale, flags)
            local got = object:GetFont()
            if not Same(got, wanted) then
                -- The file is missing or unreadable: keep the game font.
                failed = failed or ("%s (SetFont returned %s, font is %s)"):format(wanted, tostring(result), tostring(got))
                object:CopyFontObject(base)
                object:SetFont(basePath, size * scale, flags)
            end
        end
    end
    if failed then
        Chui:Print("Couldn't load the font file " .. failed .. ". Using the game font.")
    end

    -- Text that already exists must be told to pick up the new face.
    Chui.Host:ApplyFonts()
    return (objects.body:GetFont())
end

-- /chui font            list the fonts and show which is active
-- /chui font <key>      switch to that font (same as the settings page)
Chui:RegisterCommand("font", "[key] - list fonts, or switch to one", function(arg)
    local key = arg:lower()
    if key == "" then
        local keys = {}
        for _, entry in ipairs(Fonts:List()) do keys[#keys + 1] = entry.key end
        Chui:Print(("font: %s. Available: %s"):format(tostring(Chui.db.font.face), table.concat(keys, ", ")))
        return
    end
    if not Fonts:Find(key) then
        Chui:Print(("No font called %q. /chui font lists them."):format(key))
        return
    end
    Chui.db.font.face = key
    local now = Fonts:Apply()
    Chui.Host:Refresh()
    Chui:Print(("font: %s (now using %s)"):format(key, tostring(now)))
end)
