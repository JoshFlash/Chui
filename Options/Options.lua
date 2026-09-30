-- Options/Options.lua
-- The settings page: an AceConfig options table shown inside Blizzard's
-- Settings window (Options > AddOns > Chui) and opened by /chui options.
-- It reads and writes the active profile (Chui.db) only.
--
-- The options table is built when the page is first shown, not at load, so
-- the heavy part (AceConfig widgets) costs nothing until someone opens it.
local _, Chui = ...

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local APP = "Chui"
local categoryID

local function FontChoices()
    local values, order = {}, {}
    for i, entry in ipairs(Chui.Fonts:List()) do
        values[entry.key] = entry.name
        order[i] = entry.key
    end
    return values, order
end

-- New text settings take effect at once, including in an open panel.
local function ApplyFont()
    Chui.Fonts:Apply()
    Chui.Host:Refresh()
end

local function Build()
    return {
        type = "group",
        name = "Chui",
        childGroups = "tab",
        args = {
            appearance = {
                type = "group",
                name = "Appearance",
                order = 1,
                args = {
                    font = {
                        type = "select",
                        name = "Font",
                        desc = "The typeface for Chui's panels. Fonts that can't draw your game language are not listed.",
                        order = 1,
                        width = "double",
                        values = function() return (FontChoices()) end,
                        sorting = function() return select(2, FontChoices()) end,
                        get = function() return Chui.db.font.face end,
                        set = function(_, value)
                            Chui.db.font.face = value
                            ApplyFont()
                        end,
                    },
                    scale = {
                        type = "range",
                        name = "Text size",
                        desc = "Scales all panel text.",
                        order = 2,
                        width = "double",
                        min = Chui.Fonts.MIN_SCALE,
                        max = Chui.Fonts.MAX_SCALE,
                        step = 0.05,
                        isPercent = true,
                        get = function() return Chui.db.font.scale end,
                        set = function(_, value)
                            Chui.db.font.scale = value
                            ApplyFont()
                        end,
                    },
                    preview = {
                        type = "execute",
                        name = "Show a sample panel",
                        desc = "Opens a long sample quest so you can judge the font and size.",
                        order = 3,
                        func = function() Chui.modules.Quest:ShowFixture() end,
                    },
                },
            },
            profiles = AceDBOptions:GetOptionsTable(Chui.adb),
        },
    }
end

AceConfig:RegisterOptionsTable(APP, Build)

-- Open the page. Falls back to a standalone window if the Settings API is
-- missing or the page wasn't registered.
function Chui:OpenOptions()
    if categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(categoryID)
    else
        AceConfigDialog:SetDefaultSize(APP, 560, 380)
        AceConfigDialog:Open(APP)
    end
end

Chui:RegisterCommand("options", "open the settings page", function()
    Chui:OpenOptions()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local _, id = AceConfigDialog:AddToBlizOptions(APP, "Chui")
        categoryID = id
    end
    -- A profile change (or reset) from the Profiles tab rewrites the
    -- settings, so redraw the page to match.
    Chui.adb.RegisterCallback(self, "OnProfileChanged", function() AceConfigRegistry:NotifyChange(APP) end)
end)
