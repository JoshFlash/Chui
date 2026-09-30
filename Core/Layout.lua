-- Core/Layout.lua
-- The layout math, kept pure: numbers in, numbers out, no frames and no WoW
-- API, so it runs (and is tested) outside the game. Host.lua measures text
-- and owns the frames; this file decides sizes, scrolling and placement.
local _, Chui = ...

local Layout = {}
Chui.Layout = Layout

-- Vertical stack: the y offset of each item (top = 0) and the total height.
-- `gap` goes between items, not after the last one.
function Layout.Stack(heights, gap)
    local offsets, y = {}, 0
    for i, h in ipairs(heights) do
        offsets[i] = y
        y = y + h
        if i < #heights then y = y + gap end
    end
    return offsets, y
end

-- Round a size up to a whole physical pixel. `unit` is UI units per pixel.
-- Rounding up means text is never clipped by a sub-pixel. The small epsilon
-- stops float noise (10.000000001) from costing a whole extra pixel.
function Layout.Snap(value, unit)
    if not unit or unit <= 0 then return value end
    return math.ceil(value / unit - 1e-6) * unit
end

function Layout.Clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

-- Tallest the panel may be: a share of the screen, never closer to the top
-- and bottom edges than the safe margin.
function Layout.MaxHeight(screenH, pct, safe)
    return math.min(screenH * pct, screenH - 2 * safe)
end

-- Fit header + content + footer into maxHeight. Content that doesn't fit
-- scrolls inside a viewport; header and footer never scroll.
--   m = { header, content, footer, maxHeight, minViewport (optional),
--         fixedHeight (optional) }
--   -> { height, viewport, scroll, maxScroll }
-- With fixedHeight the panel is always maxHeight tall, however little content
-- there is, so it doesn't change size between views; the body scrolls only
-- when the content is taller than its viewport.
function Layout.Fit(m)
    if m.fixedHeight then
        local viewport = math.max(m.minViewport or 0, m.maxHeight - m.header - m.footer)
        local maxScroll = math.max(0, m.content - viewport)
        return {
            height = m.header + viewport + m.footer,
            viewport = viewport,
            scroll = maxScroll > 0,
            maxScroll = maxScroll,
        }
    end
    local natural = m.header + m.content + m.footer
    if natural <= m.maxHeight then
        return { height = natural, viewport = m.content, scroll = false, maxScroll = 0 }
    end
    local viewport = math.max(m.minViewport or 0, m.maxHeight - m.header - m.footer)
    viewport = math.min(viewport, m.content)
    return {
        height = m.header + viewport + m.footer,
        viewport = viewport,
        scroll = true,
        maxScroll = m.content - viewport,
    }
end

-- Scroll indicator: thumb height and its offset from the top of the track.
function Layout.Thumb(viewport, content, scroll, trackH, minThumb)
    if content <= viewport then return 0, 0 end
    local height = math.max(minThumb or 0, trackH * viewport / content)
    local range = content - viewport
    return height, (trackH - height) * (scroll / range)
end

-- Where the panel goes: offsets from the centre of the screen. The panel's
-- centre sits offsetXPct of the screen width right and offsetYPct of the
-- screen height up, kept `safe` units inside the screen edges. A panel with
-- no room to move on an axis is centred on it.
--   o = { offsetXPct, offsetYPct, safe }  ->  x, y
function Layout.Place(screenW, screenH, w, h, o)
    local limitX = screenW / 2 - o.safe - w / 2
    local x = math.floor(screenW * o.offsetXPct)
    x = limitX < 0 and 0 or Layout.Clamp(x, -limitX, limitX)

    local limitY = screenH / 2 - o.safe - h / 2
    local y = math.floor(screenH * o.offsetYPct)
    y = limitY < 0 and 0 or Layout.Clamp(y, -limitY, limitY)
    return x, y
end
