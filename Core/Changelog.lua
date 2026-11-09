-- generated from CHANGELOG.md by gen_changelog.py; do not edit by hand
local DS = DreamSuite
DS.CHANGELOG = {
  { ver = "0.10.27.26", date = "2026-11-09 19:41", items = {
    { "c", "InventoryPlus Warehouse: picking a category or sub-category crossfades the list; hovering one in the tree keeps its items bright and dims the rest" },
    { "c", "InventoryPlus: the suggested setup now makes one tab per bag holding all of that bag's categories (instead of several tabs per bag)" },
    { "d", "InventoryPlus Organize page: \"Follow the server's speed\" sits under the speed slider; \"Organize all now\" and \"Sort tabbed bags\" are in the bottom row on the right" },
    { "d", "Wizard: the InventoryPlus page says tabs can be dragged onto each other to merge them; hint is written \"(!)\"" },
    { "d", "Thank-you page: new opening paragraph and a closing line \"And to you for using this addon. Thank you.\"; layout moved down to fit" },
  } },
  { ver = "0.10.27.25", date = "2026-11-09 01:44", items = {
    { "d", "Change log: back to the first layout (a scroll frame with one text block per release) after reports of memory trouble; dates and tags are kept. New /ds memory prints DreamSuite's memory use" },
  } },
  { ver = "0.10.27.24", date = "2026-11-09 01:38", items = {
    { "c", "Change log: each release shows the date and time it was made (grey, in parentheses; times are Dutch local time and are only known from 0.10.27.13 onwards); the major / minor / fix tags are now bold-looking capitals (WoW cannot mix bold into one text block)" },
  } },
  { ver = "0.10.27.23", date = "2026-11-09 01:34", items = {
    { "d", "Change log: rebuilt on a scrolling message frame (the list came up empty); underline under the version removed, the gold hover stays" },
  } },
  { ver = "0.10.27.22", date = "2026-11-09 01:32", items = {
    { "c", "Change log in the hub: click the version in the bottom left to scroll through every change, newest first, each tagged major / minor / fix (Esc or the X closes it). The version has a broken underline that lights up gold on hover. The list is generated from CHANGELOG.md into Core/Changelog.lua (gen_changelog.py)" },
  } },
  { ver = "0.10.27.21", date = "2026-11-09 01:24", items = {
    { "d", "InventoryPlus upgrade hint: dark glow removed (it covered the slot); the \"(!)\" keeps its thick outline" },
  } },
  { ver = "0.10.27.20", date = "2026-11-09 01:19", items = {
    { "d", "InventoryPlus upgrade hint: shadow centered (no offset drop shadow; a soft dark glow sits evenly behind the text)" },
  } },
  { ver = "0.10.27.19", date = "2026-11-09 01:17", items = {
    { "d", "InventoryPlus upgrade hint: heavier shadow (thick outline plus a 2 px drop shadow)" },
  } },
  { ver = "0.10.27.18", date = "2026-11-09 01:16", items = {
    { "d", "InventoryPlus upgrade hint: now a yellow \"(!)\" in a slightly smaller font (tooltip line yellow too)" },
  } },
  { ver = "0.10.27.17", date = "2026-11-09 01:11", items = {
    { "d", "InventoryPlus upgrade hint: larger outlined \"!\" drawn on a higher strata; bags are rescanned every few seconds while the character window is open (item data can arrive late); errors are printed instead of swallowed; /ip upgrades lists each slot and why it has or lacks a hint" },
  } },
  { ver = "0.10.27.16", date = "2026-11-08 21:16", items = {
    { "d", "Wizard: title reads \"DreamSuite Setup\"; RarityBorders preview caption no longer mentions sparkles" },
    { "d", "Wizard: \"Skip Setup\" capitalized; RarityBorders preview caption no longer mentions the sparkles" },
  } },
  { ver = "0.10.27.15", date = "2026-11-08 21:04", items = {
    { "d", "Thank-you page: Adrenis removed; new line \"and everyone else, including the former <Blades of Wrynn> guild on Turtle WoW (Tel'Abim-PvP)\"; Void is now a druid" },
  } },
  { ver = "0.10.27.14", date = "2026-11-08 20:58", items = {
    { "c", "Thank-you page redone: fully opaque and covering the whole window; animated clouds, twinkling drifting stars, pulsing logo halo, \"Thank You\" as a waving letter-by-letter title with a sweeping shine, names fading in one by one in class colors, a pulsing gold border" },
    { "c", "Added Rachnor, Desblade and Adrenis; classes: Sapphine/Void hunter, Soul warlock, Mack/Rachnor paladin, Luna mage, Desblade priest (Adrenis has none yet, shown gold; set { \"Adrenis\", \"CLASS\" } in DS.THANKS). Thanks to Lea (orange) and Ori (tabby) added" },
    { "d", "Wizard: in the GCDDot preview only the left dot flashes; the right one shows just the swing ring" },
  } },
  { ver = "0.10.27.13", date = "2026-11-08 20:25", items = {
    { "b", "Easter egg: click the X08 logo in the hub three times for a thank-you page (names live in DS.THANKS; click or Esc closes it)" },
    { "c", "InventoryPlus: upgrade hint. A small OrangeRed \"!\" in the top-left of a character-window slot when your bags hold a better piece (same armor type as what you wear, higher item level, required level reached; armor, neck, cloak, rings, trinkets; no weapons). Hover shows the item, click swaps it in. Option \"Upgrade hint (!) on the character window\" on the General page" },
    { "c", "Wizard: RarityBorders preview now shows the sparkles too; the InventoryPlus page mentions the hint" },
    { "c", "Wizard window fades out when it is closed or finished" },
    { "d", "Wizard: GCDDot swing-timer preview rebuilt with the same layering as the real dot (ring below, dot above)" },
    { "d", "Wizard: URLify text reads \"you have to type it out manually\"" },
  } },
  { ver = "0.9.26.13", date = "", items = {
    { "b", "Install Wizard. On a fresh install every module starts switched off and a small setup window opens once, with one page per module: what it does, a live showcase (RarityBorders shows items with and without borders side by side; GCDDot, FadeOut, OrbMeter and the BB button animate; URLify, CraftLinker and InventoryPlus show mock-ups) and Enable / No thanks. Each choice applies at once, so it can be closed at any moment. /ds wizard (or \"Setup wizard\" in the minimap menu) runs it again. Existing installs are left as they are" },
  } },
  { ver = "0.8.26.13", date = "", items = {
    { "b", "InventoryPlus: loose partial stacks are consolidated. Sorting and organizing merge them first (the largest stack collects, the smallest empties first), and a quiet check does the same inside every bag about 1.5 s after things settle (not in combat, not while you are moving items). Switch it off with \"Merge loose stacks automatically\" on the General page; sorting always merges" },
  } },
  { ver = "0.7.26.13", date = "", items = {
    { "b", "BulkBag: a settings menu. \"Always on (legacy)\" keeps selecting switched on at all times, as in the standalone addon (Ctrl+click then also previews items); \"Hide the BB button\" removes the button, available in legacy mode only" },
  } },
  { ver = "0.6.26.13", date = "", items = {
    { "c", "BulkBag: while on, the BB button itself glows: it slowly fades from its normal look to a warm yellow/orange and back (about 2 s per cycle), instead of turning white" },
  } },
  { ver = "0.6.25.13", date = "", items = {
    { "d", "BulkBag: the BB button rendered black (desaturating the button texture fails on some graphics cards); it now gets a solid white layer with its own dark label" },
    { "d", "CraftLinker: materials always show real item links, also for recipes cached by an older version (a link is built from the item id when none is stored)" },
    { "c", "CraftLinker: the \"short\" wording is gone; each material shows what you have (bank in brackets) and, from InventoryPlus' Warehouse, what your other characters hold (\"alts: Name 12\")" },
  } },
  { ver = "0.6.25.11", date = "", items = {
    { "c", "CraftLinker: the materials answer shows real item links (the crafted item and each material), at most three links per whisper. Recipes cached by an older version are refreshed the next time the profession window opens" },
    { "c", "BulkBag: the BB button is plain white while on; the icy glow and sparkles are gone" },
  } },
  { ver = "0.6.24.10", date = "", items = {
    { "b", "CraftLinker: whisper an item you can craft, or its recipe link, and it answers with the materials needed and how many of each are in your bags (plus what waits in the bank). Recipes are remembered whenever you open a profession window. Switch on the Messages tab (\"Answer item and recipe links with materials\")" },
    { "c", "InventoryPlus: \"Clear All Rules\" button at the bottom right of the Tabs page, with a confirmation box; removes every tab of the character" },
    { "c", "BulkBag: icy effect on the BB button while it is on: a pulsing frost glow around it and sparkles twinkling on it" },
  } },
  { ver = "0.5.24.10", date = "", items = {
    { "c", "BulkBag: the BB button turns entirely blue while on (the button itself is tinted, instead of a blue layer over it)" },
  } },
  { ver = "0.5.23.10", date = "", items = {
    { "d", "OrbMeter: the centering fix moved the number down; it is nudged to the right instead (the digit sat slightly left), the vertical position is back as it was" },
  } },
  { ver = "0.5.23.9", date = "", items = {
    { "b", "BulkBag: a \"BB\" button on the backpack, next to Sort All, switches selecting on (it turns blue). While it is on, Ctrl+click and Ctrl+drag select items and Ctrl+click no longer previews them; while it is off, BulkBag does nothing and Ctrl+click previews as usual. /bb on||off||toggle does the same" },
  } },
  { ver = "0.4.23.9", date = "", items = {
    { "b", "InventoryPlus: \"Fill from the bottom\" per tab. Items of that tab are stored and sorted from the last slot of the bag upwards; another tab on the same bag can fill from the top" },
    { "b", "InventoryPlus: dragging a tab onto another tab asks to merge them into one new tab, with an optional name" },
    { "c", "InventoryPlus: the add/edit tab screen was reworked: tighter rows, no scrolling, sub-categories open on a screen of their own with the same crossfade, and single sub-categories can be unticked while the rest stay ticked (\"2/5\" shows on the category row)" },
    { "c", "CraftLinker: no more chat line for every cache update; one line when a crafting window closes, saying what was recorded (skill points gained, recipes added). Can be switched off" },
    { "c", "InventoryPlus: the Suggested setup button sits at the bottom of the Tabs page" },
    { "d", "InventoryPlus: the suggested setup is no longer applied by itself on a character without tabs" },
    { "d", "OrbMeter: the number in the orb sits centered (the digits sat slightly high in the font's line box)" },
  } },
  { ver = "0.3.23.9", date = "", items = {
    { "c", "InventoryPlus: the bag column settings moved to the Advanced tab, behind a \"Manual bag layout\" switch (off = Blizzard's own layout, nothing is touched)" },
    { "c", "InventoryPlus: Anchor setting, \"Blizzard's own\" or \"Bottom right of the screen\" (every open bag is re-anchored to the bottom right corner at the spot Blizzard gave it)" },
  } },
  { ver = "0.3.22.9", date = "", items = {
    { "c", "InventoryPlus: two sliders replace the \"Leave room between bag columns\" checkbox. \"Extra space per bag column\" (0 to 80 px, horizontal only) moves each new column that many pixels further out, the first column stays where Blizzard puts it. \"Column width\" overrides Blizzard's column spacing with a fixed pitch (150 to 400 px, or Blizzard's own). Old \"off\" becomes a gap of 0" },
    { "d", "InventoryPlus: columns are grouped by Blizzard's own position (4 px tolerance), so a third column can't be missed or shifted twice" },
  } },
  { ver = "0.3.21.8", date = "", items = {
    { "d", "InventoryPlus: bags that Blizzard places individually (cascade layout) were shifted further with every extra bag opened; columns are now worked out from where the bags actually sit, so bags in one column shift together" },
  } },
  { ver = "0.3.21.7", date = "", items = {
    { "c", "InventoryPlus: \"Follow the server's speed\" (default on): the pause between moves is the measured time the server needs to answer, and backs off when it refuses or drops something; off = the slider's fixed pause" },
    { "c", "InventoryPlus: \"Sort All\" button above the first row of the backpack (routes items and sorts every tabbed bag); can be switched off in the options" },
    { "d", "InventoryPlus: a sort that stalls (locked slot that never frees, item stuck on the cursor, no server answer for 10 s) is abandoned with a chat message instead of locking up" },
    { "d", "InventoryPlus: bag columns no longer drift or overlap when bags open and close; the shift is applied from Blizzard's own position every time, and once more a frame later" },
  } },
  { ver = "0.3.19.4", date = "", items = {
    { "c", "InventoryPlus: adding or editing a bag rule inside the hub opens the picker within the DreamSuite window (no popup); Esc closes just the picker" },
    { "c", "InventoryPlus: \"Suggested setup\" button and automatic first-time setup for characters without tabs (B1 Quests, Reagents + Hearthstone locked on slot 1; B2 Gear/Weapons, Misc; B3 Crafting; B4 Consumables, Conjured; B5 Raw Food, Junk)" },
    { "c", "InventoryPlus: sorting speed slider (pause per move, 0.05 to 0.8 s)" },
    { "c", "InventoryPlus: Warehouse uses the full width of the window" },
    { "c", "hub row shows both /inventoryplus and /ip" },
    { "c", "GCDDot sits in the background strata, behind Blizzard frames" },
    { "d", "GCDDot: no flash at startup; the flash is timer-driven so it can't get stuck on the bloom" },
    { "d", "CraftLinker: the \"nothing cached\" message is a framed, wrapping box instead of one long line" },
  } },
  { ver = "0.3.15.2", date = "", items = {
    { "c", "b (major): settings profiles. Every character has a profile of its own; the button at the top of the hub lists them. Pick another character's profile to use it (asks first, reloads the UI; what you had stays in the profile you leave), or \"Save current settings to <this character>\" to fork the current settings into your own. Collected data (the InventoryPlus warehouse, CraftLinker's cached links, per-character bag tabs) is not part of a profile" },
    { "c", "GCDDot hands its opacity to FadeOut (\"GCD Dot\" in FadeOut's DreamSuite tab); \"Hide out of combat\" applies when FadeOut is off or the dot is unticked there" },
    { "c", "opening a module puts its logo and name in the header in place of DreamSuite; the module's own title row is gone, so the settings get more room" },
    { "c", "narrower window (880 -> 800 px), settings columns narrowed to match" },
    { "c", "new module order: URLify, BulkBag, then the rest" },
    { "c", "the hub fades in and out (also on Esc and the close button)" },
    { "c", "the minimap button's right-click menu: Open DreamSuite, a settings shortcut for every enabled module, plus extras a module offers (InventoryPlus: Warehouse)" },
    { "c", "CraftLinker takes several trigger words, separated by commas" },
    { "c", "tab changes: the old page fades out, then the new one fades in (no overlap, slightly slower)" },
    { "d", "the CraftLinker \"nothing cached\" box is wide enough for the message" },
    { "d", "the profile and other settings are written back at logout" },
  } },
  { ver = "0.2.8.1", date = "", items = {
    { "c", "b (major): CraftLinker gets a settings menu (General: reply switch, trigger word, cooldown; Messages: text sent when nothing is cached; Cache: clear all, list of cached professions)" },
    { "c", "the settings engine can build text boxes (type = \"edit\"), usable by any module" },
  } },
  { ver = "0.1.8.1", date = "", items = {
    { "c", "modules without settings show a small red \"No menu available\" in their row" },
  } },
  { ver = "0.1.7.1", date = "", items = {
    { "c", "Enabled / Disabled is a switch: a bordered box on the row, click it to enable or disable" },
    { "c", "the red blink now lights up the whole row instead of a glow around the icon" },
    { "d", "Back button raised so it sits centred in the footer space" },
  } },
  { ver = "0.1.5.0", date = "", items = {
    { "c", "b (major): module list replaces the icon grid: small icon, description, command and status per row" },
    { "c", "tab changes fade out / in" },
    { "c", "left-click on a module without settings, or a disabled one, blinks a faint red glow around its icon" },
    { "c", "\"on / off\" is now \"enabled / disabled\" everywhere (menu, tooltips, status, chat messages, /ds enable||disable <module>; /ds on||off still works)" },
    { "c", "Back button moved to the bottom-right of the settings page, without the arrow" },
    { "c", "the \"8 of 8\" counter in the header is gone" },
  } },
  { ver = "0.0.0.0", date = "", items = {
    { "c", "BulkBag, CraftLinker, URLify, GCDDot, FadeOut, OrbMeter, RarityBorders, InventoryPlus" },
    { "c", "Craftmatic, MobScanner and AutoAspect are not part of the suite" },
    { "c", "Left-click an icon opens that module's settings; right-click opens the menu with Turn on / Turn off and Settings" },
    { "c", "Divider under the logo and name, divider above the footer" },
    { "c", "Back button on the right" },
    { "c", "Version numbers removed from the icons and tooltips; the suite version sits in the footer" },
    { "c", "Own icon for InventoryPlus" },
    { "c", "Update notice comes from other players running a newer version (guild / party / raid), compared as a.b.c.d" },
    { "c", "Shared widgets in UI/Widgets.lua (divider, button, checkbox, tab strip); the generated settings and InventoryPlus use them" },
    { "c", "Tab-style sub-menus: GCDDot, OrbMeter, RarityBorders, FadeOut, InventoryPlus" },
    { "c", "FadeOut has its own \"DreamSuite addons\" tab for the suite's own frames" },
  } },
}
