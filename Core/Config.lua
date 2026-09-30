-- Core/Config.lua
-- SavedVariables and slash commands.
--
-- Scaffold version: a plain table with defaults merged in. Unlike AceDB this
-- writes defaults to disk and has no profiles. It is replaced by AceDB-3.0
-- plus the flat Chui.cfg cache in M1 (Section 14.5); keep the shape of
-- `defaults` so the swap is mechanical.
local _, Chui = ...

local Config = {}
Chui.Config = Config

local SCHEMA = 1

local defaults = {
    schema = SCHEMA,
    debug = false,
    modules = {
        Gossip = true,
    },
    layout = {
        offsetX = 400.0,
        offsetYPct = 0.08, -- nudge up 8% of screen height (Section 7.1)
    },
}

local function ApplyDefaults(dst, src)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then dst[key] = {} end
            ApplyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

function Config:Init()
    ChuiDB = ChuiDB or {}
    ApplyDefaults(ChuiDB, defaults)
    Chui.db = ChuiDB
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Help()
    Chui:Print(("v%s"):format(Chui.version))
    print("  /chui test - show the gossip panel with sample data")
    print("  /chui debug - toggle timing and debug output")
    print("  /chui toggle <module> - enable or disable a module (no reload)")
end

SLASH_CHUI1 = "/chui"
SlashCmdList.CHUI = function(msg)
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()

    if cmd == "test" then
        Chui.modules.Gossip:ShowFixture()

    elseif cmd == "debug" then
        Chui.db.debug = not Chui.db.debug
        Chui:Print("debug", Chui.db.debug and "on" or "off")

    elseif cmd == "toggle" then
        local module = Chui:FindModule(arg)
        if not module then
            Chui:Print("unknown module:", arg ~= "" and arg or "(none)")
            return
        end
        if module.enabled then
            Chui:DisableModule(module.name)
        else
            Chui:EnableModule(module.name)
        end
        Chui.db.modules[module.name] = module.enabled
        Chui:Print(module.name, module.enabled and "enabled" or "disabled")

    else
        Help()
    end
end
