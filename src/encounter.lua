-- Build native foes before the engine takes ownership of battle lifecycles.
local E = {}
local engine, identity, owner, pending
function E.init(adapter, numbers, mod) engine,identity,owner=adapter,numbers,mod end
function E.reset() pending=nil end
function E.build(spec,n)
  return {species=n,level=spec.level,moves=spec.moves,pp=spec.pp,ivs=spec.ivs,
    ability=spec.ability,item=spec.item~=0 and spec.item or nil}
end
local function gbMon(game,foe,key)
  local moves={}
  for i,id in ipairs(foe.moves or {}) do
    if type(id)=='string' and game.data.moves[id] then moves[#moves+1]={id=id,pp=foe.pp[i]} end
  end
  local iv=foe.ivs or {}
  local dvs={attack=math.floor((iv.atk or 0)/2),defense=math.floor((iv.def or 0)/2),
    speed=math.floor((iv.spe or 0)/2),special=math.floor((iv.spa or 0)/2)}
  if engine.generation()==2 then
    return engine.try('src.battle.gen2.Mon').new(game.data,key,foe.level,{dvs=dvs,moves=moves,item=foe.item})
  end
  local P=engine.try('src.pokemon.Pokemon')
  local mon=P.new(game.data,key,foe.level,function() return 0 end)
  dvs.hp=(dvs.attack%2)*8+(dvs.defense%2)*4+(dvs.speed%2)*2+dvs.special%2
  mon.dvs=dvs;mon.moves=moves
  mon.stats=engine.try('src.pokemon.Stats').calc(game.data.pokemon[key],foe.level,dvs,mon.statExp)
  mon.hp=mon.stats.hp;return mon
end
function E.start(mod,game,foe,n,level)
  local key=identity.native(n)
  if not key or not engine.fieldReady() or engine.busy() then return false,'field unavailable' end
  game=game or mod.game
  local healthy=false
  for _,mon in ipairs(game and game.save and game.save.party or {}) do if (mon.hp or 0)>0 then healthy=true;break end end
  if not healthy then return false,'no healthy party' end
  if engine.generation()==2 then
    local w=engine.overworld(); local mon=gbMon(game,foe,key)
    if not mon or not w or not w.startBattle then return false,'no battle seam' end
    -- World:startBattle owns transitions, evolution and blackouts.
    local started=w:startBattle({wild=mon}) ~= false
    if started then
      game.save.pokedex=game.save.pokedex or {seen={},caught={}}
      game.save.pokedex.seen=game.save.pokedex.seen or {}
      game.save.pokedex.seen[key]=true
    end
    return started
  end
  if engine.generation()==1 then
    -- The supported API preserves afterBattle. Install the complete generated
    -- mon at battle.started, before commands can run; pending is armed first.
    pending=gbMon(game,foe,key)
    local ok,result=pcall(mod.world.startWildBattle,mod.world,key,level)
    if not ok or not result then pending=nil;return false end
    return true
  end
  local native={}
  for k,v in pairs(foe) do native[k]=v end
  native.species=key
  local B=engine.battleBridge()
  if not (B and B.startWild) then return false,'native battle bridge unavailable' end
  local ok,result=pcall(B.startWild,mod,game,native,{__completeDexExact=true,visibleSpawn=true})
  return ok and result and true or false
end
function E.applyPending(state)
  if not pending then return end
  local mon=pending;pending=nil
  if not (state and state.enemy and state.enemy.mon and state.enemy.mon.species==mon.species) then return end
  local enemy=state.enemy
  enemy.mon=mon;enemy.curStats=mon.stats;enemy.curMoves=mon.moves
  enemy.shownHP=mon.hp;enemy.shownPx=48
end
return E
