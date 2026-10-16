-- Media/Skins.lua
-- Art for panel skins. Data only.
--
-- parchment: one texture atlas, Media/Skins/Parchment.png. The panel shows a
-- crop of the paper's solid middle, cut to the panel's proportions, inside a
-- drawn border. So the sheet's torn edges, curls and shadow are never shown
-- and don't need masking. If the art changes, update the numbers below. All
-- coordinates are pixels on the image's own grid (`size`).
--
--   file      Interface\AddOns\Chui\Media\Skins\Parchment.png. Leave it nil for
--             no art: the panel falls back to a plain tan background. (In
--             development builds Dev/PlaceholderArt.lua fills it in with
--             borrowed art when it is nil.) The PNG needs a transparent
--             background (RGBA) wherever the art doesn't cover the image.
--   size      image width, height
--   paper     {left, right, top, bottom} of the paper's solid middle: a
--             rectangle with no torn edge, dark rim or transparency in it.
--             Larger is better, since more of it can be used on big panels.
--   titlePlate  the strip the NPC's name sits on, {left, right, top, bottom},
--             with `cap` = the width in pixels of each torn end. The ends are
--             kept as they are and the middle stretches to the panel.
local _, Chui = ...

Chui.Media = Chui.Media or {}

Chui.Media.skins = {
    parchment = {
        file = "Interface\\AddOns\\Chui\\Media\\Skins\\Parchment.png",
        size = { 887, 1774 },
        paper = { 160, 810, 80, 890 },
        titlePlate = { 18, 780, 1170, 1260, cap = 80 },
    },
}
