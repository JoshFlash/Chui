-- Core/Host.lua
-- The single shared, centered panel every interaction renders into
-- (Sections 5.1 and 7).
--
-- Three regions: a header (title, subtitle), a body that scrolls when the
-- content is taller than the screen allows, and a footer (primary button).
-- Header and footer never scroll. Sizes and placement come from Core/Layout.lua;
-- this file measures text and owns the frames. Pooled widgets arrive with
-- CHUI-5. The public shape (Present, Dismiss, OnHostClosed) is unchanged.
local _, Chui = ...

local Host = {}
Chui.Host = Host

local T -- theme tokens, bound in Init
local Layout -- Chui.Layout, bound in Init
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
    Layout = Chui.Layout

    -- Named so it can go in UISpecialFrames (Escape closes it).
    local f = CreateFrame("Frame", "ChuiHostFrame", UIParent)
    f:SetFrameStrata("HIGH") -- below DIALOG, so StaticPopups stay on top
    f:SetClampedToScreen(true)
    f:EnableMouse(true)      -- clicks on the panel don't fall through to the world
    f:Hide()

    -- Drag the panel by its background or header. Buttons and rows handle
    -- their own clicks, so they don't start a drag. The new position is saved
    -- in the profile and used for every panel from then on.
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Host:SavePosition()
    end)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(T.surface.base))
    AddPixelBorder(f, unpack(T.edge.accent))

    -- Font objects derived from Blizzard's keep locale glyph coverage correct.
    self.title = f:CreateFontString(nil, "OVERLAY", Chui.Fonts.name.title)
    self.title:SetJustifyH("LEFT")
    self.title:SetTextColor(unpack(T.text.primary))

    self.subtitle = f:CreateFontString(nil, "OVERLAY", Chui.Fonts.name.subtitle)
    self.subtitle:SetJustifyH("LEFT")
    self.subtitle:SetTextColor(unpack(T.text.secondary))

    -- Body: a scroll frame holds the text and the rows. The mouse wheel
    -- scrolls it by one row; a thin indicator on the right shows position.
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) Host:ScrollBy(-delta * T.space.row) end)
    local child = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(child)
    self.scroll, self.child = scroll, child

    local thumb = f:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(T.edge.accent[1], T.edge.accent[2], T.edge.accent[3], 0.6)
    thumb:SetWidth(T.space.scrollbar)
    thumb:Hide()
    self.thumb = thumb

    self.body = child:CreateFontString(nil, "OVERLAY", Chui.Fonts.name.body)
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

    -- Screen size or UI scale changed: lay the open panel out again.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent", function() Host:Refresh() end)

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
        row = CreateFrame("Button", nil, self.child)
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
        local text = row:CreateFontString(nil, "OVERLAY", Chui.Fonts.name.row)
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

-- Lay out content, size to fit, place, show. Synchronous: the panel is
-- complete before this returns (Section 3, "Render on the event").
-- content = { title, subtitle, body, width,
--             rows = { { text, onClick, atlas, icon, muted }, ... } (optional),
--             primary = { text, onClick, enabled } (optional) }
function Host:Present(owner, content)
    local f, child, scroll, cfg = self.frame, self.child, self.scroll, Chui.cfg
    local pad = T.space.pad
    local width = content.width or T.width.default
    local inner = width - 2 * pad
    local unit = PixelUtil.GetPixelToUIUnitFactor() / f:GetEffectiveScale()
    local function snap(v) return Layout.Snap(v, unit) end

    -- Header
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
    local headerH = snap(y + T.space.section)

    -- Body content, laid out from the top of the scroll child
    local body = self.body
    body:SetWidth(inner)
    body:SetText(content.body or "") -- text metrics are available immediately
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    local cy = body:GetStringHeight()

    local rows, used = content.rows, 0
    if rows and #rows > 0 then
        if cy > 0 then cy = cy + T.space.section end
        for i, r in ipairs(rows) do
            local row = self:AcquireRow(i)
            row.text:SetText(r.text)
            ApplyRowIcon(row, r)
            row.action = r.onClick
            row:SetWidth(inner)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -cy)
            row:Show()
            cy = cy + T.space.row
            used = i
        end
    end
    for i = used + 1, #self.rowPool do self.rowPool[i]:Hide() end
    local contentH = snap(cy)

    -- Footer: the primary button, bottom-right, then the bottom padding
    local p, button = content.primary, self.primary
    local footerH = pad
    if p then
        button:SetText(p.text)
        button:SetWidth(math.max(96, button:GetTextWidth() + 32))
        button:SetEnabled(p.enabled ~= false)
        self.primaryAction = p.onClick
        button:Show()
        footerH = footerH + T.space.section + button:GetHeight()
    else
        self.primaryAction = nil
        button:Hide()
    end

    local fit = Layout.Fit({
        header = headerH,
        content = contentH,
        footer = snap(footerH),
        maxHeight = Layout.MaxHeight(UIParent:GetHeight(), cfg.maxHeightPct, T.space.safe),
        minViewport = T.space.row,
    })

    child:SetSize(inner, contentH)
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -headerH)
    scroll:SetSize(inner, fit.viewport)
    scroll:SetVerticalScroll(0)

    self.owner = owner
    self.lastContent = content
    self.fit, self.headerH, self.contentH = fit, headerH, contentH
    self.spaceHeld = IsKeyDown("SPACE") -- a press already down belongs to the previous view
    self:UpdateThumb(0)
    self:Place(width, fit.height)
    f:Show()
