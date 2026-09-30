-- Core/EventBus.lua
-- One hidden event frame for the whole addon (Section 5.1). An event is only
-- registered with the client while at least one enabled module wants it, so
-- a disabled or idle Chui costs nothing.
local _, Chui = ...

local EventBus = {}
Chui.EventBus = EventBus

local frame = CreateFrame("Frame")
local listeners = {} -- [event] = { [module] = true }

function EventBus:Register(module, event)
    local set = listeners[event]
    if not set then
        set = {}
        listeners[event] = set
        frame:RegisterEvent(event)
    end
    set[module] = true
end

function EventBus:Unregister(module, event)
    local set = listeners[event]
    if not set then return end
    set[module] = nil
    if next(set) == nil then
        listeners[event] = nil
        frame:UnregisterEvent(event)
    end
end

function EventBus:UnregisterAll(module)
    -- Setting existing keys to nil during pairs() is allowed in Lua.
    for event, set in pairs(listeners) do
        if set[module] then
            self:Unregister(module, event)
        end
    end
end

-- Dispatch: module:EVENT_NAME(...) inside an error boundary. A failing
-- handler disables only its own module (fail open); other modules and the
-- default UI keep working.
frame:SetScript("OnEvent", function(_, event, ...)
    local set = listeners[event]
    if not set then return end
    for module in pairs(set) do
        local handler = module[event]
        if handler then
            local ok, err = pcall(handler, module, ...)
            if not ok then
                Chui:OnModuleError(module, err)
            end
        end
    end
end)
