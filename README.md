# DreamSuite

All the X08 addons in one. One minimap button opens a single window where every module is an icon: **click** for its settings, **right-click** to switch it on or off.

`/ds` opens the window (`/dreamsuite`, and `/x08` as a shortcut). `/ds minimap` shows or hides the minimap button.

## First start

On a fresh install every module is off and the Install Wizard opens once: one page per module with a short showcase and an Enable / No thanks choice. `/ds wizard` runs it again at any time.

## Install

Copy the `DreamSuite` folder to `Interface\AddOns\`. If you still have the old standalone addons (`GCDDot`, `URLify`, `X08Hub`, ...), type `/ds legacy` once and `/reload`: it switches them off so nothing runs twice, and DreamSuite imports their settings the first time it sees them. Then delete the old folders.

## Modules

| Module | What it does | Command |
|---|---|---|
| BulkBag | Ctrl+click or drag to select several items, click an empty slot to move them all (bags, bank, guild bank). Switched on/off after combat | `/bb` |
| CraftLinker | Answers "craft" whispers with clickable trade-skill links; trigger word, cooldown and messages are in its settings (data is kept per character) | `/craftlink` |
| URLify | Turns chat URLs into clickable links with a copy box | - |
| GCDDot | Movable dot that fills with the GCD, plus a swing timer ring | `/gcd` |
| FadeOut | Fades chosen UI elements out of combat, back in on combat or mouseover | `/fadeout` |
| RarityBorders | Quality-colored borders on bag / bank / character items, optional sparkles, comet trail and holographic shimmer, red tint on unusable items. Works with Bagnon and ElvUI | `/rb` |
| InventoryPlus | Category tabs on your bags: hover to highlight a type, route loot to the right bag, sort, auto-delete cheap junk, ignore list, and a Warehouse of what every character carries. Switched on/off after combat | `/ip` |
| OrbMeter | Orb with your damage / healing per second, a threat ring, hover and raid-lead panels, reports. Registers with FadeOut when both are on | `/om` |

## The window

- **Click** an icon: the module's settings (the window fades into them, **Back** on the right fades back).
- **Right-click**: menu with Turn on / off and Settings.
- **Hover**: description and command.
- **Profile** button (top right): every character has its own settings profile. Use another character's profile or save the current settings to your own.
- **Minimap button**: click opens the hub, right-click gives shortcuts to the modules' settings (and InventoryPlus' Warehouse).
- A red dot on an icon means a problem (old standalone addon still loaded, or the module failed to start).
- Switching a module off makes it fully inert: events unregistered, timers stopped, frames hidden (FadeOut gives every faded frame back at full opacity).
- Modules that touch the secure UI (bags, bank) are switched after combat ends instead of during it.

`/ds list` prints every module's state; `/ds on <module>` and `/ds off <module>` do the same as clicking.

## Updates

WoW's Lua cannot make web requests, so DreamSuite learns about newer versions from other players: everyone running it tells guild, party and raid which version they have (the version number only). If someone has a newer one, the window and the minimap button show a dot, and clicking the notice shows copyable links (direct download, Warperia, GitHub).

Versions are **a.b.c.d**: a = 0 unreleased / 1 released, b = major update, c = minor update, d = fix (no rollover at 9). See `CHANGELOG.md`.

## Folder layout

```
DreamSuite/
  DreamSuite.toc
  Core/      Core.lua  Options.lua
  UI/        Hub.lua   Minimap.lua
  Icons/     Hub.tga, <ModuleId>.tga, dot.tga, star.tga
  Modules/
    BulkBag/      BulkBag.lua
    CraftLinker/  CraftLinker.lua
    URLify/       URLify.lua
    GCDDot/       GCDDot.lua  media/piewheel.tga
    FadeOut/      FadeOut.lua
    OrbMeter/     OrbMeter_core.lua  OrbMeter.lua  media/piewheel.tga
    RarityBorders/ RarityBorders.lua
    InventoryPlus/ Core.lua  Tabs.lua  Warehouse.lua  Options.lua
```

## Adding a module

Put the module in `Modules/<Id>/`, add its file to the `.toc`, and register it:

```lua
local DS = DreamSuite
local M = DS.RegisterModule({
    id = "MyModule", title = "MyModule", desc = "One line for the tooltip",
    slash = { "/mm" },                       -- optional; DreamSuite registers them
    legacy = { folder = "MyModule", db = "MyModuleDB" },   -- the old standalone addon, if there was one
})

function M.OnEnable()  end   -- build frames the first time, register events, show
function M.OnDisable() end   -- unregister events, stop OnUpdates, hide: leave it inert
function M.OnSlash(msg) end  -- only called while the module is on

M.options = function()       -- optional: the settings view
    local db = DS.GetDB("MyModule", { size = 20 })
    return {
        { type = "slider", key = "size", label = "Size", min = 4, max = 64, step = 1, live = true,
          get = function() return db.size end, set = function(v) db.size = v end },
    }
end
```

Settings go in `DS.GetDB(id, defaults)` (stored account-wide in `DreamSuiteDB.data[id]`); use `DS.GetCharDB(id, defaults)` for per-character data (`legacy.perChar = true` imports an old per-character variable the same way). Control types: `bool`, `slider`, `choice`, `color`, `action`, `header`, `text` (see the header of `Core/Options.lua`). A module that builds its own settings view can set `embed = function(parent) ... return frame end` instead. Set `secure = true` on modules that touch protected frames so toggling waits for the end of combat.

Icons: 32-bit TGA, square, 64x64 or 128x128, named `Icons/<ModuleId>.tga`. WoW 3.3.5a cannot load PNG, and a texture added while the game is running only shows after a full client restart.