end

-- Mouse wheel and friends. Clamped to the scrollable range.
function Host:ScrollBy(delta)
    local fit = self.fit
    if not fit or not fit.scroll then return end
    local target = Layout.Clamp(self.scroll:GetVerticalScroll() + delta, 0, fit.maxScroll)
    self.scroll:SetVerticalScroll(target)
    self:UpdateThumb(target)
end

function Host:UpdateThumb(scrollPos)
    local fit, thumb = self.fit, self.thumb
    if not fit.scroll then
        thumb:Hide()
        return
    end
    local height, offset = Layout.Thumb(fit.viewport, self.contentH, scrollPos, fit.viewport, 16)
    thumb:SetHeight(height)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -(T.space.pad - T.space.scrollbar) / 2, -(self.headerH + offset))
    thumb:Show()
end

-- Where the panel's centre ended up after a drag, as shares of the screen
-- (the same offsetXPct / offsetYPct the default placement uses), saved in the
-- profile. Then re-anchored through Place, which also applies the safe margin.
function Host:SavePosition()
    local f = self.frame
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local layout = Chui.db.layout
    layout.offsetXPct = (cx - ux) / UIParent:GetWidth()
    layout.offsetYPct = (cy - uy) / UIParent:GetHeight()
    Chui.Config:Rebuild()
    self:Place(f:GetWidth(), f:GetHeight())
end

-- Section 7.1: centred on the saved position (default: nudged right and up),
-- kept inside the safe margins. Dragging the panel changes the position.
function Host:Place(width, height)
    local f, cfg = self.frame, Chui.cfg
    local x, y = Layout.Place(UIParent:GetWidth(), UIParent:GetHeight(), width, height, {
        offsetXPct = cfg.offsetXPct, offsetYPct = cfg.offsetYPct, safe = T.space.safe,
    })
    PixelUtil.SetSize(f, width, height)
    f:ClearAllPoints()
    PixelUtil.SetPoint(f, "CENTER", UIParent, "CENTER", x, y)
end

-- Give every piece of Chui text the current face and size of its font
-- object. Text made from a font template can keep the face it was created
-- with, so after a font setting changes this is set on each one explicitly.
function Host:ApplyFonts()
    if not self.frame then return end
    local names = Chui.Fonts.name
    local function sync(fontString, role)
        fontString:SetFont(_G[names[role]]:GetFont())
    end
    sync(self.title, "title")
    sync(self.subtitle, "subtitle")
    sync(self.body, "body")
    for _, row in ipairs(self.rowPool) do sync(row.text, "row") end
end

-- Lay the open panel out again (screen size, UI scale or font changed).
function Host:Refresh()
    if self.frame and self.frame:IsShown() and self.owner and self.lastContent then
        self:Present(self.owner, self.lastContent)
    end
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
