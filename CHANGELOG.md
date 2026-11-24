# DreamSuite changelog

## Version numbers

`a.b.c.d`

- **a**: 0 = unreleased, 1 = released
- **b**: major updates
- **c**: minor updates and smaller additions
- **d**: fixes, one tick per fix

Numbers don't roll over at 9 (`0.4.3.106` is fine). Every change below is tallied here; the files themselves carry no change notes.

## 0.11.41.45 (2026-11-24 22:21)
- c: InventoryPlus: the Suggested setup follows the number of bags you carry. No extra bags, no suggestion. With 1 extra bag the backpack takes everything and the bag takes Crafting; 2 bags: backpack Quest, Reagents, Gear, Weapons and Misc, Crafting, then Consumables, Conjured, Raw Food and Junk; 3 and 4 bags split it further. The button's tooltip shows what you would get
- c: DreamScore: hover the score on the character window to see the stat priority of your spec (weights, hit and defense caps)
- c: DreamScore: hit caps are separate for melee, ranged and spell (spell hit needs 26.23 rating per 1%, melee and ranged 32.79; caps 8%, 8% and 17%). Enhancement shamans also cast: hit past the melee cap still counts half up to about 14% spell hit
- c: DreamScore: when a buff with "Hardcore" in its name is seen, a window asks once per character whether stamina should count higher and by how much (/dscore hardcore opens it again). ChromieCraft documents no such buff, so the name match is a guess
- c: DreamScore weights checked against more sources: WoWSims default EP weights, Wowhead and 2010 Engadget guides. Where they disagreed with the weights they were adjusted (Fury, Frost and Unholy DK, Blood, Protection paladin, bear, Resto druid crit and others); the Specs tab lists the sources per spec. Resto druid no longer counts healing power on top of spell power
- c: CraftLinker: the materials whisper also says how many crafts the bank and your other characters' stock would cover (from the InventoryPlus Warehouse)

## 0.11.40.45 (2026-11-24 11:40)
- c: DreamScore weights re-checked against Icy Veins and Warcraft Tavern pages for all classes (the guide each spec rests on is listed in the Specs tab). Corrected where the order disagreed with the guides: Arms and Fury put armor penetration higher, Fury and Frost DK expertise/hit higher, Protection warrior/paladin and Blood DK defensive stats re-ordered, Holy paladin haste and mp5 above spell power, Enhancement intellect/spell power above crit, Shadow, Fire, Frost mages: spirit above intellect, Elemental haste, Restoration shaman haste/mp5/crit, bear dodge lowered. Arms, Combat and Restoration shaman sources now say plainly that only Icy Veins was read
- d: DreamScore showed some stats under their internal names (RESISTANCE0_NAME for armor). All weighted stats now have readable names in the Specs tab, /dscore weights and /dscore audit

