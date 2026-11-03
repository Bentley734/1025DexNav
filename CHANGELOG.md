# 0.2.1

- Replace Gen 1/2 icon grids with native 160x144 scrolling text lists.
- Use uncompressed native font coordinates and a text-only Game Boy field HUD.
- Route SELECT from the current queued input edge before native Input:step.
- Consume handled shortcuts so Gen 2 does not use its registered item and the
  opening SELECT press does not immediately register a menu row.
- Validate keyboard/controller taps, SELECT hold, row selection, registration,
  search handoff, integer drawing coordinates and text bounds on all six GB games.
- Preserve the Gen 3 screen/HUD and canonical progress schema.

# 0.2.0



- Support all 11 Gen 1–3 cartridges through native per-generation adapters.

- Use canonical National Dex identities across public APIs and saved progress.

- Migrate v0.1.13 native progress without deleting the original save fields.

- Honor Gen 2 time-of-day tables and 1025Dex habitat additions and generation gates.

- Refresh menus, searches, icons and native handles on Hoennto travel/save changes.

- Preserve native battle completion, catches, evolution and blackout handling.

- Respect WildFollowers occupied tiles and preserve the player's grass effects.

- Independently implement search selection/generation; include the maximum slot

  level, prevent zero-percent bonuses, and award potential without repeated stats.



## 0.1.13 â€” Level-appropriate moves with 1025Dex



- With 1025Dex 1.2.9+, use its canonical wild move API in the generator.

- Disable bonus TM/HM moves while that API is active. A low-level Charmander

  cannot receive Flamethrower as a bonus, and previews match actual battles.

- Keep the existing special-move behavior when running without that API.

- Preserve encounter pools, terrain searches, exact species, icons and UI.



## 0.1.12 â€” Encounter-area search fixes



- Use the engine terrainAt classifier shared with WildFollowers instead of

  accepting only hardcoded grass tiles. Enables bare-floor caves and indoor

  encounter dungeons in FR/LG/Emerald while preserving Emerald seaweed rules.

- On older engines, allow walkable cave/indoor floors only when the map has

  a live land encounter table. Exclude bounds, warp and native object tiles.

- Keep the reference scan weighting, then pick a validated tile if every

  random roll misses; never select the tile occupied by the player.

- Prefer 1025Dex's live modified pools over an intermediary provider. Recheck

  pools on each search and keep the exact selected species in battles.

- Fall back to the runtime map ID if the public world state lacks one.

- Extend production-code regression tests across Kanto, Sevii and Hoenn,

  LG map aliases, all generation selections, caves and indoor dungeons.



## 0.1.5 compatibility build



Live custom encounter APIs, exact-species battles, custom field marker, icon retry, paged pools, and LeafGreen/Widescreen support.



# Changelog



## [0.1.11] - 2026-10-01



### Added



- Emerald support in the manifest and sharing metadata.

- Canonical Gen 3 terrain handling for Emerald long grass, ash grass, desert deep sand, and underwater seaweed.

- Blocked tiles, warps and underwater non-encounter floor are excluded from fallback searches.

- Emerald integration tests for vanilla and custom encounters, icons, search placement, modal UI, and exact battle hand-off.



The existing 1025Dex/WildFollowers API priority, search controls, generation mechanics and FR/LG UI layout remain in use.



## [0.1.10] - 2026-09-25



### Changed



- Point the manifest repository field to `Bentley734/1025DexNav`.



## [0.1.9] - 2026-09-25



### Fixed



- Removed the two partial frame tiles protruding from the bottom corners of

  the DexNav footer without changing the footer size or its text layout.



## [0.1.8] - 2026-09-24



### Fixed



- Aligned the no-water message with the WATER label.

- Centered the DEXNAV title and A:SEARCH control vertically in the header.



## [0.1.7] - 2026-09-24



### Fixed



- LAND moves up under the header on maps with no water encounters instead of

  leaving a full empty WATER panel above it.

- WATER retains its 32px-safe one/two-row layout and L/R paging from 0.1.6.

