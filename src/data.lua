-- Live content access. Species exposed here always use National Dex numbers.
local Data = {}
local Gen3, mod, identity
function Data.init(engine, owner, numbers)
  Gen3, mod, identity = engine, owner, numbers
end
function Data.exports(id)
  if not mod.find then return nil end
  local ok, h = pcall(mod.find, mod, id)
  return ok and h and h.exports or nil
end
function Data.target(target)
  local A = Data.exports('wildfollowers')
  if A and A.dexnavTarget then return A.dexnavTarget(target) end
  return false
end
function Data.mapId()
  local world = mod.world
  local current = world and world.current and world:current()
  if current and current.mapId then return current.mapId end
  if Gen3.generation()==3 then
    local R=Gen3.try('src.core.game3.runtime');local session=R and R.getSession and R.getSession()
    return session and session.map
  end
end
function Data.playerCell() return Gen3.playerCell() end
function Data.speciesId(native) return identity.national(native) end
function Data.speciesName(n) return identity.name(n) end
function Data.speciesRecord(_, n) return identity.record(n) end
local function nativeGB(mapId)
  local game = mod.game
  local data = game and game.data
  if not data then return nil end
  if Gen3.generation() == 1 then return data.encounters and data.encounters[mapId] end
  local w = Gen3.overworld()
  local tables = w and w.encounters or data.gen2Encounters
  if not tables then return nil end
  local grass = tables.grass and tables.grass[mapId]
  local water = tables.water and tables.water[mapId]
  local tod = w and (w.tod or w.daytime) or 'DAY'
  if tod == 'DARK' then tod = 'NITE' end
  local slots = grass and grass.slots and (grass.slots[tod] or grass.slots.DAY)
  local rate = grass and grass.rates and (grass.rates[tod] or grass.rates.DAY)
  return {land=slots and {slots=slots,rate=rate}, water=water}
end
local function area(record, terrain)
  return record and (record[terrain] or terrain == 'land' and record.grass)
