-- Modules/Merchant.lua
-- Stub: proves the merchant can be suppressed and closed cleanly.
-- Read-only list of the first items; buying, buyback, repair and the real
-- virtual list arrive in M2. While suppressed you can still sell by
-- right-clicking items in your bags (the server tracks the open merchant,
-- not the frame).
local _, Chui = ...

local Merchant = Chui:NewModule("Merchant")
Merchant.kind = "merchant"
Merchant.events = { "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED" }

local MAX_LINES = 12
local lines = {}

function Merchant:Render()
    local t0 = debugprofilestop()
    wipe(lines)
    local count = GetMerchantNumItems()
    for i = 1, math.min(count, MAX_LINES) do
        local info = C_MerchantFrame.GetItemInfo(i)
        local cost
        if info.hasExtendedCost then
            cost = "|cff9aa3b5(currency or item cost)|r"
        else
            cost = GetMoneyString(info.price, true)
        end
        lines[#lines + 1] = ("%s   %s"):format(info.name or "...", cost)
    end
    if count > MAX_LINES then
        lines[#lines + 1] = ("|cff9aa3b5+ %d more|r"):format(count - MAX_LINES)
    end

    Chui.Host:Present(self, {
        width = Chui.Theme.tokens.width.default,
        title = UnitName("npc"),
        subtitle = ("%d items  -  %s"):format(count, GetMoneyString(GetMoney(), true)),
        body = table.concat(lines, "\n"),
    })
    Chui:Debug(("merchant render %.2f ms (%d items)"):format(debugprofilestop() - t0, count))
end

function Merchant:MERCHANT_SHOW()
    if not Chui.Suppressor:ShouldRender("merchant") then return end
    self:Render()
end

-- Item names resolve asynchronously; re-render while our panel is up.
-- (M2 patches rows in place instead of re-rendering.)
function Merchant:MERCHANT_UPDATE()
    if Chui.Host:IsShownFor(self) then self:Render() end
end

function Merchant:MERCHANT_CLOSED()
    Chui.Host:Dismiss(self)
end

function Merchant:OnHostClosed()
    CloseMerchant()
end
