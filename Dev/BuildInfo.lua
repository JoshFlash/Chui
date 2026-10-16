-- Dev/BuildInfo.lua  (development only; the packager comments it out of releases)
-- /chui build prints the game client's version, build and interface number, so
-- the `## Interface:` line in Chui.toc can be checked against it. The number
-- to have in that line is the last value printed here.
local _, Chui = ...

Chui:RegisterCommand("build", "dev: print the client's version and interface number", function()
    local version, build, date, interface = GetBuildInfo()
    Chui:Print(("client %s (build %s, %s), interface %s"):format(
        tostring(version), tostring(build), tostring(date), tostring(interface)))
    Chui:Print("Chui.toc must list that interface number. If the AddOns list marks Chui out of date, it doesn't.")
end)
