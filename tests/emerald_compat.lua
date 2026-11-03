-- Run from the mod folder: texlua tests/emerald_compat.lua /path/to/1025Dex
-- Production DexNav and attached Dex policy; engine/graphics services are fixtures.
local dexRoot=assert(arg[1],'Pass the extracted 1025Dex 1.2.1 folder')
local checks=0
local function eq(a,b,msg)
  checks=checks+1;assert(a==b,(msg or '')..': '..tostring(a)..' ~= '..tostring(b))
end
local function read(path)
  local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s
end
local function data(path)return assert(loadfile(dexRoot..'/'..path))()end
local gameId='emerald'
local session={map='EM_ROUTE101',engineOptions={fireredGenEncounterPool=17},flags={}}
local player={cellX=0,cellY=0,px=0,py=0}
local behavior,water,walkable,void,warp=2,false,true,false,false
local collision={_mapDef={mapType=1},behavior=function()return behavior end,
  isWater=function()return water end,isWalkable=function()return walkable end,
  inBounds=function(x,y)return not void and x>=-6 and x<=6 and y>=-6 and y<=6 end,
  warpAt=function()return warp end}
local native={land={slots={{species=261+25,minLevel=3,maxLevel=5}}},
  water={slots={{species=129,minLevel=5,maxLevel=10}}}}
local roster=data('encounters/roster.lua')
local names,nationals={},{ }
for _,mon in ipairs(roster)do
  local slot=mon.id<=251 and mon.id or mon.id<=386 and mon.id+25 or mon.id+64
  names[mon.name]=slot;nationals[slot]=mon.id
end
local iconDraws,textDraws,lastBattle=0,0,nil
local icon={image={},quads={[0]={},[1]={}},frames=2,w=32,h=32}
local P={national=function(s)return nationals[s]end,
  speciesFromName=function(n)return names[n]end,
  speciesFromNational=function(n)return names[roster[n].name] end,
  name=function(s)return roster[nationals[s]].name end,
  keyName=function(s)return nationals[s] and roster[nationals[s]].name end,
  movesAtLevel=function()return {33,45},{35,40}end,
  abilities=function()return {1,2}end,abilityName=function(n)return 'ABILITY'..n end,
  moveName=function(n)return 'MOVE'..n end,movePp=function()return 35 end,
  icon=function()return icon end,_speciesMeta={}}
local Bridge={start=function(_,_,foe,opts)lastBattle={foe=foe,opts=opts};return true end}
function Bridge.startWild(owner,game,foe,opts)
  opts.wild=true;return Bridge.start(owner,game,foe,opts)
end
local top
local stack={push=function(id,layer)top={id=id,layer=layer}end,
  pop=function()top=nil end,has=function(id)return top and top.id==id end,
  top=function()return top end,busy=function()return top~=nil end}
