-- Dev/FontInfo.lua  (development only; the packager comments it out of releases)
-- /chui fontinfo prints, for each text role, the face and size on the Chui font
-- object and on the live text that uses it. If the object is right but the
-- text is not, the text isn't picking up font changes.
local _, Chui = ...

Chui:RegisterCommand("fontinfo", "dev: print the face and size of each Chui font", function()
    local host = Chui.Host
    local live = {
        title = host.title, subtitle = host.subtitle, body = host.body,
        row = host.rowPool and host.rowPool[1] and host.rowPool[1].text,
    }
    Chui:Print(("profile: face=%s scale=%s"):format(tostring(Chui.db.font.face), tostring(Chui.db.font.scale)))
    for role, name in pairs(Chui.Fonts.name) do
        local objPath, objSize = _G[name]:GetFont()
        local text = live[role]
        local textPath, textSize
        if text then textPath, textSize = text:GetFont() end
        print(("  %-8s object %s %.1f | text %s %s"):format(role, tostring(objPath), objSize or 0,
            tostring(textPath or "(none yet)"), textSize and ("%.1f"):format(textSize) or ""))
    end
end)
