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
    bypassKey = "SHIFT", -- SHIFT, CTRL, ALT or NONE (Section 6.4)
    modules = {
        Gossip = true,
        Quest = true,
        Merchant = true,
    },
    -- Spike: suppression is opt-in per kind. Off = shadow mode (Chui's panel
    -- appears beside Blizzard's). Becomes default-on once M1 panels are usable.
    suppress = {
        gossip = false,
        quest = false,
        merchant = false,
    },
    layout = {
        offsetX = 400.0,
        offsetYPct = 0.08, -- nudge up 8% of screen height (Section 7.1)
    },
    trace = {}, -- Dev: event trace log, readable in SavedVariables after /reload
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

-- Back to shipped defaults (debug off, every kind in shadow mode, all modules
-- on), keeping the trace log. Used to undo a spike/test session.
function Config:Reset()
    local db = Chui.db
    for key in pairs(db) do
        if key ~= "trace" then db[key] = nil end
    end
    ApplyDefaults(db, defaults)
    for _, name in ipairs(Chui.moduleOrder) do
        if db.modules[name] ~= false then Chui:EnableModule(name) else Chui:DisableModule(name) end
    end
    Chui.Suppressor:Sync()
end

---------------------------------------------------------------------------
-- Slash commands. Subcommands live in Chui.commands so any file (Dev/
-- tools included) can add its own with Chui:RegisterCommand.
---------------------------------------------------------------------------
Chui:RegisterCommand("test", "show the gossip panel with sample data", function()
    Chui.modules.Gossip:ShowFixture()
end)

Chui:RegisterCommand("debug", "toggle timing and debug output", function()
    Chui.db.debug = not Chui.db.debug
    Chui:Print("debug", Chui.db.debug and "on" or "off")
end)

Chui:RegisterCommand("toggle", "<module> - enable or disable a module (no reload)", function(arg)
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
end)

Chui:RegisterCommand("suppress", "<gossip|quest|merchant> [on|off] - hide Blizzard's window for that kind", function(arg)
    local kind, value = arg:lower():match("^(%S*)%s*(%S*)$")
    if not Chui.Suppressor:IsKnownKind(kind) then
        Chui:Print("usage: /chui suppress <gossip|quest|merchant> [on|off]")
        return
    end
    local on
    if value == "on" then on = true
    elseif value == "off" then on = false
    else on = not Chui.db.suppress[kind] end
    Chui.db.suppress[kind] = on
    Chui.Suppressor:Sync()
    Chui:Print(("suppress %s: %s%s"):format(kind, on and "on" or "off",
        Chui.Suppressor:IsEngaged(kind) == on and "" or " (applies when no NPC window is open)"))
end)

Chui:RegisterCommand("bypass", "<shift|ctrl|alt|none> - modifier that shows the default window", function(arg)
    local key = arg:upper()
    if key ~= "SHIFT" and key ~= "CTRL" and key ~= "ALT" and key ~= "NONE" then
        Chui:Print("usage: /chui bypass <shift|ctrl|alt|none>")
        return
    end
    Chui.db.bypassKey = key
    Chui:Print("bypass modifier:", key)
end)

Chui:RegisterCommand("reset", "restore default settings (shadow mode, debug off)", function()
    Chui.Config:Reset()
    Chui:Print("settings reset to defaults")
end)

Chui:RegisterCommand("status", "show suppression state", function()
    Chui.Suppressor:PrintStatus()
end)

local function Help()
    Chui:Print(("v%s"):format(Chui.version))
    local names = {}
    for name in pairs(Chui.commands) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        print(("  /chui %s - %s"):format(name, Chui.commands[name].help))
    end
end

SLASH_CHUI1 = "/chui"
SlashCmdList.CHUI = function(msg)
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local command = Chui.commands[cmd:lower()]
    if command then
        command.fn(arg)
    else
        Help()
    end
end