end
function Data.encounters(mapId)
  if not mapId then return nil end
  local source
  for _, id in ipairs({'1025dex','firered_complete_dex','wildfollowers'}) do
    local A = Data.exports(id)
    if A and A.dexnavEncounters then
      local ok, r = pcall(A.dexnavEncounters,mapId)
      if ok and type(r) == 'table' then source=r; break end
    end
  end
  if not source and Gen3.generation() == 3 then
    local E = Gen3.try('src.core.game3.encounters')
    source = E and E.tableFor and E.tableFor(mapId)
  end
  source = source or (Gen3.generation() < 3 and nativeGB(mapId))
  if not source then
    local R = mod.content and mod.content.encounters
    source = R and R:get(mapId)
  end
  if not source then return nil end
  local result = {numbering='national'}
  for _, terrain in ipairs({'land','water'}) do
    local a = area(source,terrain)
    if a and a.rate ~= 0 then
      local slots = {}
      for _, s in ipairs(a.slots or a.mons or {}) do
        local ref = s.species or s[1]
        local n = source.numbering == 'national' and identity.valid(ref) or identity.national(ref)
        local lo = tonumber(s.minLevel or s.min or s.level or s[2])
        local hi = tonumber(s.maxLevel or s.max or s.level or s[3]) or lo
        if n and identity.native(n) and lo then slots[#slots+1]={species=n,minLevel=lo,maxLevel=hi} end
      end
      -- GB 1025Dex exposes its gated, habitat-specific additions separately.
      local A = Data.exports('1025dex')
      if Gen3.generation() < 3 and A and A.gbEncounterAdditions then
        local additions, profile = A.gbEncounterAdditions(mapId,terrain)
        for _, row in ipairs(additions or {}) do
          local n = identity.valid(row.id)
          if n and identity.native(n) and profile then
            local lo = math.max(profile.lo,math.min(profile.hi,row.gate or profile.lo))
            if row.special or row.ultra then lo=math.max(55,lo) end
            slots[#slots+1]={species=n,minLevel=lo,maxLevel=math.max(lo,profile.hi)}
          end
        end
      end
      result[terrain]={slots=slots,rate=a.rate}
    end
  end
  return result
end
function Data.speciesList(record,terrain)
  local a = area(record,terrain)
  local out,seen = {},{}
  for _, slot in ipairs(a and (a.slots or a.mons) or {}) do
    local n = record.numbering == 'national' and identity.valid(slot.species) or identity.national(slot.species)
    if n then
      if seen[n] then seen[n].count=seen[n].count+1
      else local row={species=n,name=identity.name(n),count=1}; seen[n]=row; out[#out+1]=row end
    end
  end
  return out
end
function Data.slotFor(record,terrain,n)
  local a = area(record,terrain); local lo,hi
  for _, s in ipairs(a and a.slots or {}) do
    local id = record.numbering == 'national' and identity.valid(s.species) or identity.national(s.species)
    if id == n then
      local min = tonumber(s.minLevel or s.level); local max = tonumber(s.maxLevel or s.level) or min
      if min then lo=math.min(lo or min,min); hi=math.max(hi or max,max) end
    end
  end
  return lo and {min=lo,max=hi} or nil
end
local resolver = {}
function resolver.moveId(ref)
  if Gen3.generation() < 3 then
    if type(ref) ~= 'string' then return nil end
    local key=ref:upper():gsub('[^A-Z0-9]','_')
    return mod.game.data.moves[key] and key or nil
  end
  if tonumber(ref) then return tonumber(ref) end
  local M=Gen3.try('src.core.game3.battle.moves')
  return M and M.numForName and M.numForName(M.normalizeId(ref))
end
function resolver.movePp(id)
  if Gen3.generation() < 3 then local row=mod.game.data.moves[id]; return row and row.pp or 0 end
  local P=Gen3.pokemon(); return P and P.movePp and P.movePp(id) or 0
end
function resolver.movesAtLevel(n,level)
  local native=identity.native(n); if not native then return nil end
  if Gen3.generation() == 3 then
    local A=Data.exports('1025dex')
    if A and A.vanillaWildMoves then
      local moves,pp=A.vanillaWildMoves(native,level)
      if moves and #moves>0 then return moves,pp end
    end
    local P=Gen3.pokemon(); return P and P.movesAtLevel and P.movesAtLevel(native,level)
  end
  local moves,pp={},{}
  if Gen3.generation() == 1 then
    local P=Gen3.try('src.pokemon.Pokemon')
    moves=P.movesAtLevel(identity.record(n),level)
    for i,m in ipairs(moves) do pp[i]=resolver.movePp(m) end
  else
    local P=Gen3.try('src.battle.gen2.Mon')
    for _,m in ipairs(P.movesAtLevel(identity.record(n),level,mod.game.data.moves)) do
      moves[#moves+1]=m.id; pp[#pp+1]=m.pp
    end
  end
  return moves,pp
end
function resolver.strictLevelUpMoves()
  local A=Data.exports('1025dex')
  return Gen3.generation()<3 or A and type(A.vanillaWildMoves)=='function' or false
end
function resolver.abilityIds(n)
  if Gen3.generation()<3 then return nil end
  local P=Gen3.pokemon(); local native=identity.native(n)
  return native and P and P.abilities and P.abilities(native) or nil
end
function resolver.abilityName(id)
  if not id or Gen3.generation()<3 then return nil end
  local P=Gen3.pokemon(); return P and P.abilityName and P.abilityName(id)
end
function resolver.itemName(id)
  if Gen3.generation()<3 then local r=mod.game.data.items and mod.game.data.items[id];return r and r.name end
  local I=Gen3.items();return I and I.displayName and I.displayName(id)
end
function Data.specialAbilityName(n)
  local ids=resolver.abilityIds(n);return ids and ids[2] and resolver.abilityName(ids[2])
end
function Data.moveName(id)
  if Gen3.generation()<3 then local r=mod.game.data.moves[id]; return r and r.name end
  local P=Gen3.pokemon();return P and P.moveName and P.moveName(id)
end
function Data.itemName(id) if id and id~=0 then return resolver.itemName(id) end end
Data.resolver=resolver
local function companionAt(x,y)
  local api=Data.exports('wildfollowers')
  if not (api and api.status) then return false end
  local ok,state=pcall(api.status)
  if not ok or not state or state.game and state.game~=Gen3.gameId() then return false end
  for _,list in ipairs({state.actors or {},state.followers or {}}) do
    for _,e in ipairs(list) do
      if not e.hidden and e.x==x and e.y==y then return true end
    end
  end
  return false
end
local function gbTiles(terrain)
  local w=Gen3.overworld();local map=w and w.map
  if not map then return nil end
  local field=mod.game.data.field or {};local indoor=field.indoorEncounters
  local d=map.def or {}
  local cave=Gen3.generation()==1 and indoor and d.index and d.index>=indoor.firstIndoorMap and d.tileset~=indoor.excludedTileset
    or Gen3.generation()==2 and (d.environment=='CAVE' or d.environment==4)
  local function target(x,y)
    if not map:inBounds(x,y) or map:warpAtCell(x,y) then return false end
    if companionAt(x,y) then return false end
    for _, list in ipairs({w.entities or {},w.npcs or {}}) do
      for _, e in pairs(list) do
        if not e.hidden and ((e.cellX==x and e.cellY==y) or (e.targetX==x and e.targetY==y)) then return false end
      end
    end
    local water=map:isWaterCell(x,y)
    if terrain=='water' then return water end
    if water or not map:isWalkableCell(x,y) then return false end
    return map:isGrassCell(x,y) or cave==true
  end
  return {isTarget=target,passable=target}
end
function Data.tileQuery(terrain)
  if Gen3.generation() < 3 then return gbTiles(terrain) end
  local C = Gen3.collision()
  if not C then return nil end
  local api = Data.exports("wildfollowers")
  -- Emerald's raw metatile bytes are translated into canonical engine IDs.
  -- Resolve named IDs, rather than comparing its ROM bytes with FRLG bytes.
  local MB = Gen3.try("src.core.game3.mb")
  local function id(name, fallback)
    return MB and MB.id and MB.id(name) or fallback
  end
  local tall, long, ash, sand = id("TALL_GRASS", 0x02),
    id("LONG_GRASS", 0x103), id("ASHGRASS", 0x124), id("DEEP_SAND", 0x106)
  local seaweed, deepSeaweed = id("SEAWEED", 0x22), id("SEAWEED_NO_SURFACING", 0x12a)
  local emerald = Gen3.gameId() == "emerald" or Gen3.gameId() == "ruby" or Gen3.gameId() == "sapphire"
  local Encounters = Gen3.try("src.core.game3.encounters")
  local Objects = Gen3.try("src.core.game3.objects")
  local mapType = tonumber(C._mapDef and C._mapDef.mapType)
  local fallbackLand
  if not (Encounters and Encounters.terrainAt) and (mapType == 4 or mapType == 8) then
    local record = Data.encounters(Data.mapId())
    fallbackLand = record and area(record, "land") ~= nil
  end
  local function target(x,y)
    if C.inBounds and not C.inBounds(x,y) then return false end
    if companionAt(x,y) then return false end
    if C.warpAt and C.warpAt(x,y) then return false end
    if Objects and Objects.at and Objects.at(x,y) then return false end
    local behavior = C.behavior and C.behavior(x,y)
    local water = C.isWater and C.isWater(x,y) or false
    local underwater = emerald and tonumber(C._mapDef and C._mapDef.mapType) == 5
    if underwater then
      return terrain == "water" and (behavior == seaweed or behavior == deepSeaweed)
        and (water or not C.isWalkable or C.isWalkable(x,y))
    end
    if terrain ~= "water" and (water or (C.isWalkable and not C.isWalkable(x,y))) then
      return false
    end
    -- Native encounter classification covers caves, indoor dungeons, grass,
    -- sand and game-specific tiles. WildFollowers uses this same engine seam.
    if Encounters and Encounters.terrainAt then
      local ok, kind = pcall(Encounters.terrainAt, x, y)
      if ok then return kind == terrain end
    end
    -- Older engine fallback: do not let WildFollowers spawn toggles decide
    -- whether a DexNav search can run. Only consult its optional tile API
    -- after the map safety checks, when native classification is unavailable.
    if api and api.dexnavTileAllowed then
      local ok, allowed = pcall(api.dexnavTileAllowed, x, y, terrain)
      if ok then return allowed == true end
    end
    if terrain == "water" then return water end
    if behavior == tall or behavior == 0xD1
      or (emerald and (behavior == long or behavior == ash or behavior == sand)) then
      return true
    end
    -- Cave and indoor encounter maps have ordinary walkable floors. A live
    -- land table is required, so buildings without Pokemon stay excluded.
    if fallbackLand then return C.isWalkable ~= nil and C.isWalkable(x,y) == true end
    return false
  end
  return {isTarget=target, passable=target}
end

return Data