- The adaptive layout remains inside FireRed's modal canvas for Widescreen

  FireRed compatibility.



All notable changes to this project are documented here. The format follows

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project

adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).



## [0.1.3] - 2026-09-19



### Fixed



- The screen header no longer clips in either direction. FRLG glyph cells

  carry ink from row 0 down to row ~12, so the title row now sits at y=5 in a

  24px header bar with clearance on both sides; the panels were re-budgeted

  around it.



### Changed



- Panel titles ("WATER", "LAND") moved to the left edge of their panels, like

  the reference, which frees the label rows for the icons.

- The info bar is two rows: species / search level / bonus / ability on the

  first, and the controls hint or the transient status message on the second,

  so a status no longer hides the numbers.



## [0.1.2] - 2026-09-19



### Changed



- The field quick search is the **R button** by default (gamepad right

  shoulder, the literal R key, or the engine's `e` alias) once a species is

  registered; **SELECT now always opens the DexNav screen**. The new QUICK

  SEARCH option switches the quick key back to SELECT (tap = search, hold =

  screen).

- The hidden-tile rustle loops through all five frames continuously (the mod

  drives the frame each tick) instead of playing once and parking, and a

  softly bobbing chevron marks the tile so the spot reads at a glance.



### Fixed



- The screen header text no longer clips at the top: FRLG glyph ink can start

  at cell row 0, so the header row moved to y=2 inside a 16px bar.



## [0.1.1] - 2026-09-19



### Fixed



- The DexNav screen draws the engine's native 32x32 party icons (was 18-20px

  half-size) and animates them at the party menu's frame rate instead of

  freezing on the first frame.

- The screen's info line and status messages are one 14px row now; the

  previous two-line status ("X registered.\nTap SELECT...") was clipped by

  the bottom edge. The line reads `NAME  LV n  +bonus  ABL ability`, and

  transient messages replace it until the cursor moves.

- A search now shows the engine's own tall-grass rustle on the hidden tile

  (clear + `FieldEffects.tallGrassAt`, kept alive each frame and replayed

  every ~0.9s), instead of no world marker at all. Surf searches draw a

  wave-ring overlay on the tile, since the engine exposes no per-cell water

  effect.

- Panel geometry: the WATER panel no longer overlaps the LAND panel.



### Changed



- The WATER/LAND panels use the full 32px icon box (6 columns of land, 5 of

  water), and the info line drops the reference's four-row right column,

  which cannot hold a 14px FRLG font next to 32px icons.



## [0.1.0] - 2026-09-19



### Added



- Per-species search levels (0-100) persisted per save, raised by one for

  every hidden Pokemon battle.

- The DexNav screen (SELECT hold, or SELECT tap with nothing registered):

  the current map's LAND and WATER encounter species, cursor navigation, the

  highlighted species' search level, level bonus and special ability, and

  the reference's SEARCH / REGISTER / CANCEL verbs.

- Hidden-Pokemon generation from the map's own wild slots: level from the

  slot range plus the search-level bonus (capped at +20), 0-3 potential

  stars that force 31 IVs, a special move in slot 1, a second ability, and

  held-item odds -- all driven by the reference's search-level chance tables.

- Rustling-tile search: a 12x12 distance-weighted scan for a grass or surf

  tile near the player, a 15-second search clock, >20-tile signal loss,

  surf Pokemon re-rolling their tile as the player closes in, and the

  reference's "got away" / "signal lost" messages.

- The field HUD strip: species icon, level, potential stars, move, ability

  and item, revealed by search level (move at >1, ability/item at >2, stars

  at >4), plus the proximity prompt.

- Mod options: FIELD HUD and SELECT TAP.

- An exported API for other mods: `searchLevel`, `searchLevels`,

  `setSearchLevel`, `speciesName`, `localSpecies`, `state`, `openScreen`,

  `startSearch`, `stopSearch`.

- A 99-check headless suite covering the chance tables, the generator, the

  tile search, the screen/HUD draw paths, and a full load of the mod on a

  Gen 3 boot through the production loader.

