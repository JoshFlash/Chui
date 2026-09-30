-- Modules/Merchant.lua
-- The vendor panel: every item with its icon, name, stack size and price, a
-- Buyback tab, and the normal vendor controls on each row:
--   right-click          buy one (one stack, as listed)
--   shift-right-click    quantity picker for stackable items
--   left-click           pick the item up (drop it on a bag slot to buy it)
--   shift-click          link the item into the chat box when it is open
--   ctrl-click           preview in the dressing room
--   hover                the item tooltip and the buy cursor (the magnifier
--                        while ctrl is held); your bag items show the sell
--                        cursor while the vendor is open
-- Items that cost currency or other items ask for confirmation first. The
-- quantity picker, link, preview and tooltip are Blizzard's own.
-- Not here yet: the repair and sell-junk buttons.
-- While suppressed you can still sell by right-clicking items in your bags
-- (the server tracks the open merchant, not the frame).
local _, Chui = ...

local Merchant = Chui:NewModule("Merchant")
Merchant.kind = "merchant"
Merchant.events = { "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "PLAYER_MONEY" }

local Paint = Chui.Theme.Paint
local ICON_SIZE = 30
local UNUSABLE_TINT = { 1, 0.3, 0.3 }
local BUY_CURSOR = "Interface/Cursor/Buy.blp"

Merchant.tab = "buy" -- "buy" or "buyback"

---------------------------------------------------------------------------
-- Cursors. Blizzard's bag buttons only show the sell cursor while
-- MerchantFrame is shown, and Chui keeps that frame hidden, so this draws
-- both cursors. It resets the cursor only if it set it, when the tooltip
-- goes away.
---------------------------------------------------------------------------
local cursorOwned = false
local hoveringRow = false

local function ShowBuyCursor()
    if IsModifiedClick("DRESSUP") then ShowInspectCursor() else SetCursor(BUY_CURSOR) end
    cursorOwned = true
    hoveringRow = true
end

if GameTooltip then
    if GameTooltip.SetBagItem and C_Container and C_Container.ShowContainerSellCursor then
        hooksecurefunc(GameTooltip, "SetBagItem", function(_, bag, slot)
            if Chui.Host:IsShownFor(Merchant) then
                C_Container.ShowContainerSellCursor(bag, slot)
                cursorOwned = true
            end
        end)
    end
    GameTooltip:HookScript("OnHide", function()
        hoveringRow = false
        if cursorOwned then
            cursorOwned = false
            ResetCursor()
        end
    end)
end

-- Holding or releasing ctrl while over a row swaps buy cursor and magnifier.
local modifierWatcher = CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent", function()
    if hoveringRow then ShowBuyCursor() end
end)

