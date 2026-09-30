-- Core/Config.lua
-- SavedVariables (AceDB-3.0) and slash commands.
--
-- Three layers:
--   Chui.adb   the AceDB object: profiles, plus `global` for data that isn't
--              a setting (schema version, the dev trace log).
--   Chui.db    the active profile table. Views and commands read and write
--              settings here; it is re-pointed whenever the profile changes.
--   Chui.cfg   a flat cache of the hot-path values (read per render or per
--              key event), rebuilt on every profile callback. After changing
--              one of these in Chui.db call Config:Rebuild().
local _, Chui = ...

local Config = {}
Chui.Config = Config

local SCHEMA = 2 -- 1 was the plain-table scaffold (settings at the ChuiDB root)

local defaults = {
    profile = {
        debug = false,
        bypassKey = "SHIFT", -- SHIFT, CTRL, ALT or NONE (Section 6.4)
        modules = {
            Gossip = true,
            Quest = true,
            Merchant = true,
        },
        -- On = Chui owns the interaction and Blizzard's window is hidden. Off =
        -- shadow mode (Chui's panel appears beside Blizzard's).
        suppress = {
            gossip = true,
            quest = true,
            merchant = true,
        },
        layout = {
            offsetX = 400.0,
            offsetYPct = 0.08, -- nudge up 8% of screen height (Section 7.1)
        },
    },
    global = {
        trace = {}, -- Dev: event trace log, readable in SavedVariables after /reload
    },
}

---------------------------------------------------------------------------
-- Schema migration. MIGRATIONS[n] upgrades data from schema n-1 to n and
-- runs once, in order. A fresh install starts at SCHEMA and runs nothing.
---------------------------------------------------------------------------
local MIGRATIONS = {}

-- 1 -> 2: settings moved from the ChuiDB root into the profile. Old
-- `suppress` flags were spike-era opt-ins, so they are dropped and the new
-- defaults (on) apply. The old trace log is dropped too.
MIGRATIONS[2] = function(adb)
    local root, profile = ChuiDB, adb.profile
    if root.debug ~= nil then profile.debug = root.debug end
    if root.bypassKey ~= nil then profile.bypassKey = root.bypassKey end
    for name, on in pairs(root.modules or {}) do profile.modules[name] = on end
    for key, value in pairs(root.layout or {}) do profile.layout[key] = value end
    for _, key in ipairs({ "schema", "debug", "bypassKey", "modules", "suppress", "layout", "trace" }) do
        root[key] = nil
    end
end

local function Migrate(adb)
    local global = adb.global
    if global.schema == nil then
        -- No version yet: either a brand-new install, or schema 1 (plain
        -- table), which carried `schema` at the ChuiDB root.
        global.schema = type(ChuiDB.schema) == "number" and 1 or SCHEMA
    end
    for version = global.schema + 1, SCHEMA do
        if MIGRATIONS[version] then MIGRATIONS[version](adb) end
        global.schema = version
    end
end

---------------------------------------------------------------------------
-- Binding and the flat cache
---------------------------------------------------------------------------
Chui.cfg = Chui.cfg or {}

function Config:Rebuild()
    local p, cfg = Chui.db, Chui.cfg
    cfg.debug = p.debug
    cfg.bypassKey = p.bypassKey
    cfg.offsetX = p.layout.offsetX
    cfg.offsetYPct = p.layout.offsetYPct
end

local function Bind()
    Chui.db = Chui.adb.profile
    Config:Rebuild()
end

-- Profile switched, copied or reset: re-point, then bring modules and
-- suppression in line with the new profile's settings.
function Config:OnProfileChanged()
    Bind()
    for _, name in ipairs(Chui.moduleOrder) do
        if Chui.db.modules[name] ~= false then Chui:EnableModule(name) else Chui:DisableModule(name) end
    end
    Chui.Suppressor:Sync()
end

function Config:Init()
    local adb = LibStub("AceDB-3.0"):New("ChuiDB", defaults, true) -- one shared "Default" profile
    Chui.adb = adb
    Migrate(adb)
    Bind()
    adb.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    adb.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    adb.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
end

-- Back to shipped defaults for the active profile (debug off, every kind
-- suppressed, all modules on). The trace log lives in `global` and stays.
function Config:Reset()
    Chui.adb:ResetProfile()
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
    Chui.Config:Rebuild()
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

Chui:RegisterCommand("suppress-all", "[on|off] - hide Blizzard's window for every kind (no argument: toggle)", function(arg)
    local value = arg:lower()
    local on
    if value == "on" then on = true
    elseif value == "off" then on = false
    elseif value == "" then
        on = false
        for kind in pairs(Chui.db.suppress) do
            if not Chui.db.suppress[kind] then on = true end
        end
    else
        Chui:Print("usage: /chui suppress-all [on|off]")
        return
    end
    for kind in pairs(Chui.db.suppress) do
        Chui.db.suppress[kind] = on
    end
    Chui.Suppressor:Sync()
    Chui:Print("suppress all:", on and "on" or "off", "(applies to each kind when no NPC window is open)")
end)

Chui:RegisterCommand("bypass", "<shift|ctrl|alt|none> - modifier that shows the default window", function(arg)
    local key = arg:upper()
    if key ~= "SHIFT" and key ~= "CTRL" and key ~= "ALT" and key ~= "NONE" then
        Chui:Print("usage: /chui bypass <shift|ctrl|alt|none>")
        return
    end
    Chui.db.bypassKey = key
    Chui.Config:Rebuild()
    Chui:Print("bypass modifier:", key)
end)

Chui:RegisterCommand("reset", "restore default settings (all suppressed, debug off)", function()
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
