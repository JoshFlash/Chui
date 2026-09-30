-- Core/Init.lua
-- First file in the TOC. Creates the addon namespace, the module registry
-- and the startup lifecycle.
--
-- Every file listed in the TOC receives the same two varargs: the addon's
-- folder name and a private table shared by all of Chui's files. That table
-- is our namespace; nothing leaks into the global environment except the
-- single `Chui` handle below.
local ADDON_NAME, Chui = ...

_G.Chui = Chui -- lets you /dump Chui in game; later hosts the public API

Chui.name = ADDON_NAME
Chui.modules = {}     -- name -> module table
Chui.moduleOrder = {} -- registration order, so enabling is deterministic
Chui.commands = {}    -- "/chui <name>" -> { fn = function(arg), help = "..." }
Chui.cfg = {}         -- flat settings cache, filled by Core/Config.lua

do
    local v = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    -- An unpackaged dev checkout still contains the packager token.
    Chui.version = (v and not v:find("^@")) and v or "dev"
end

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------
-- Theme loads after this file, so the prefix is built when it is first needed.
local prefix
local function Prefix()
    prefix = prefix or Chui.Theme.Paint("accent", "Chui") .. ":"
    return prefix
end

function Chui:Print(...)
    print(Prefix(), ...)
end

function Chui:Debug(...)
    if self.cfg.debug then
        print(Prefix(), Chui.Theme.Paint("muted", "[debug]"), ...)
    end
end

-- Any file (including Dev/ files) can add a slash subcommand.
function Chui:RegisterCommand(name, help, fn)
    self.commands[name] = { help = help, fn = fn }
end

---------------------------------------------------------------------------
-- Modules
-- A module is a plain table with:
--   .kind        suppression kind it owns ("gossip", "quest", ...), optional
--   .events      list of event names it needs while enabled
--   :EVENT_NAME  a method per event (dispatched by Core.EventBus)
--   :OnEnable / :OnDisable   optional
--   :OnHostClosed            optional; the player closed the panel
---------------------------------------------------------------------------
function Chui:NewModule(name)
    assert(not self.modules[name], "Chui: duplicate module " .. name)
    local module = { name = name, enabled = false }
    self.modules[name] = module
    table.insert(self.moduleOrder, name)
    return module
end

function Chui:FindModule(name)
    if not name then return nil end
    name = name:lower()
    for key, module in pairs(self.modules) do
        if key:lower() == name then return module end
    end
end

function Chui:EnableModule(name)
    local module = self.modules[name]
    if not module or module.enabled then return end
    module.enabled = true
    for _, event in ipairs(module.events or {}) do
        self.EventBus:Register(module, event)
    end
    if module.kind then self.Suppressor:SetModuleActive(module.kind, true) end
    if module.OnEnable then module:OnEnable() end
    self:Debug("enabled", name)
end

function Chui:DisableModule(name)
    local module = self.modules[name]
    if not module or not module.enabled then return end
    module.enabled = false
    self.EventBus:UnregisterAll(module)
    self.Host:Dismiss(module) -- hide our panel without ending the interaction
    -- Hand the interaction type back to Blizzard immediately, even mid-interaction.
    if module.kind then self.Suppressor:SetModuleActive(module.kind, false) end
    if module.OnDisable then module:OnDisable() end
    self:Debug("disabled", name)
end

-- Error boundary target (Section 3, "Fail open"). A module that throws is
-- switched off, suppression for its kind is released, and the event that
-- failed is replayed to Blizzard's frame so the default window appears now
-- rather than on the next interaction. The error still reaches BugSack.
function Chui:OnModuleError(module, err, event, ...)
    -- Only replay if Blizzard really missed the event. In shadow mode (or a
    -- bypassed interaction) its frame already received it.
    local missed = module.kind and self.Suppressor:IsEngaged(module.kind)
    self:DisableModule(module.name)
    if missed and event then
        self.Suppressor:Replay(module.kind, event, ...)
    end
    if not module.errorReported then
        module.errorReported = true
        self:Print(("The %s module hit an error and was switched off until /reload."):format(module.name))
    end
    geterrorhandler()(err)
end

---------------------------------------------------------------------------
-- Startup lifecycle
-- These events fire after every file in the TOC has loaded, so the
-- handlers can safely use Config, Host and the modules defined later.
---------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")
        Chui.Config:Init() -- SavedVariables (ChuiDB) exist from this point

    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        Chui.Host:Init()
        Chui.Suppressor:Init()
        for _, name in ipairs(Chui.moduleOrder) do
            if Chui.db.modules[name] ~= false then
                Chui:EnableModule(name)
            end
        end
        Chui:Debug("loaded", Chui.version)
    end
end)
