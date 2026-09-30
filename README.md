# Chui

Instant, centered replacement panels for NPC interactions.

## Libraries

Libraries are vendored in `Libs/` and updated by hand from CurseForge. Only what Chui loads is kept:

- `Libs/LibStub/`, `Libs/CallbackHandler-1.0/`, `Libs/AceDB-3.0/`: from the Ace3 release zip

`embeds.xml` loads them in dependency order. The options libraries (AceConfig, AceGUI, AceDBOptions, AceConsole) go with the load-on-demand Chui_Options addon.
