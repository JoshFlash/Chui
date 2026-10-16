-- Dev/PlaceholderArt.lua  (development only; the packager comments it out of releases)
-- Stand-in art while Chui's own is being made. It points at the parchment
-- atlas that ships inside the DialogueUI addon (by Peterodox), which uses the
-- layout Media/Skins.lua describes. Nothing is copied into Chui: the texture is
-- read from that addon's folder, so it only shows while DialogueUI is
-- installed, and it is never part of a release.
--
-- When Chui's own parchment exists, set `file` in Media/Skins.lua and delete
-- this file and its line in Chui.toc.
local _, Chui = ...

local skin = Chui.Media.skins.parchment
if not skin.file then
    skin.file = "Interface\\AddOns\\DialogueUI\\Art\\Theme_Brown\\Parchment.png"
end