---------------------------------------------------------------------------
-- State: API reads -> plain table, so the real vendor and /chui test merchant
-- share Render.
---------------------------------------------------------------------------
function Merchant:BuildState()
    local s = { title = UnitName("npc") or UNKNOWN, money = GetMoney(), items = {}, buyback = {} }
    for i = 1, GetMerchantNumItems() do
        local info = C_MerchantFrame.GetItemInfo(i)
        if info then
            local item = {
                index = i,
                name = info.name,
                icon = info.texture,
                price = info.price or 0,
                stack = info.stackCount or 1,
                available = info.numAvailable or -1, -- -1 means unlimited
                usable = info.isUsable ~= false,
                link = GetMerchantItemLink(i),
                costs = {},
            }
            if item.link and C_Item.GetItemQualityByID then
                item.quality = C_Item.GetItemQualityByID(item.link)
            end
            if info.hasExtendedCost then
                for j = 1, GetMerchantItemCostInfo(i) do
                    local texture, value, _, name = GetMerchantItemCostItem(i, j)
                    item.costs[#item.costs + 1] = { texture = texture, value = value, name = name }
                end
            end
            s.items[#s.items + 1] = item
        end
    end
    s.count = #s.items

    for i = 1, GetNumBuybackItems() do
        local name, icon, price, quantity, available, usable = GetBuybackItemInfo(i)
        if name then
            s.buyback[#s.buyback + 1] = {
                index = i, name = name, icon = icon, price = price or 0, stack = quantity or 1,
                available = available or -1, usable = usable ~= false, link = GetBuybackItemLink(i), costs = {},
            }
        end
    end
    return s
end

---------------------------------------------------------------------------
-- View helpers
---------------------------------------------------------------------------
local function ColoredName(item)
    local name = item.name or "..." -- names arrive asynchronously; MERCHANT_UPDATE redraws
    local color = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    if color and color.color then name = color.color:WrapTextInColorCode(name) end
    if item.available and item.available > 0 then
        name = name .. Paint("muted", (" (%d left)"):format(item.available))
    end
    return name
end

-- "1g 50s" plus one "icon count" per currency or item the vendor also wants.
local function CostText(item, playerMoney)
    local parts = {}
    if item.price > 0 then
        local money = GetMoneyString(item.price, true)
        parts[#parts + 1] = item.price > playerMoney and Paint("bad", money) or money
    end
    for _, cost in ipairs(item.costs) do
        local icon = cost.texture and ("|T%s:14:14|t"):format(cost.texture) or ""
        parts[#parts + 1] = icon .. (cost.value or "")
    end
    return table.concat(parts, "  ")
end

StaticPopupDialogs.CHUI_CONFIRM_PURCHASE = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, data) BuyMerchantItem(data.index, data.quantity) end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
}

local function Buy(item, quantity)
    if #item.costs > 0 then
        StaticPopup_Show("CHUI_CONFIRM_PURCHASE",
            ("Buy %s for %s?"):format(item.name or "this item", CostText(item, math.huge)), nil,
            { index = item.index, quantity = quantity })
    else
        BuyMerchantItem(item.index, quantity)
    end
end

-- Blizzard's quantity picker. Current clients have it as a method on
-- StackSplitFrame; older ones as a global function. It calls row:SplitStack.
local function OpenQuantityPicker(maxStack, row, stack)
    if StackSplitFrame and StackSplitFrame.OpenStackSplitFrame then
        StackSplitFrame:OpenStackSplitFrame(maxStack, row, "BOTTOMLEFT", "TOPLEFT", stack)
        return true
    elseif OpenStackSplitFrame then
        OpenStackSplitFrame(maxStack, row, "BOTTOMLEFT", "TOPLEFT", stack)
        return true
    end
    return false
end

-- Same order as Blizzard's merchant buttons: chat-link / dressing-room click
-- first, then the quantity picker, then pick up (left) or buy (right).
local function OnItemClick(item, button, row)
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    if item.link and HandleModifiedItemClick(item.link) then return end
    if IsModifiedClick("SPLITSTACK") then
        local maxStack = GetMerchantItemMaxStack(item.index)
        if item.available > 0 and item.available < maxStack then maxStack = item.available end
        if maxStack > 1 and OpenQuantityPicker(maxStack, row, item.stack) then return end
    end
    if button == "LeftButton" then
        PickupMerchantItem(item.index)
    else
        Buy(item)
    end
end

-- A buyback click buys the item back, whichever button.
local function OnBuybackClick(item, button)
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    if item.link and HandleModifiedItemClick(item.link) then return end
    BuybackItem(item.index)
end

---------------------------------------------------------------------------
-- View: state -> Host content. `owner` is only passed by the fixture, whose
-- rows must not touch the game.
---------------------------------------------------------------------------
local rows = {}

function Merchant:Render(s, owner)
    local t0 = debugprofilestop()
    local live = owner == nil
    local buyback = self.tab == "buyback"
    wipe(rows)

    for _, item in ipairs(buyback and s.buyback or s.items) do
        local row = {
            text = ColoredName(item),
            right = CostText(item, s.money),
            icon = item.icon,
            iconSize = ICON_SIZE,
            count = item.stack,
            tint = not item.usable and UNUSABLE_TINT or nil,
            clicks = "AnyUp",
        }
        if live then
            if buyback then
                row.onClick = function(button) OnBuybackClick(item, button) end
            else
                row.onClick = function(button, frame) OnItemClick(item, button, frame) end
                row.onSplit = function(quantity) Buy(item, quantity) end
            end
            row.tooltip = function(frame)
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                if buyback then
                    GameTooltip:SetBuybackItem(item.index)
                else
                    GameTooltip:SetMerchantItem(item.index)
                end
                ShowBuyCursor()
            end
        else
            row.onClick = function() Chui:Print("test: would buy " .. (item.name or "?")) end
            row.tooltip = function(frame)
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
                GameTooltip:SetText(item.name or "?")
            end
        end
        rows[#rows + 1] = row
    end

    local function SwitchTab(tab)
        if self.tab == tab then return end
        self.tab = tab
        self.resetScroll = true
        if live then self:Render(self:BuildState()) else self:Render(s, owner) end
    end

    local keepScroll = not self.resetScroll
    self.resetScroll = nil
    Chui.Host:Present(owner or self, {
        width = Chui.Theme.tokens.width.default,
        title = s.title,
        subtitle = ("%d items  -  %s"):format(s.count, GetMoneyString(s.money, true)),
        tabs = {
            { text = "Merchant", active = not buyback, onClick = function() SwitchTab("buy") end },
            { text = ("Buyback (%d)"):format(#s.buyback), active = buyback, onClick = function() SwitchTab("buyback") end },
        },
        body = (buyback and #rows == 0) and Paint("muted", "Nothing to buy back.") or nil,
        rows = rows,
        fixedHeight = true, -- same size with few items, many, or on the Buyback tab
        keepScroll = keepScroll, -- buying redraws the list; stay where you were
    })
    Chui:Debug(("merchant render %.2f ms (%d items)"):format(debugprofilestop() - t0, s.count))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function Merchant:MERCHANT_SHOW()
    if not Chui.Suppressor:ShouldRender("merchant") then return end
    self.tab = "buy"
    self:Render(self:BuildState())
end

-- Item names resolve asynchronously and purchases change stock and money, so
-- redraw while our panel is up.
function Merchant:MERCHANT_UPDATE()
    if Chui.Host:IsShownFor(self) then self:Render(self:BuildState()) end
end
Merchant.PLAYER_MONEY = Merchant.MERCHANT_UPDATE

function Merchant:MERCHANT_CLOSED()
    Chui.Host:Dismiss(self)
end

function Merchant:OnHostClosed()
    CloseMerchant()
end

---------------------------------------------------------------------------
-- Fixture for /chui test merchant: a busy vendor, so scrolling, icons, stack
-- sizes, limited stock, currency costs, unaffordable prices and the Buyback
-- tab can all be tried without visiting one. Nothing here touches the game.
---------------------------------------------------------------------------
local fixtureOwner = {}
local FIXTURE = {
    { "Linen Cloth", "INV_Fabric_Linen_01", 1, 20 },
    { "Silk Thread", "INV_Fabric_Silk_01", 1, 5 },
    { "Healing Potion", "INV_Potion_54", 1, 1 },
    { "Mana Potion", "INV_Potion_76", 1, 1 },
    { "Elixir of Fortitude", "INV_Potion_43", 2, 1 },
    { "Iron Bar", "INV_Ingot_Iron", 1, 10 },
    { "Mithril Ingot", "INV_Ingot_03", 2, 10 },
    { "Wayfarer's Boots", "INV_Boots_Cloth_01", 2, 1 },
    { "Scout's Cloak", "INV_Misc_Cape_18", 3, 1 },
    { "Tempered Dagger", "INV_Sword_04", 3, 1 },
    { "Runed Wand", "INV_Wand_07", 4, 1 },
    { "Sturdy Backpack", "INV_Misc_Bag_08", 2, 1 },
    { "Spiced Jerky", "INV_Misc_Food_15", 1, 5 },
    { "Honeyed Bread", "INV_Misc_Food_35", 1, 5 },
    { "Bandage", "INV_Misc_Bandage_15", 1, 20 },
    { "Torch", "INV_Torch_Thrown", 1, 1 },
    { "Lockpick", "INV_Misc_Key_03", 1, 1 },
    { "Fishing Pole", "INV_Fishingpole_01", 1, 1 },
    { "Blank Scroll", "INV_Scroll_05", 1, 5 },
    { "Bottle of Ink", "INV_Misc_Ink_01", 1, 5 },
}

function Merchant:ShowFixture()
    local items = {}
    for i, entry in ipairs(FIXTURE) do
        items[i] = {
            index = i, name = entry[1], icon = "Interface\\Icons\\" .. entry[2],
            quality = entry[3], stack = entry[4], price = i * 173 + 25, available = -1,
            usable = true, costs = {},
        }
    end
    items[3].available = 4                                 -- limited stock
    items[7].usable = false                                -- can't use it
    items[11].price = 9999999                              -- can't afford it
    items[12].price = 0                                    -- costs items, not gold
    items[12].costs = { { texture = "Interface\\Icons\\INV_Misc_Coin_01", value = 15 } }
    for i = #items + 1, 60 do                               -- enough to need scrolling
        items[i] = {
            index = i, name = "Trade Good " .. i, icon = "Interface\\Icons\\INV_Misc_Gear_01",
            quality = 1, stack = 1, price = i * 91, available = -1, usable = true, costs = {},
        }
    end
    local buyback = {
        { index = 1, name = "Worn Sword", icon = "Interface\\Icons\\INV_Sword_01", price = 350, stack = 1, available = -1, usable = true, costs = {} },
        { index = 2, name = "Linen Bandage", icon = "Interface\\Icons\\INV_Misc_Bandage_15", price = 40, stack = 12, available = -1, usable = true, costs = {} },
    }
    self.tab = "buy"
    self:Render({ title = "Quartermaster Dain", money = 1234567, count = #items, items = items, buyback = buyback }, fixtureOwner)
end
