-- Core/Host.lua
-- The single shared, centered panel every interaction renders into
-- (Sections 5.1 and 7).
--
-- Scaffold version: fixed anatomy (title, subtitle, body text, clickable
-- rows, one primary button, close button) laid out by hand. In M1 this becomes a generic container for module views
-- with header / scrollable body / footer, max-height clamping and pooled
-- widgets. The public shape (Present, Dismiss, OnHostClosed) stays the same.
local _, Chui = ...

local Host = {}
Chui.Host = Host

local T -- theme tokens, bound in Init
local CLOSE_BUTTON_ROOM = 24 -- keeps the title clear of the close button

-- Four 1-pixel edges. PixelUtil snaps to the physical pixel grid for the
-- region's current effective scale. TODO(M1): re-apply on UI_SCALE_CHANGED.
local function AddPixelBorder(frame, r, g, b, a)
    local top = frame:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")

    local bottom = frame:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")

    local left = frame:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")

    local right = frame:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")

    for _, tex in ipairs({ top, bottom, left, right }) do
        tex:SetColorTexture(r, g, b, a)
    end
    PixelUtil.SetHeight(top, 1, 1)
    PixelUtil.SetHeight(bottom, 1, 1)
    PixelUtil.SetWidth(left, 1, 1)
    PixelUtil.SetWidth(right, 1, 1)
end

function Host:Init()
    T = Chui.Theme.tokens

    -- Named so it can go in UISpecialFrames (Escape closes it).
    local f = CreateFrame("Frame", "ChuiHostFrame", UIParent)
    f:SetFrameStrata("HIGH") -- below DIALOG, so StaticPopups stay on top
    f:SetClampedToScreen(true)
    f:EnableMouse(true)      -- clicks on the panel don't fall through to the world
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(T.surface.base))
    AddPixelBorder(f, unpack(T.edge.accent))

    -- Font objects derived from Blizzard's keep locale glyph coverage correct.
    self.title = f:CreateFontString(nil, "OVERLAY", T.font.title)
    self.title:SetJustifyH("LEFT")
    self.title:SetTextColor(unpack(T.text.primary))

    self.subtitle = f:CreateFontString(nil, "OVERLAY", T.font.subtitle)
    self.subtitle:SetJustifyH("LEFT")
    self.subtitle:SetTextColor(unpack(T.text.secondary))

    self.body = f:CreateFontString(nil, "OVERLAY", T.font.body)
    self.body:SetJustifyH("LEFT")
    self.body:SetJustifyV("TOP")
    self.body:SetSpacing(2)
    self.body:SetTextColor(unpack(T.text.primary))

    -- Primary action, always bottom-right (Section 10.1). No click-through
    -- guard yet (M1, Section 11.3): a double-click can hit the next view's
    -- button, so click deliberately while testing.
    local primary = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    primary:SetHeight(24)
    primary:SetPoint("BOTTOMRIGHT", -T.space.pad, T.space.pad)
    primary:SetScript("OnClick", function()
        if Host.primaryAction then Host.primaryAction() end
    end)
    primary:Hide()
    self.primary = primary

    -- Space presses the primary button. Every other key propagates, so
    -- movement, Escape and action bars keep working while the panel is up.
    self.rowPool = {}
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(true)
    f:SetScript("OnKeyDown", function(_, key) Host:OnKeyDown(key) end)
    f:SetScript("OnKeyUp", function(_, key)
        if key == "SPACE" then Host.spaceHeld = false end
    end)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnHide", function() Host:OnHidden() end)
    tinsert(UISpecialFrames, "ChuiHostFrame")

    self.frame = f
end

-- Space activates the primary button when there is one and it is enabled.
-- spaceHeld makes it a fresh-press rule: key repeat, or a press that was
-- already down when this view appeared, does nothing, so one press can't run
-- through several quest steps.
function Host:OnKeyDown(key)
    local f, button = self.frame, self.primary
    if key ~= "SPACE" or not button:IsShown() or not button:IsEnabled() then
        f:SetPropagateKeyboardInput(true)
        return
    end
    f:SetPropagateKeyboardInput(false)
    if self.spaceHeld then return end
    self.spaceHeld = true
    button:Click()
end

