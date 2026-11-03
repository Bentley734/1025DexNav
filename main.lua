-- 1025DexNav: National identities with generation-specific native engine adapters.
return function(mod)
  local sourceMod, liveGame = mod, nil
  mod = setmetatable({}, {__index=function(_,key)
    if key=='game' then return liveGame or sourceMod.game end
    return sourceMod[key]
  end})
  mod.events:on('game.ready',function(ev) if ev and ev.game then liveGame=ev.game end end)

  local function readModule(rel)
    local source = mod:read(rel)
    if not source then error("[gen3_dexnav] missing mod file: " .. rel) end
    return assert(load(source, "@gen3_dexnav/" .. rel))()
  end

  local Gen3 = readModule("src/gen3.lua")
  local GB = readModule("src/gameboy.lua")
  Gen3 = GB.bind(Gen3, mod)
  local Identity = readModule("src/identity.lua").new(mod, Gen3)
  Gen3.identity = Identity
  local Progress = readModule("src/progress.lua").new(mod, Identity, Gen3.generation)
  local Chance = readModule("src/chance.lua")
  local Generator = readModule("src/generator.lua")
  local Scan = readModule("src/scan.lua")
  local Data = readModule("src/data.lua")
  local Icons = readModule("src/mon_icons.lua")
  local Hud = readModule(Gen3.generation()<3 and "src/text_hud.lua" or "src/hud.lua")
  local Screen = readModule(Gen3.generation()<3 and "src/text_screen.lua" or "src/screen.lua")
  local Input = readModule("src/input.lua")
  local Encounter = readModule("src/encounter.lua")

  Gen3.roll = Gen3.roll or Chance.roll
  Generator.init(Chance)
  Data.init(Gen3, mod, Identity)
  Icons.init(Gen3)
  Hud.init(Gen3, Icons)
  Screen.init(Gen3, Icons, Data)
  Encounter.init(Gen3, Identity, mod)
  Screen.reset() -- a hot reload must not leave a stale layer on the stack

  local SELECT_HOLD = 0.40 -- seconds; a longer hold opens the screen
  local TIMEOUT = 15.0 -- seconds; the reference's 0x384-frame search clock
  local LOST_RANGE = 20 -- manhattan tiles; the reference's "> 20" signal loss
  local BUSH_FRAMES = 5 -- tall-grass rustle frames (FieldEffects RUSTLE)
  local BUSH_FRAME = 0.12 -- seconds per frame; a ~0.6s continuous loop

  -- ------- options

  mod.options:define({
    { key = "field_hud", label = "FIELD HUD", type = "toggle", default = true },
    { key = "quick_key", label = "QUICK SEARCH", type = "choice", default = "r",
      choices = { { "R BUTTON", "r" }, { "SELECT", "select" } } },
  })

  -- ------- search levels + registration (per save, mod.save)

  local searchLevel = Progress.get
  local registered = Progress.registered
  local register = Progress.register
  local function bumpSearchLevel(n) return Progress.set(n, Progress.get(n)+1) end

  -- ------- the active search

  local search -- nil, or the live scan state

  local function say(game, text)
    if not Gen3.say(game, text) then mod.log:info("%s", tostring(text)) end
  end

  local function roll(n)
    return Chance.roll(n)
  end

  --- The engine owns one tall-grass rustle slot (the player's own grass step
  --- uses it too), so a search drives it: clear + aim it at the hidden tile.
  local function armRustle(state)
    if state.terrain == "water" then return end
    Gen3.clearTallGrass()
    state.bushClock = 0
    Gen3.rustleFrame(state.tile.x, state.tile.y, 0)
  end

  --- Choose a hidden tile near the player with the reference's weighting.
  local function place(state)
    local cell = Data.playerCell()
    if not cell then return false end
    local query = Data.tileQuery(state.terrain)
    if not query then return false end
    local x, y = Scan.pick({
      px = cell.x,
      py = cell.y,
      terrain = state.terrain,
      cave = state.cave,
      roll = roll,
      isTarget = query.isTarget,
      passable = query.passable,
    })
    if not x then return false end
    state.tile = { x = x, y = y }
    state.customMarker = Data.target({mapId=state.mapId, species=state.species,
      terrain=state.terrain, x=x, y=y})
    armRustle(state)
    return true
  end

  local function stopSearch()
    Data.target(nil)
    search = nil
    Screen.setSearchActive(false)
    Gen3.clearTallGrass()
  end

  local function startSearch(game, species, terrain)
    species = Identity.valid(species)
    terrain = terrain == 'water' and 'water' or 'land'
    if not species or not Identity.native(species) or not Gen3.fieldReady() then return false end
    if Gen3.busy() and not Screen.isOpen() then return false end
    stopSearch()
    local mapId = Data.mapId()
    local record = Data.encounters(mapId)
    local slot = record and Data.slotFor(record, terrain, species)
    if not slot then
      say(game, "There is no reaction.\nThe signal was lost!")
      return false
    end

    local level = searchLevel(species)
    local spec = Generator.build({
      species = species,
      generation = Gen3.generation(),
      record = Data.speciesRecord(mod, species),
      slot = slot,
      searchLevel = level,
      terrain = terrain,
      roll = roll,
      use = Data.resolver,
    })

    local state = {
      species = species,
      name = Data.speciesName(species),
      terrain = terrain,
      mapId = mapId,
      level = level,
      spec = spec,
      elapsed = 0,
      rerolls = 0,
      proximity = nil,
    }
    state.spec.moveName = Data.moveName(spec.moves[1])
    state.spec.abilityName = Data.resolver.abilityName(spec.ability)
    state.spec.itemName = Data.itemName(spec.item)

    if not place(state) then
      say(game, "The Pokemon got away!")
      return false
    end

    search = state
    Screen.setSearchActive(true)
    return true
  end

  local function startBattle(game)
    local state = search
    if not state then return end
    local foe = Encounter.build(state.spec, state.species)
    stopSearch()
    local ok = Encounter.start(mod, game, foe, state.species, state.spec.level)
    if not ok then
      mod.log:warn("battle start failed for species %s", tostring(state.species))
      return
    end
    bumpSearchLevel(state.species)
  end

  -- ------- field tick (core.update)

  local function fieldTick(game, dt)
    if not search then return end
    if not Gen3.fieldReady() or Data.mapId() ~= search.mapId then
      stopSearch()
      return
    end
    if Gen3.busy() then return end

    local cell = Data.playerCell()
    if not cell then return end
    local proximity = math.abs(cell.x - search.tile.x) + math.abs(cell.y - search.tile.y)
    search.elapsed = search.elapsed + (tonumber(dt) or 0)

    if proximity > LOST_RANGE then
      stopSearch()
      say(game, "There is no reaction.\nThe signal was lost!")
      return
    end

    if search.elapsed > TIMEOUT then
      stopSearch()
      say(game, "The Pokemon got away!")
      return
    end

    if proximity < 1 then
      startBattle(game)
      return
    end

    -- Keep the engine's one tall-grass slot on the hidden tile (the player's
    -- own grass step uses it too) and drive its frames ourselves: the engine
    -- plays the rustle once and parks on the last frame, which reads as a
    -- single pulse.  Looping all five frames makes it constant and obvious.
    if search.terrain ~= "water" then
      search.bushClock = (search.bushClock or 0) + (tonumber(dt) or 0)
      local frame = math.floor(search.bushClock / BUSH_FRAME) % BUSH_FRAMES
      Gen3.rustleFrame(search.tile.x, search.tile.y, frame)
    end

    -- Surfing Pokemon move around: the reference re-rolls the tile up to
    -- twice while the player closes in, so a beeline cannot pin them down.
    if proximity < 2 and search.rerolls < 2 and search.terrain == "water" then
      search.rerolls = search.rerolls + 1
      place(search)
    end

    search.proximity = proximity
  end

  -- ------- SELECT: tap searches the registered species, hold opens the screen

  local selectDown = nil

  local function openScreen(game)
    if not Gen3.fieldReady() or Gen3.busy() then return false end
    local mapId = Data.mapId()
    return Screen.open(mod, {
      game = game,
      mapId = mapId,
      encounters = Data.encounters(mapId),
      searchLevel = searchLevel,
      registered = registered(),
      onSearch = function(species, terrain)
        register(species, terrain)
        startSearch(game, species, terrain)
      end,
      onRegister = function(species, terrain)
        register(species, terrain)
      end,
    })
  end

  --- The one field action behind the quick key: search the registered
  --- species, or open the screen when nothing is registered yet.
  local function quickSearch(game)
    if search or Screen.isOpen() then return end
    local reg = registered()
    if not reg then
      openScreen(game)
      return
    end
    startSearch(game, reg.species, reg.terrain)
  end

  local function quickKeyIsR()
    return (mod.options:get("quick_key") or "r") ~= "select"
  end

  local function pollSelect(game, dt, input)
    input = input or game and game.input
    if not input or not input.wasPressed then return end
    if Screen.isOpen() or Gen3.busy() then
      selectDown = nil
      return
    end
    if quickKeyIsR() then
      -- R (gamepad right shoulder, or its keyboard alias) quick-searches;
      -- SELECT opens the screen, tap or hold.
      if input:wasPressed("r") then
        quickSearch(game)
        return 'r'
      elseif input:wasPressed("select") then
        openScreen(game)
        return 'select'
      end
      return
    end
    if input:wasPressed("select") then
      selectDown = 0
    end
    if selectDown == nil then return end
    selectDown = selectDown + (tonumber(dt) or 0)
    if selectDown >= SELECT_HOLD then
      selectDown = nil
      openScreen(game)
      return 'select'
    end
    if not input:isDown("select") then
      selectDown = nil
      quickSearch(game)
    end
    return 'select'
  end

  -- Campaign switches can replace the dataset, world and save in one update.
  -- Compare actual owners as well as GameVersion; no map-name prefix guesses.
  local context
  local function reset()
    stopSearch(); Screen.reset(); Progress.reset(); Encounter.reset()
    if Icons.reset then Icons.reset() end
    if Gen3.reset then Gen3.reset() end
    selectDown = nil
  end
  local function sync()
    local game = mod.game
    local R = Gen3.generation() == 3 and Gen3.try('src.core.game3.runtime')
    local session = R and R.getSession and R.getSession()
    local w = Gen3.generation() < 3 and Gen3.overworld()
    local nextContext = {game=game, save=game and game.save, data=game and game.data,
      session=session, sessionVersion=session and session.version,
      world=w, map=w and w.map, id=Gen3.gameId(), mapId=Data.mapId()}
    if context then
      for key,value in pairs(nextContext) do
        if context[key] ~= value then reset(); break end
      end
      for key,value in pairs(context) do
        if nextContext[key] ~= value then reset(); break end
      end
    end
    context = nextContext
  end
  for _, event in ipairs({'save.created','save.loaded','save.loading','save.new_game','map.reloaded'}) do
    mod.events:on(event, reset)
  end
  -- ------- wiring

  mod.hooks:wrap("core.update", function(next, game, dt)
    liveGame = game or liveGame
    local result = next(game, dt)
    sync()
    local ok, err = pcall(fieldTick, game, dt)
    if not ok then stopSearch(); mod.log:warn("DexNav update: %s", tostring(err)) end
    return result
  end)

  mod.hooks:wrap("input.step", function(next, game, dt)
    liveGame = game or liveGame
    local result = next(game, dt)
    sync()
    local pad=game and game.input
    local pending=Gen3.generation()<3 and Input.pending(pad) or pad
    local ok,handled=pcall(pollSelect, game, dt, pending)
    if ok and handled and Gen3.generation()<3 then Input.consume(pad,handled) end
    if not ok then mod.log:warn('DexNav input: %s',tostring(handled)) end
    return result
  end)

  -- Only reserve the hidden tile's ordinary step encounter. Preserve roamers,
  -- fishing, scripted encounters and all random battles on other tiles.
  mod.hooks:wrap('encounter.roll',function(next,tables,ctx)
    local hit=next(tables,ctx)
    if not search or not hit or hit.roamer or hit.roaming or hit.wildScripted
      or ctx and ctx.kind and ctx.kind~='wild' then return hit end
    if ctx and ctx.mapId and ctx.mapId~=search.mapId then return hit end
    local cell=Data.playerCell()
    if cell and cell.x==search.tile.x and cell.y==search.tile.y then return nil end
    return hit
  end)

  -- The engine binds the R button to the keyboard `e` (DEFAULT_BINDINGS); a
  -- player pressing the literal R key gets this hook.  R is unused in the
  -- field, so the press is only ever ours.
  mod.hooks:wrap("input.key", function(next, game, payload)
    local result = next(game, payload)
    pcall(function()
      if not quickKeyIsR() then return end
      if not (payload and payload.phase == "pressed" and payload.key == "r") then return end
      if Screen.isOpen() or Gen3.busy() then return end
      quickSearch(game)
    end)
    return result
  end)

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    pcall(Hud.draw, game, viewport, {
      search = search,
      enabled = mod.options:get("field_hud") ~= false,
      busy = Gen3.busy,
    })
    return result
  end)

  mod.events:on("world.stepped", function(payload)
    if search and payload and payload.mapId and payload.mapId ~= search.mapId then
      stopSearch()
    end
  end)

  mod.events:on("battle.started", function(payload)
    stopSearch()
    pcall(Encounter.applyPending, payload and payload.battle)
  end)

  -- ------- inter-mod surface

  mod.exports.searchLevel = searchLevel
  mod.exports.setSearchLevel = Progress.set
  mod.exports.searchLevels = Progress.all
  mod.exports.numbering = 'national'
  mod.exports.apiVersion = 2
  mod.exports.speciesNumbers = Identity
  mod.exports.speciesName = Data.speciesName
  mod.exports.localSpecies = function(mapId, terrain)
    local record = Data.encounters(mapId or Data.mapId())
    return Data.speciesList(record, terrain or "land")
  end
  mod.exports.state = function()
    if not search then return nil end
    return {
      species = search.species,
      name = search.name,
      terrain = search.terrain,
      level = search.spec.level,
      potential = search.spec.potential,
      tile = { x = search.tile.x, y = search.tile.y },
      proximity = search.proximity,
    }
  end
  mod.exports.openScreen = openScreen
  mod.exports.startSearch = function(game, species, terrain) sync(); return startSearch(game or mod.game, species, terrain) end
  mod.exports.stopSearch = stopSearch
end