local modules={
  ['src.core.GameVersion']={get=function()return gameId end,generation=function()return 3 end},
  ['src.core.game3.runtime']={getSession=function()return session end},
  ['src.core.game3.options']={block=function(o)return o end},
  ['src.core.game3.pokemon']=P,['src.core.game3.player']=player,
  ['src.core.game3.collision']=collision,['src.core.game3.map']={current={}},
  ['src.core.game3.battle']={isActive=function()return false end},
  ['src.core.game3.battle_bridge']=Bridge,
  ['src.core.game3.encounters']={tableFor=function()return native end},
  ['src.core.game3.mb']={id=function(name)return ({TALL_GRASS=2,LONG_GRASS=0x103,
    ASHGRASS=0x124,DEEP_SAND=0x106,SEAWEED=0x22,SEAWEED_NO_SURFACING=0x12a})[name]end},
  ['src.core.game3.profile']={forSession=function()return {id=gameId}end},
  ['src.core.game3.constants']={of=function()return {require=function()return 0x864 end}end},
  ['src.core.game3.scripting.space']={isActive=function()return false end},
  ['src.core.game3.scripting.flags']={getFlag=function()return false end},
  ['src.import.gba.map_catalog']={resolve=function(m)return m end},
  ['src.ui.game3.stack']=stack,
  ['src.ui.game3.window']={printPx=function()textDraws=textDraws+1 end},
  ['src.ui.game3.frlg_font']={measure=function(s)return #s*6 end},
  ['src.core.game3.field_effects']={tallGrassAt=function()end,clearTallGrass=function()end},
}
for name,value in pairs(modules)do package.loaded[name]=value end
love={graphics={setColor=function()end,rectangle=function()end,push=function()end,
  pop=function()end,setScissor=function()end,translate=function()end,scale=function()end,
  ellipse=function()end,draw=function(image)if image==icon.image then iconDraws=iconDraws+1 end end,
  newImage=function()return {setFilter=function()end}end},
  image={newImageData=function()return {setPixel=function()end}end}}
local dex={exports={},read=function(_,path)return read(dexRoot..'/encounters/'..path)end,
  log={warn=function()end,info=function()end}}
assert(loadfile(dexRoot..'/encounters/main.lua'))()(dex)
local installed={['1025dex']=dex}
local hooks,events,save={}, {}, {}
local mod={generation=3,exports={},content={pokemon={each=function()return function()end end}},
  read=function(_,path)return read(path)end,find=function(_,id)return installed[id]end,
  options={define=function()end,get=function()end},
  save={get=function(_,key)return save[key]end,set=function(_,key,v)save[key]=v end},
  hooks={wrap=function(_,name,fn)hooks[name]=fn end},
  events={on=function(_,name,fn)events[name]=fn end},log={info=function()end,warn=function()end}}
mod.game={data={pokemon={}},save={party={{hp=10}}}}
local G=assert(loadfile('src/gameboy.lua'))().bind(assert(loadfile('src/gen3.lua'))(),mod)
local I=assert(loadfile('src/identity.lua'))().new(mod,G)
local D=assert(loadfile('src/data.lua'))();D.init(G,mod,I)
-- Canonical Emerald terrain (not raw ROM IDs), obstacles, warps and water.
for _,version in ipairs({'firered','leafgreen','emerald'})do
  gameId=version
  for _,b in ipairs({2,0xd1,0x103,0x124,0x106,0x03,0x22,0x12a,0})do
    behavior=b;water=false;walkable=true
    local expected=b==2 or b==0xd1 or version=='emerald' and (b==0x103 or b==0x124 or b==0x106)
    eq(D.tileQuery('land').isTarget(0,0),expected,'land terrain '..version)
    eq(D.tileQuery('water').isTarget(0,0),false,'dry water search')
  end
end
gameId='emerald';behavior=2
for _,block in ipairs({'void','warp','wall'})do
  void=block=='void';warp=block=='warp';walkable=block~='wall'
  eq(D.tileQuery('land').isTarget(0,0),false,'blocked '..block)
end
void=false;warp=false;walkable=true;water=true
eq(D.tileQuery('water').isTarget(0,0),true,'surf search')
eq(D.tileQuery('land').isTarget(0,0),false,'water excluded from land')
collision._mapDef.mapType=5;water=false
for _,b in ipairs({0x22,0x12a,0,2})do
  behavior=b
  eq(D.tileQuery('water').isTarget(0,0),b==0x22 or b==0x12a,'underwater seaweed')
  eq(D.tileQuery('land').isTarget(0,0),false,'underwater is never land')
end
behavior=0x22;walkable=false
eq(D.tileQuery('water').isTarget(0,0),false,'blocked underwater')
walkable=true;collision._mapDef.mapType=1
-- All actual Hoenn locations and all 17 selections through DexNav's data API.
local Policy=data('encounters/policy.lua');local pools=0
local locations=data('encounters/locations.lua')
for _,loc in ipairs(data('encounters/hoenn_locations.lua'))do locations[#locations+1]=loc end
for _,loc in ipairs(locations)do
  for selection=1,#Policy.choices do
    session.engineOptions.fireredGenEncounterPool=selection
    local record=D.encounters(loc.map)
    if loc.map:match('^FR_') then
      local lg=D.encounters(loc.map:gsub('^FR_','LG_'))
      eq(#D.speciesList(record,'land'),#D.speciesList(lg,'land'),'LG alias land pools')
      eq(#D.speciesList(record,'water'),#D.speciesList(lg,'water'),'LG alias water pools')
    end
    for _,terrain in ipairs({'land','water'})do
      for _,row in ipairs(D.speciesList(record,terrain))do
        local mon=roster[row.species]
        local choice=Policy.choices[selection]
        local starter=loc.map=='FR_ROUTE_1' and terrain=='land' and (mon.id==1 or mon.id==4 or mon.id==7 or mon.id==25)
        local resident=loc.residentSlots and terrain=='land' and (mon.id==50 or mon.id==51)
        eq(starter or resident or (mon.id>=choice.first and mon.id<=choice.last),true,'active generation selection')
        local policySlots=dex.exports.dexnavEncounters(loc.map)[terrain]
        local present=false
        for _,entry in ipairs(policySlots and policySlots.slots or {}) do if P.national(entry.species)==mon.id then present=true end end
        eq(present,true,'DexNav matches actual pool including native habitat exceptions')
        eq(mon.special,false,'pre-League special gating')
        local slot=D.slotFor(record,terrain,row.species)
        eq(slot~=nil and slot.min<=slot.max,true,'custom slot levels')
        pools=pools+1
      end
    end
  end
end
installed.wildfollowers={exports={dexnavEncounters=function()return native end,
  dexnavTileAllowed=function()return false end}}
eq(D.encounters('EM_ROUTE101').land.slots[1].species,
 P.national(dex.exports.dexnavEncounters('EM_ROUTE101').land.slots[1].species),'1025Dex live pool priority')
eq(D.tileQuery('land').isTarget(0,0),false,'WildFollowers tile policy priority')
installed.wildfollowers=nil;installed['1025dex']=nil
eq(D.encounters('EM_ROUTE101').land.slots[1].species,P.national(native.land.slots[1].species),'vanilla encounter fallback')
installed['1025dex']=dex
-- Engine terrain classification must cover bare-floor caves and indoors,
-- and be independent of WildFollowers optional spawn/indoor settings.
local E=modules['src.core.game3.encounters']
local nativeKind='land'
E.terrainAt=function()return nativeKind end
installed.wildfollowers={exports={dexnavTileAllowed=function()return false end}}
for _,version in ipairs({'firered','leafgreen','emerald'})do
  gameId=version;behavior=0;water=false
  for _,mapType in ipairs({4,8})do
    collision._mapDef.mapType=mapType
    eq(D.tileQuery('land').isTarget(0,0),true,'native bare dungeon floor '..version)
  end
end
nativeKind=nil;eq(D.tileQuery('land').isTarget(0,0),false,'native non-encounter floor')
nativeKind='land';warp=true;eq(D.tileQuery('land').isTarget(0,0),false,'native dungeon warp')
warp=false;walkable=false;eq(D.tileQuery('land').isTarget(0,0),false,'native dungeon wall')
walkable=true;installed.wildfollowers=nil
E.terrainAt=nil
for _,mapType in ipairs({4,8})do
  collision._mapDef.mapType=mapType
  eq(D.tileQuery('land').isTarget(0,0),true,'older engine bare floor fallback')
end
local Scan=assert(loadfile('src/scan.lua'))()
local x,y=Scan.pick({px=50,py=50,terrain='land',cave=true,
 roll=function(n)return n-1 end,isTarget=function(x,y)return x==51 and y==50 end})
eq(x,51,'high-coordinate cave sparse fallback x');eq(y,50,'sparse fallback y')
x=Scan.pick({px=0,py=0,terrain='water',roll=function(n)return n-1 end,
 isTarget=function(x,y)return x==1 and y==0 end})
eq(x,1,'single surf tile fallback')
x=Scan.pick({px=0,py=0,terrain='land',roll=function()return 0 end,
 isTarget=function(x,y)return x==0 and y==0 end})
eq(x,nil,'player tile excluded')
x=Scan.pick({px=0,py=0,terrain='land',roll=function()return 0 end,
 isTarget=function()return false end})
eq(x,nil,'no encounter tiles still fails')
mod.world={current=function()return {}end}
session.map='EM_ROUTE101';eq(D.mapId(),session.map,'world map ID falls back to session')
mod.world=nil
-- Load the entire mod, draw its modal screen/HUD and walk into a search.
session.engineOptions.fireredGenEncounterPool=17
assert(loadfile('main.lua'))()(mod)
mod.exports.openScreen({})
eq(top.id,'gen3_dexnav','Emerald modal stack')
top.layer.draw();eq(iconDraws>0 and textDraws>0,true,'custom icons and shared UI draw')
top.layer.handleInput({wasPressed=function(_,key)return key=='b' end})
eq(top,nil,'modal closes')
math.randomseed(111)
for _,scenario in ipairs({{2,'land','EM_ROUTE101',1},{0x103,'land','EM_ROUTE119',1},
  {0x124,'land','EM_ROUTE113',1},{0x106,'land','EM_ROUTE111',1},
  {0,'water','EM_ROUTE104',1},{0x22,'water','EM_UNDERWATER_ROUTE124',5},
  {0,'land','FR_MT_MOON_1F',4},{0,'land','LG_POKEMON_TOWER_3F',8},
  {0,'land','FR_POKEMON_MANSION_1F',8},{0,'land','EM_GRANITE_CAVE_1F',4}})do
  local terrain,mapId,mapType
  behavior,terrain,mapId,mapType=(table.unpack or unpack)(scenario)
  gameId=mapId:match('^EM_') and 'emerald' or mapId:match('^LG_') and 'leafgreen' or 'firered'
  session.map=mapId;collision._mapDef.mapType=mapType;water=terrain=='water' and mapType~=5
  player.cellX,player.cellY=0,0
  local species=mod.exports.localSpecies(mapId,terrain)[1].species
  mod.exports.setSearchLevel(species,50)
  eq(mod.exports.startSearch(mod.game,species,terrain),true,'search starts '..mapId)
  local state=mod.exports.state();eq(state.species,species,'search identity')
  hooks['render.hud'](function()end,{}, {gameWidth=240,gameHeight=160})
  player.cellX,player.cellY=state.tile.x,state.tile.y
  hooks['core.update'](function()end,mod.game,.1)
  eq(mod.exports.state(),nil,'arrival ends search')
  eq(P.national(lastBattle.foe.species),species,'battle keeps selected species')
  eq(lastBattle.foe.level,state.level,'battle keeps generated level')
  eq(lastBattle.opts.__completeDexExact,true,'Dex replacement bypass')
  eq(#lastBattle.foe.moves,4,'generated moves handed to battle')
  eq(type(lastBattle.foe.ivs),'table','generated IVs handed to battle')
  eq(mod.exports.searchLevel(species),51,'search level persists')
end
print(('PASS: %d assertions; %d FR/LG/Hoenn pool entries, all 17 selections; dungeon/field terrain, UI, icons and exact battles.'):format(checks,pools))
