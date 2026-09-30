# Chui

Instant, centered replacement panels for NPC interactions.

## Libraries

Libraries are vendored in `Libs/` and updated by hand from CurseForge. Only what Chui loads is kept:

- `Libs/LibStub/`, `Libs/CallbackHandler-1.0/`, `Libs/AceDB-3.0/`: from the Ace3 release zip

`embeds.xml` loads them in dependency order. AceGUI, AceConfig, AceConsole and AceDBOptions are there for the settings page.

## Settings

Options > AddOns > Chui, or `/chui options`. The page is in `Options/Options.lua`; its options table is only built when the page is first shown.

## Fonts

Fonts live in `Media/Fonts/`. Register each file in `Media/Fonts.lua` (name, path and the locales it covers). Only ship fonts whose licence allows redistribution, and keep the licence file beside the font.