function Host:AcquireRow(i)
    local row = self.rowPool[i]
    if not row then
        row = CreateFrame("Button", nil, self.frame)
        row:SetHeight(T.space.row)
        -- A Button's HIGHLIGHT layer draws above OVERLAY text and would cover
        -- it, so the hover tint is a BACKGROUND texture we toggle ourselves.
        local highlight = row:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(unpack(T.surface.raised))
        highlight:Hide()
        row:SetScript("OnEnter", function() highlight:Show() end)
        row:SetScript("OnLeave", function() highlight:Hide() end)
        row:SetScript("OnHide", function() highlight:Hide() end)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(T.space.icon, T.space.icon)
        icon:SetPoint("LEFT", 8, 0)
        row.icon = icon
        local text = row:CreateFontString(nil, "OVERLAY", T.font.row)
        text:SetPoint("RIGHT", -8, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        text:SetTextColor(unpack(T.text.primary))
        row.text = text
        row:SetScript("OnClick", function(self) if self.action then self.action() end end)
        self.rowPool[i] = row
    end
    return row
end

-- Icon for a row: atlas when this client has it, else the file.
local function ApplyRowIcon(row, r)
    local icon, text = row.icon, row.text
    local shown = true
    if r.atlas and C_Texture.GetAtlasInfo(r.atlas) then
        icon:SetAtlas(r.atlas)
    elseif r.icon then
        icon:SetTexture(r.icon)
    else
        shown = false
    end
    icon:SetShown(shown)
    icon:SetDesaturated(r.muted == true)
    text:ClearAllPoints()
    text:SetPoint("LEFT", shown and (8 + T.space.icon + 8) or 8, 0)
    text:SetPoint("RIGHT", -8, 0)
end

-- Lay out content, size to fit, center, show. Synchronous: the panel is
-- complete before this returns (Section 3, "Render on the event").
-- content = { title, subtitle, body, width,
--             rows = { { text, onClick, atlas, icon, muted }, ... } (optional),
--             primary = { text, onClick, enabled } (optional) }
function Host:Present(owner, content)
    local f = self.frame
    local pad = T.space.pad
    local width = content.width or T.width.default
    local inner = width - 2 * pad
    local y = pad

    local title = self.title
    title:SetWidth(inner - CLOSE_BUTTON_ROOM)
    title:SetText(content.title or "")
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -y)
    y = y + title:GetStringHeight()

    local subtitle = self.subtitle
    if content.subtitle and content.subtitle ~= "" then
        y = y + T.space.tight
        subtitle:SetWidth(inner)
        subtitle:SetText(content.subtitle)
        subtitle:ClearAllPoints()
        subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -y)
        subtitle:Show()
        y = y + subtitle:GetStringHeight()
    else
        subtitle:Hide()
    end

    y = y + T.space.section
    local body = self.body
    body:SetWidth(inner)
    body:SetText(content.body or "") -- text metrics are available immediately
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -y)
    y = y + body:GetStringHeight()

    local rows, used = content.rows, 0
    if rows and #rows > 0 then
        y = y + T.space.section
        for i, r in ipairs(rows) do
            local row = self:AcquireRow(i)
            row.text:SetText(r.text)
            ApplyRowIcon(row, r)
            row.action = r.onClick
            row:SetWidth(inner)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -y)
            row:Show()
            y = y + T.space.row
            used = i
        end
    end
    for i = used + 1, #self.rowPool do self.rowPool[i]:Hide() end

    local p, button = content.primary, self.primary
    if p then
        y = y + T.space.section
        button:SetText(p.text)
        button:SetWidth(math.max(96, button:GetTextWidth() + 32))
        button:SetEnabled(p.enabled ~= false)
        self.primaryAction = p.onClick
        button:Show()
        y = y + button:GetHeight()
    else
        self.primaryAction = nil
        button:Hide()
    end
    y = y + pad

    -- TODO(M1): clamp to maxHeightPct and scroll the body beyond it.
    self.owner = owner
    self.spaceHeld = IsKeyDown("SPACE") -- a press already down belongs to the previous view
    self:Place(width, math.ceil(y))
    f:Show()
end

-- Section 7.1, "Center" anchor mode.
function Host:Place(width, height)
    local f, layout = self.frame, Chui.db.layout
    local screenH = UIParent:GetHeight()
    PixelUtil.SetSize(f, width, height)
    f:ClearAllPoints()
    PixelUtil.SetPoint(f, "CENTER", UIParent, "CENTER",
        layout.offsetX, math.floor(screenH * layout.offsetYPct))
end

-- Closing is two-way (Section 5.4):
--   Player closes (close button, Escape) -> OnHide -> owner:OnHostClosed(),
--     which tells the game to end the interaction.
--   Game closes (GOSSIP_CLOSED etc.) -> Dismiss(), which hides the panel
--     WITHOUT calling back, so the two paths can't ping-pong.
function Host:Dismiss(owner)
    if not self.frame or self.owner ~= owner then return end
    self.dismissing = true
    self.frame:Hide()
    self.dismissing = false
end

function Host:OnHidden()
    local owner = self.owner
    self.owner = nil
    if self.dismissing then return end
    if owner and owner.OnHostClosed then
        owner:OnHostClosed()
    end
end

function Host:IsShownFor(owner)
    return self.frame and self.frame:IsShown() and self.owner == owner
end