## 0.11.39.44 (2026-11-23 00:53)
- c: DreamScore counts effects that come and go: a Use: effect that grants a stat for a while (\"Increases your attack power by 278 for 20 sec, 2 Min Cooldown\") and procs whose tooltip gives their chance and cooldown or procs per minute are turned into the average amount of that stat (amount x seconds it lasts / seconds between uses or procs) and weighed like a normal stat. Mana restores count as mana per 5 sec. Healing and damage effects, and procs without numbers, stay uncounted. Switch: Count Use: and proc effects (Scoring tab)

## 0.11.38.44 (2026-11-23 00:40)
- c: DreamScore settings are split into three tabs: General, Scoring and Specs. The weights of every class and spec are now the Specs tab (/dscore specs still opens them in a window). Settings pages can hold a custom view for this
- c: DreamScore: Hardcore is one tick that doubles the stamina weight of your spec (at least 0.20 for specs that hardly value it); the separate stamina slider is gone
- d: DreamScore settings: the hit cap buttons got shorter names and the layout no longer overlaps

## 0.11.37.44 (2026-11-23 00:16)
- c: DreamScore has its new icon
- c: DreamScore: "Show all specs and their weights" (settings, or /dscore specs) opens a window with every class and spec, the weights per stat, and the guides they come from listed at the bottom
- c: DreamScore: Hardcore option: stamina is worth at least a chosen share (default 40%) of the main stat for every spec, because it is not all about damage
- c: DreamScore: set bonuses that are plain stat grants now count. A bonus is split over the pieces it takes (a 2-piece bonus half to each of its two pieces, a 3-piece bonus a third to each of three), so the piece you look at and the pieces you wear share it
- c: DreamScore: hit and defense caps. Hit rating counts in full up to the cap and at a reduced value past it (same level mobs, boss level mobs, or white hit for dual wielders; casters use spell hit), defense up to 540. What you have is read from the game, so gear, gems, buffs and talents are included. Settings: cap mode and how much a point keeps past the cap
- c: DreamScore: /dscore audit lists, per worn item, what is read (gems, enchants, socket bonus, set bonus), what the spec does not value and which tooltip lines it cannot read
- c: DreamScore: the (!) hint also looks at your bank and guild bank, as they were on your last visit (a guild bank tab counts once you have opened it); the tooltip says where the item is and clicking does not swap those

## 0.11.36.44 (2026-11-21 00:45)
- d: Warlock soul shard limit: a shard that landed loose in a normal bag because the soul bag was full is now destroyed first, instead of a shard from the soul bag's first slot leaving a stray one behind. Soul bags themselves are untouched by bag tab rules, as before

## 0.11.36.43 (2026-11-19 01:17)
- d: Right-clicking a character in the Warehouse overview now opens a small dropdown menu with "Clear character" (which asks to confirm)

## 0.11.36.42 (2026-11-17 02:43)
- c: InventoryPlus Warehouse: right-click a character in the overview to clear that character's stored data (asks first; only the Warehouse record is removed)

## 0.11.35.42 (2026-11-15 20:42)
- c: InventoryPlus auto-delete: the "whole stack" value comparison is gone (it did not work and would need stack limits per item); the limit is now always per item. New switches for grey items and for white items, each with its own "worth less than" box (white defaults to off, 50c), and the sub-options grey out when auto-delete is off. Quest items, the ignore list and anything not freshly looted are still never touched

## 0.11.34.42 (2026-11-15 20:35)
- c: DreamScore tells bear Feral Druids from cat ones by their talents (more ranks in Protector of the Pack, Natural Reaction, Primal Gore and Thick Hide than in Shredding Attacks, Predatory Strikes, Predatory Instincts and Savage Fury = bear) and uses the bear weights (stamina, armor, dodge, expertise) for a bear build; the spec shows as "Feral (bear)" or "Feral (cat)"

## 0.11.33.42 (2026-11-15 20:30)
- d: DreamScore now counts gem, enchant and socket-bonus lines for every stat, not only caster ones (attack power, strength, agility, stamina, hit, expertise, armor penetration, defense, dodge, parry, block, armor), so e.g. +24 Attack Power on bracers is no longer ignored. "All Stats" now covers all five primary stats

## 0.11.33.41 (2026-11-12 02:38)
- d: The setup wizard's DreamScore preview was drawn under its own panel and looked dim; the text now sits on top, in full brightness

## 0.11.33.40 (2026-11-12 01:41)
- d: DreamScore settles faster after logging in: the spec, the upgrade hints and the total are re-checked every second for 10 seconds after login, a loading screen, or a talent change

## 0.11.33.39 (2026-11-12 01:03)
- d: The DreamScore total on the character window moved 2 px down

## 0.11.33.38 (2026-11-12 01:02)
- d: The DreamScore total on the character window moved 10 px back up

## 0.11.33.37 (2026-11-12 01:01)
- d: The DreamScore total on the character window sits 20 px lower and 4 px further right, in the middle of the black space

## 0.11.33.36 (2026-11-12 01:00)
- d: The DreamScore total on the character window is centred in the free space beside the weapon slots

## 0.11.33.35 (2026-11-12 00:59)
- d: The DreamScore total on the character window moved up to the weapon row, clear of the frame edge and tabs

## 0.11.33.34 (2026-11-12 00:56)
- d: The DreamScore total on the character window was drawn underneath the window's artwork and so not visible; it now sits above it

## 0.11.33.33 (2026-11-12 00:53)
- c: DreamScore: option to score trinkets and relics/idols by item level (their effects can't be valued by stats), and an option to show your total DreamScore on the character window, under the trinkets beside the weapon slots (both in the DreamScore panel)
- d: The tooltip line now reads "DreamScore: (Restoration) 200"; the setup wizard's DreamScore preview is lighter and easier to read

## 0.11.32.33 (2026-11-11 23:05)
- c: DreamScore now covers every class: weights for all 27 specs (Warrior, Paladin, Hunter, Rogue, Priest, Death Knight, Shaman, Mage, Warlock, Druid), taken from the WotLK stat priorities of Icy Veins, Warcraft Tavern and similar guides, converted to numbers by judgment (weapon DPS values are estimates; Death Knight Blood is treated as the tank tree; Feral uses cat weights). Weights follow your talents: with no points the three specs of your class are averaged, every point in your main tree moves towards that spec, and 31 points make it 100%. The tooltip shows e.g. "(Restoration 32%)" while blending and `/dscore weights` explains it

## 0.11.31.33 (2026-11-11 00:39)

- c: DreamScore: effects of meta gems can be worked out into stats by hand (`DS.DreamScore.GEM_EFFECTS`, matched by gem name). First entry: Insightful Earthsiege Diamond = 60 mp5 (600 mana per proc, 15 s cooldown, about 60 mp5 measured)
- d: Restoration Druid weights: mp5 lowered from 2.0 to 0.5 (IcyVeins is the outlier; Warcraft Tavern, Espway and WotLK Helper rank it last or treat it as a 700+ target)

## 0.11.30.32 (2026-11-10 12:42)

- d: DreamScore tooltip: the item you are wearing shows only its score (no "+0% vs worn"); the line no longer repeats the class ("DreamScore (Restoration)")

## 0.11.30.31 (2026-11-10 12:39)

- d: DreamScore: gems were not counted (a gem's stats are an enchantment, not item stats). Gem and enchant stats are now read from the item's tooltip (the lines the item has beyond its bare version), so socketed gems and enchants such as "+8 All Stats" count. An item with matching gems and an enchant now beats the same item bare

## 0.11.30.30 (2026-11-10 12:25)

- c: DreamScore counts socketed gems and active socket bonuses. The item's own stats are read with the gems taken out of the link, then each gem's stats are added (so nothing is counted twice whichever way GetItemStats behaves); empty sockets still get the credit from the options; an active socket bonus is read from the item's tooltip (English clients). Enchants are not counted yet. Scores are cached per item link
- d: Item scores are not cached while a gem's data is still loading

## 0.11.29.29 (2026-11-10 01:50)

- d: DreamScore upgrade hint: also reacts to UNIT_INVENTORY_CHANGED, re-detects the spec if it was unavailable, and `/dscore upgrades` now lists every equippable bag item with the reason it did or did not count (level, armor type, unreadable stats, score vs worn)

## 0.11.29.28 (2026-11-10 01:41)

- c: The upgrade hint moved from InventoryPlus to DreamScore and now compares by DreamScore instead of item level: a (!) on a character slot when a bag item is at least 1% better for your spec (and wearable at your level), hover shows it, click swaps. `/dscore upgrades` explains each slot. The InventoryPlus option and `/ip upgrades` are gone
- d: Wizard: the OrbMeter preview's threat ring sweeps visibly (drawn like the real orb: ring below, core above); DPS stays between about 700 and 1500 with calmer movement and the real "1.1K" number format

## 0.11.28.27 (2026-11-10 01:08)

- b: DreamScore, a new module: every item gets a score for your class and spec (its stats valued by the spec's stat priority) shown on the tooltip with how it compares to the item you wear in that slot (`/dscore`, `/dscore weights`). Items with procs or Use: effects are marked "effect not counted". First spec: Restoration Druid (weights from the IcyVeins WotLK Classic stat priority; edit them in `DS.DreamScore.SPECS`)
- c: Wizard page and hub row for DreamScore
- d: Hub rows slightly shorter so nine modules fit in the window

## 0.10.27.26 (2026-11-09 19:41)

- c: InventoryPlus Warehouse: picking a category or sub-category crossfades the list; hovering one in the tree keeps its items bright and dims the rest
- c: InventoryPlus: the suggested setup now makes one tab per bag holding all of that bag's categories (instead of several tabs per bag)
- d: InventoryPlus Organize page: "Follow the server's speed" sits under the speed slider; "Organize all now" and "Sort tabbed bags" are in the bottom row on the right
- d: Wizard: the InventoryPlus page says tabs can be dragged onto each other to merge them; hint is written "(!)"
- d: Thank-you page: new opening paragraph and a closing line "And to you for using this addon. Thank you."; layout moved down to fit

## 0.10.27.25 (2026-11-09 01:44)

- d: Change log: back to the first layout (a scroll frame with one text block per release) after reports of memory trouble; dates and tags are kept. New `/ds memory` prints DreamSuite's memory use

## 0.10.27.24 (2026-11-09 01:38)

- c: Change log: each release shows the date and time it was made (grey, in parentheses; times are Dutch local time and are only known from 0.10.27.13 onwards); the major / minor / fix tags are now bold-looking capitals (WoW cannot mix bold into one text block)

## 0.10.27.23 (2026-11-09 01:34)

- d: Change log: rebuilt on a scrolling message frame (the list came up empty); underline under the version removed, the gold hover stays

## 0.10.27.22 (2026-11-09 01:32)

- c: Change log in the hub: click the version in the bottom left to scroll through every change, newest first, each tagged major / minor / fix (Esc or the X closes it). The version has a broken underline that lights up gold on hover. The list is generated from CHANGELOG.md into Core/Changelog.lua (`gen_changelog.py`)

## 0.10.27.21 (2026-11-09 01:24)

- d: InventoryPlus upgrade hint: dark glow removed (it covered the slot); the "(!)" keeps its thick outline

## 0.10.27.20 (2026-11-09 01:19)

- d: InventoryPlus upgrade hint: shadow centered (no offset drop shadow; a soft dark glow sits evenly behind the text)

## 0.10.27.19 (2026-11-09 01:17)

- d: InventoryPlus upgrade hint: heavier shadow (thick outline plus a 2 px drop shadow)

## 0.10.27.18 (2026-11-09 01:16)

- d: InventoryPlus upgrade hint: now a yellow "(!)" in a slightly smaller font (tooltip line yellow too)

## 0.10.27.17 (2026-11-09 01:11)

- d: InventoryPlus upgrade hint: larger outlined "!" drawn on a higher strata; bags are rescanned every few seconds while the character window is open (item data can arrive late); errors are printed instead of swallowed; `/ip upgrades` lists each slot and why it has or lacks a hint

## 0.10.27.16 (2026-11-08 21:16)

- d: Wizard: title reads "DreamSuite Setup"; RarityBorders preview caption no longer mentions sparkles
- d: Wizard: "Skip Setup" capitalized; RarityBorders preview caption no longer mentions the sparkles

## 0.10.27.15 (2026-11-08 21:04)

- d: Thank-you page: Adrenis removed; new line "and everyone else, including the former <Blades of Wrynn> guild on Turtle WoW (Tel'Abim-PvP)"; Void is now a druid

## 0.10.27.14 (2026-11-08 20:58)

- c: Thank-you page redone: fully opaque and covering the whole window; animated clouds, twinkling drifting stars, pulsing logo halo, "Thank You" as a waving letter-by-letter title with a sweeping shine, names fading in one by one in class colors, a pulsing gold border
- c: Added Rachnor, Desblade and Adrenis; classes: Sapphine/Void hunter, Soul warlock, Mack/Rachnor paladin, Luna mage, Desblade priest (Adrenis has none yet, shown gold; set `{ "Adrenis", "CLASS" }` in `DS.THANKS`). Thanks to Lea (orange) and Ori (tabby) added
- d: Wizard: in the GCDDot preview only the left dot flashes; the right one shows just the swing ring

## 0.10.27.13 (2026-11-08 20:25)

- b: Easter egg: click the X08 logo in the hub three times for a thank-you page (names live in `DS.THANKS`; click or Esc closes it)
- c: InventoryPlus: upgrade hint. A small OrangeRed "!" in the top-left of a character-window slot when your bags hold a better piece (same armor type as what you wear, higher item level, required level reached; armor, neck, cloak, rings, trinkets; no weapons). Hover shows the item, click swaps it in. Option "Upgrade hint (!) on the character window" on the General page
- c: Wizard: RarityBorders preview now shows the sparkles too; the InventoryPlus page mentions the hint
- c: Wizard window fades out when it is closed or finished
- d: Wizard: GCDDot swing-timer preview rebuilt with the same layering as the real dot (ring below, dot above)
- d: Wizard: URLify text reads "you have to type it out manually"

## 0.9.26.13 (unreleased)

- b: Install Wizard. On a fresh install every module starts switched off and a small setup window opens once, with one page per module: what it does, a live showcase (RarityBorders shows items with and without borders side by side; GCDDot, FadeOut, OrbMeter and the BB button animate; URLify, CraftLinker and InventoryPlus show mock-ups) and Enable / No thanks. Each choice applies at once, so it can be closed at any moment. `/ds wizard` (or "Setup wizard" in the minimap menu) runs it again. Existing installs are left as they are

## 0.8.26.13 (unreleased)

- b: InventoryPlus: loose partial stacks are consolidated. Sorting and organizing merge them first (the largest stack collects, the smallest empties first), and a quiet check does the same inside every bag about 1.5 s after things settle (not in combat, not while you are moving items). Switch it off with "Merge loose stacks automatically" on the General page; sorting always merges

## 0.7.26.13 (unreleased)

- b: BulkBag: a settings menu. "Always on (legacy)" keeps selecting switched on at all times, as in the standalone addon (Ctrl+click then also previews items); "Hide the BB button" removes the button, available in legacy mode only

## 0.6.26.13 (unreleased)

- c: BulkBag: while on, the BB button itself glows: it slowly fades from its normal look to a warm yellow/orange and back (about 2 s per cycle), instead of turning white

## 0.6.25.13 (unreleased)

- d: BulkBag: the BB button rendered black (desaturating the button texture fails on some graphics cards); it now gets a solid white layer with its own dark label
- d: CraftLinker: materials always show real item links, also for recipes cached by an older version (a link is built from the item id when none is stored)
- c: CraftLinker: the "short" wording is gone; each material shows what you have (bank in brackets) and, from InventoryPlus' Warehouse, what your other characters hold ("alts: Name 12")

## 0.6.25.11 (unreleased)

- c: CraftLinker: the materials answer shows real item links (the crafted item and each material), at most three links per whisper. Recipes cached by an older version are refreshed the next time the profession window opens
- c: BulkBag: the BB button is plain white while on; the icy glow and sparkles are gone

## 0.6.24.10 (unreleased)

- b: CraftLinker: whisper an item you can craft, or its recipe link, and it answers with the materials needed and how many of each are in your bags (plus what waits in the bank). Recipes are remembered whenever you open a profession window. Switch on the Messages tab ("Answer item and recipe links with materials")
- c: InventoryPlus: "Clear All Rules" button at the bottom right of the Tabs page, with a confirmation box; removes every tab of the character
- c: BulkBag: icy effect on the BB button while it is on: a pulsing frost glow around it and sparkles twinkling on it

## 0.5.24.10 (unreleased)

- c: BulkBag: the BB button turns entirely blue while on (the button itself is tinted, instead of a blue layer over it)

## 0.5.23.10 (unreleased)

- d: OrbMeter: the centering fix moved the number down; it is nudged to the right instead (the digit sat slightly left), the vertical position is back as it was

## 0.5.23.9 (unreleased)

- b: BulkBag: a "BB" button on the backpack, next to Sort All, switches selecting on (it turns blue). While it is on, Ctrl+click and Ctrl+drag select items and Ctrl+click no longer previews them; while it is off, BulkBag does nothing and Ctrl+click previews as usual. `/bb on|off|toggle` does the same

## 0.4.23.9 (unreleased)

- b: InventoryPlus: "Fill from the bottom" per tab. Items of that tab are stored and sorted from the last slot of the bag upwards; another tab on the same bag can fill from the top
- b: InventoryPlus: dragging a tab onto another tab asks to merge them into one new tab, with an optional name
- c: InventoryPlus: the add/edit tab screen was reworked: tighter rows, no scrolling, sub-categories open on a screen of their own with the same crossfade, and single sub-categories can be unticked while the rest stay ticked ("2/5" shows on the category row)
- c: CraftLinker: no more chat line for every cache update; one line when a crafting window closes, saying what was recorded (skill points gained, recipes added). Can be switched off
- c: InventoryPlus: the Suggested setup button sits at the bottom of the Tabs page
- d: InventoryPlus: the suggested setup is no longer applied by itself on a character without tabs
- d: OrbMeter: the number in the orb sits centered (the digits sat slightly high in the font's line box)

## 0.3.23.9 (unreleased)

- c: InventoryPlus: the bag column settings moved to the Advanced tab, behind a "Manual bag layout" switch (off = Blizzard's own layout, nothing is touched)
- c: InventoryPlus: Anchor setting, "Blizzard's own" or "Bottom right of the screen" (every open bag is re-anchored to the bottom right corner at the spot Blizzard gave it)

## 0.3.22.9 (unreleased)

- c: InventoryPlus: two sliders replace the "Leave room between bag columns" checkbox. "Extra space per bag column" (0 to 80 px, horizontal only) moves each new column that many pixels further out, the first column stays where Blizzard puts it. "Column width" overrides Blizzard's column spacing with a fixed pitch (150 to 400 px, or Blizzard's own). Old "off" becomes a gap of 0
- d: InventoryPlus: columns are grouped by Blizzard's own position (4 px tolerance), so a third column can't be missed or shifted twice

## 0.3.21.8 (unreleased)

- d: InventoryPlus: bags that Blizzard places individually (cascade layout) were shifted further with every extra bag opened; columns are now worked out from where the bags actually sit, so bags in one column shift together

## 0.3.21.7 (unreleased)

- c: InventoryPlus: "Follow the server's speed" (default on): the pause between moves is the measured time the server needs to answer, and backs off when it refuses or drops something; off = the slider's fixed pause
- c: InventoryPlus: "Sort All" button above the first row of the backpack (routes items and sorts every tabbed bag); can be switched off in the options
- d: InventoryPlus: a sort that stalls (locked slot that never frees, item stuck on the cursor, no server answer for 10 s) is abandoned with a chat message instead of locking up
- d: InventoryPlus: bag columns no longer drift or overlap when bags open and close; the shift is applied from Blizzard's own position every time, and once more a frame later

## 0.3.19.4 (unreleased)

- c: InventoryPlus: adding or editing a bag rule inside the hub opens the picker within the DreamSuite window (no popup); Esc closes just the picker
- c: InventoryPlus: "Suggested setup" button and automatic first-time setup for characters without tabs (B1 Quests, Reagents + Hearthstone locked on slot 1; B2 Gear/Weapons, Misc; B3 Crafting; B4 Consumables, Conjured; B5 Raw Food, Junk)
- c: InventoryPlus: sorting speed slider (pause per move, 0.05 to 0.8 s)
- c: InventoryPlus: Warehouse uses the full width of the window
- c: hub row shows both `/inventoryplus` and `/ip`
- c: GCDDot sits in the background strata, behind Blizzard frames
- d: GCDDot: no flash at startup; the flash is timer-driven so it can't get stuck on the bloom
- d: CraftLinker: the "nothing cached" message is a framed, wrapping box instead of one long line

## 0.3.15.2 (unreleased)

- b (major): settings profiles. Every character has a profile of its own; the button at the top of the hub lists them. Pick another character's profile to use it (asks first, reloads the UI; what you had stays in the profile you leave), or "Save current settings to <this character>" to fork the current settings into your own. Collected data (the InventoryPlus warehouse, CraftLinker's cached links, per-character bag tabs) is not part of a profile
- c: GCDDot hands its opacity to FadeOut ("GCD Dot" in FadeOut's DreamSuite tab); "Hide out of combat" applies when FadeOut is off or the dot is unticked there
- c: opening a module puts its logo and name in the header in place of DreamSuite; the module's own title row is gone, so the settings get more room
- c: narrower window (880 -> 800 px), settings columns narrowed to match
- c: new module order: URLify, BulkBag, then the rest
- c: the hub fades in and out (also on Esc and the close button)
- c: the minimap button's right-click menu: Open DreamSuite, a settings shortcut for every enabled module, plus extras a module offers (InventoryPlus: Warehouse)
- c: CraftLinker takes several trigger words, separated by commas
- c: tab changes: the old page fades out, then the new one fades in (no overlap, slightly slower)
- d: the CraftLinker "nothing cached" box is wide enough for the message
- d: the profile and other settings are written back at logout

## 0.2.8.1

- b (major): CraftLinker gets a settings menu (General: reply switch, trigger word, cooldown; Messages: text sent when nothing is cached; Cache: clear all, list of cached professions)
- c: the settings engine can build text boxes (`type = "edit"`), usable by any module

## 0.1.8.1

- c: modules without settings show a small red "No menu available" in their row

## 0.1.7.1

- c: Enabled / Disabled is a switch: a bordered box on the row, click it to enable or disable
- c: the red blink now lights up the whole row instead of a glow around the icon
- d: Back button raised so it sits centred in the footer space

## 0.1.5.0

- b (major): module list replaces the icon grid: small icon, description, command and status per row
- c: tab changes fade out / in
- c: left-click on a module without settings, or a disabled one, blinks a faint red glow around its icon
- c: "on / off" is now "enabled / disabled" everywhere (menu, tooltips, status, chat messages, `/ds enable|disable <module>`; `/ds on|off` still works)
- c: Back button moved to the bottom-right of the settings page, without the arrow
- c: the "8 of 8" counter in the header is gone

## 0.0.0.0 - starting point

Everything below is the baseline the counter starts from.

**Modules** (ported from the standalone addons, which are no longer developed)
- BulkBag, CraftLinker, URLify, GCDDot, FadeOut, OrbMeter, RarityBorders, InventoryPlus
- Craftmatic, MobScanner and AutoAspect are not part of the suite

**Hub**
- Left-click an icon opens that module's settings; right-click opens the menu with Turn on / Turn off and Settings
- Divider under the logo and name, divider above the footer
- Back button on the right
- Version numbers removed from the icons and tooltips; the suite version sits in the footer
- Own icon for InventoryPlus
- Update notice comes from other players running a newer version (guild / party / raid), compared as `a.b.c.d`

**Settings**
- Shared widgets in `UI/Widgets.lua` (divider, button, checkbox, tab strip); the generated settings and InventoryPlus use them
- Tab-style sub-menus: GCDDot, OrbMeter, RarityBorders, FadeOut, InventoryPlus
- FadeOut has its own "DreamSuite addons" tab for the suite's own frames
