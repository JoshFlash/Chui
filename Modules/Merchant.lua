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

local MAX_LINES = 40
local lines = {}

-- API reads -> plain table, so the real vendor and /chui test merchant share
-- Render. Only the first MAX_LINES items are read; the rest are just counted.
function Merchant:BuildState()
    local count = GetMerchantNumItems()
    local s = {
        title = UnitName("npc") or UNKNOWN,
        money = GetMoney(),
        count = count,
        items = {},
    }
    for i = 1, math.min(count, MAX_LINES) do
        local info = C_MerchantFrame.GetItemInfo(i)
        s.items[i] = {
            name = info and info.name,
            price = info and info.price or 0,
            extended = info and info.hasExtendedCost,
        }
    end
    return s
end

-- `owner` is only passed by the fixture, so closing the test panel doesn't
-- call CloseMerchant().
function Merchant:Render(s, owner)
    local t0 = debugprofilestop()
    wipe(lines)
    for i, item in ipairs(s.items) do
        local cost
        if item.extended then
            cost = Chui.Theme.Paint("muted", "(currency or item cost)")
        else
            cost = GetMoneyString(item.price, true)
        end
        lines[i] = ("%s   %s"):format(item.name or "...", cost)
    end
    if s.count > #s.items then
        lines[#lines + 1] = Chui.Theme.Paint("muted", ("+ %d more"):format(s.count - #s.items))
    end

    Chui.Host:Present(owner or self, {
        width = Chui.Theme.tokens.width.default,
        title = s.title,
        subtitle = ("%d items  -  %s"):format(s.count, GetMoneyString(s.money, true)),
        body = table.concat(lines, "\n"),
    })
    Chui:Debug(("merchant render %.2f ms (%d items)"):format(debugprofilestop() - t0, s.count))
end

function Merchant:MERCHANT_SHOW()
    if not Chui.Suppressor:ShouldRender("merchant") then return end
    self:Render(self:BuildState())
end

-- Item names resolve asynchronously; re-render while our panel is up.
-- (M2 patches rows in place instead of re-rendering.)
function Merchant:MERCHANT_UPDATE()
    if Chui.Host:IsShownFor(self) then self:Render(self:BuildState()) end
end

function Merchant:MERCHANT_CLOSED()
    Chui.Host:Dismiss(self)
end

function Merchant:OnHostClosed()
    CloseMerchant()
end

---------------------------------------------------------------------------
-- Fixture for /chui test merchant: a vendor with more items than fit, so
-- scrolling and the "+ N more" line can be tried without visiting one.
---------------------------------------------------------------------------
local fixtureOwner = {}
local FIXTURE_NAMES = {
    "Linen Cloth", "Silk Thread", "Hearthstone Charm", "Healing Potion", "Mana Potion",
    "Elixir of Fortitude", "Iron Bar", "Mithril Ingot", "Leather Scraps", "Rugged Hide",
    "Ranger's Arrow", "Hunter's Quiver", "Traveler's Tent", "Spiced Jerky", "Honeyed Bread",
    "Wayfarer's Boots", "Scout's Cloak", "Tempered Dagger", "Oak Staff", "Runed Wand",
    "Cracked Shield", "Sturdy Backpack", "Bandage", "Antivenom", "Torch", "Lockpick",
    "Fishing Pole", "Cooking Spices", "Bottle of Ink", "Blank Scroll", "Copper Key",
    "Silver Ring", "Apprentice's Robe", "Journeyman's Gloves", "Recipe: Stew",
    "Pattern: Satchel", "Schematic: Gyro", "Mount Whistle", "Banner of the Vale",
    "Lantern", "Rope", "Grappling Hook", "Flint and Steel", "Waterskin",
    "Bedroll", "Map of the Coast",
}

function Merchant:ShowFixture()
    local items = {}
    for i, name in ipairs(FIXTURE_NAMES) do
        items[i] = { name = name, price = i * 137 + 25, extended = (i % 11 == 0) }
    end
    local shown = {}
    for i = 1, math.min(#items, MAX_LINES) do shown[i] = items[i] end
    self:Render({ title = "Quartermaster Dain", money = 1234567, count = #items, items = shown }, fixtureOwner)
end
