# 1025DexNav 0.2.1



For Gen1Recomp 0.3.54+. Supports Red, Blue, Yellow, Gold, Silver, Crystal,

Ruby, Sapphire, FireRed, LeafGreen and Emerald, with or without 1025Dex.

Optional integrations: 1025Dex 1.2.15+, Hoennto 0.2.4+, WildFollowers 3 beta.5+.

Disable the other mod named DexNav; both use the same controls.



Install the ZIP with the mod manager. SELECT opens the LAND/WATER screen.
Gen 1/2 use a native-sized text list and text field HUD; Gen 3 keeps its icon grid.


A searches, SELECT registers a species, and B/START closes.

On Gen 1/2, UP/DOWN selects a row and LEFT/RIGHT switches terrain.
On Gen 3, LEFT/RIGHT selects a species and UP/DOWN switches terrain.
L/R changes pages on both layouts. R quick-searches the registered

species. The QUICK SEARCH option can instead use SELECT tap/hold.



Search levels persist per save and increase after a successfully started search

battle. Searches last 15 seconds, lose the signal beyond 20 tiles, and choose

an unoccupied encounter tile nearby. The field HUD reveals moves, abilities,

items and potential stars as the search level increases. The marker does not

replace the player's grass effect. Gen 1/2 use native DVs, moves and battle

lifecycles; abilities are available only on Gen 3, and held items on Gen 2/3.



1025Dex's live encounter selection, habitat gates and natural-move policy are

used when available. Gen 2 LAND pools follow the live time of day. Gen 3 uses

native encounter terrain for grass, caves, indoor dungeons, sand and underwater

seaweed. WildFollowers actors and followers are excluded from search placement.

A search reserves its hidden tile's ordinary step battle; roamers and scripted

battles retain their native behavior.



Hoennto travel, save loads, map reloads and native data/session replacement

clear the active search, menu, cached icons and engine handles. The mounted

cartridge determines species mapping and terrain. Progress remains per save.



## Canonical identities and migration



Every public numeric species argument/result is a National Dex number 1–1025:

`searchLevel`, `setSearchLevel`, `searchLevels`, `speciesName`, `localSpecies`,

`state`, `startSearch`. Public metadata is `numbering = "national"`, `apiVersion = 2`.

`startSearch(game, national, terrain)` returns a boolean. `speciesNumbers.native`

and `speciesNumbers.national` explicitly convert at the engine boundary.

No fixed species offset is used. Native party/save species remain unchanged.



On first access, old v0.1.13 Gen 3 search levels and registrations migrate through

the active cartridge's actual species mapping into `national_progress` schema 1.

The original `search_levels` and `registered` fields remain intact for recovery.

Already migrated data is never interpreted as native IDs. Back up a save before

switching to an older DexNav release: older releases do not understand this schema.



## Implementation and validation



The supplied DexNav 1.1.8 was inspected for interface names only; none of its code

or compatibility files is bundled or copied. Identity, progress migration,

Game Boy adapters, encounter access, battle handoff, tile selection and generation

were independently implemented. Existing screen/HUD presentation and icon helpers

were retained from the user-supplied 1025DexNav; earlier release history remains

in CHANGELOG.md. Gameplay percentage values were retained as tuning data.



Tests run from this folder with a Lua runner:



- `tests/all_games.lua ENGINE_ROOT DEX_ROOT`: all 11 games, real native map,

  GameVersion and GB mon builders, canonical identities, save migration,

  time of day, WildFollowers occupancy, exact battle shapes and travel resets.

- `tests/emerald_compat.lua DEX_ROOT`: actual 1025Dex encounter policy, all 17

  selections, FR/LG/Hoenn pool entries, field/dungeon terrain, UI and battle handoff.

- `tests/wild_moves.lua DEX_ROOT`: actual 1025Dex move data for all 1,025 species

  at levels 1–100, FRLG/RSE previews and PP.



Engine runtime, graphics and battle transitions are controlled fixtures in these

suites. They do not replace visual testing in each imported cartridge.


Version 0.2.1 reserves SELECT from the queued input edges before the GB native
input step, preventing Gen 2 registered-item use and same-press menu registration.
Keyboard/controller taps and SELECT hold are tested with the real Input module.

Compatibility patch 0.2.2: launcher requirement `>=0.3.54`. The previous launcher maximum is removed; game behavior is unchanged.
