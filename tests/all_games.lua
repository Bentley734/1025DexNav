-- Run from the mod folder. Native map and GameVersion code; isolated services.
local engineRoot=assert(arg[1]);local dexRoot=assert(arg[2])
package.path=engineRoot..'/?.lua;'..package.path
local checks=0
local function eq(actual,want,message) checks=checks+1;assert(actual==want,message..': '..tostring(actual)..' ~= '..tostring(want)) end
local function module(path) return assert(loadfile(path))() end
local Version=require('src.core.GameVersion')
local games={'red','blue','yellow','gold','silver','crystal','ruby','sapphire','firered','leafgreen','emerald'}
for _,id in ipairs(games) do
 Version.set(id)
 local gen=Version.generation()
 local moduleCache={['src.core.GameVersion']=Version}
 local mapId='ROUTE_TEST'
 local nativeByDex={[1]=1,[25]=25,[252]=277,[358]=411,[386]=410,[399]=463,[1025]=1089}
 local dexByNative={};for n,s in pairs(nativeByDex) do dexByNative[s]=n end
 local rows={};for n in pairs(nativeByDex) do rows['MON'..n]={dex=n,name='Mon '..n,baseStats={hp=40,attack=40,defense=40,speed=40,special=40,spAttack=40,spDefense=40},types={'NORMAL'},growthRate='MEDIUM_FAST',level1Moves={'TACKLE'},learnset={{level=1,move='TACKLE'}},genderRatio=127} end
 local P={national=function(s)return dexByNative[s] end,speciesFromNational=function(n)return nativeByDex[n] end,
 speciesFromName=function(key)return nativeByDex[tonumber(key:match('MON(%d+)'))] end,
 keyName=function(s)return dexByNative[s] and 'MON'..dexByNative[s] end,name=function(s)return rows['MON'..dexByNative[s]].name end,
 movesAtLevel=function()return {33},{35} end,movePp=function()return 35 end,moveName=function()return 'Tackle' end,abilities=function()return {1,2} end,abilityName=function()return 'Ability' end}
 local storage,events,hooks={},{},{}
 local stack={states={},push=function(self,s)table.insert(self.states,s)end,pop=function(self)return table.remove(self.states)end,top=function(self)return self.states[#self.states]end}
 local game={data={pokemon=rows,moves={TACKLE={name='Tackle',pp=35}},items={},field={indoorEncounters={firstIndoorMap=100,excludedTileset='FOREST'}}},save={party={{hp=20}}},stack=stack}
 local nativeRecord={grass={rate=30,slots={{species=gen==3 and 277 or 'MON252',level=5}}},water={rate=20,slots={{species=gen==3 and 25 or 'MON25',level=7}}}}
 game.data.encounters={[mapId]=nativeRecord}
 local map
 if gen==1 then
  map=require('src.world.Map').new({id=mapId,index=1,width=12,height=12,blocks={},tileset='OVERWORLD',warps={}}, {grassTile=2,walkable={2},waterTiles={3}})
  function map:cellTile(x,y)return x==8 and 3 or 2 end
 elseif gen==2 then
  map=require('src.world.gen2.Map').new({id=mapId,width=12,height=12,blocks={},warps={},environment='ROUTE'}, {collision={}})
  function map:cellCollision(x,y)return x==8 and 0x29 or 0x18 end
 end
 local player={cellX=4,cellY=4,px=64,py=64}
 local world={map=map,player=player,entities={},npcs={},isOverworld=true}
 if gen==1 then stack:push(world) end
 if gen==2 then
  world.encounters={grass={[mapId]={rates={DAY=30,NITE=30},slots={DAY={{species='MON252',level=5}},NITE={{species='MON25',level=9}}}}},water={[mapId]=nativeRecord.water}}
  world.daytime='DAY'
 end
 local lastBattle
 local mod={id='gen3_dexnav',generation=gen,game=game,exports={},log={info=function()end,warn=function()end}}
 function mod:read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
 mod.content={pokemon={get=function(_,key)return rows[key]end},encounters={get=function(_,key)return game.data.encounters[key]end}}
 mod.save={get=function(_,key)return storage[key]end,set=function(_,key,value)storage[key]=value end}
 local quickMode='r'
 mod.options={define=function()end,get=function(_,key)return key=='quick_key' and quickMode or nil end}
 mod.hooks={wrap=function(_,name,fn)hooks[name]=fn end}
 mod.events={on=function(_,name,fn)events[name]=events[name] or {};table.insert(events[name],fn)end}
 local function emit(name,payload)for _,fn in ipairs(events[name] or {})do fn(payload)end end
 local identityAPI={numbering='national',nationalOfSpecies=function(s)
  return gen==3 and dexByNative[s] or rows[s] and rows[s].dex
 end,speciesFromNational=function(n)return gen==3 and nativeByDex[n] or rows['MON'..n] and 'MON'..n end}
 local peer={speciesNumbers=identityAPI,vanillaWildMoves=gen==3 and function(s)eq(s,277,'move resolver receives native Treecko');return {33},{35} end or nil,
 gbEncounterAdditions=function()return {{id=399,gate=3}},{lo=3,hi=9}end}
 local wf={status=function()return {game=id,actors={{x=5,y=5}},followers={}}end}
 function mod:find(name)return name=='1025dex' and {exports=peer} or name=='wildfollowers' and {exports=wf} or nil end
 mod.world={overworld=function()return world end,current=function()return {mapId=mapId,x=player.cellX,y=player.cellY}end,
 startWildBattle=function(_,key,level)
  lastBattle={enemy={mon={species=key}}};emit('battle.started',{battle=lastBattle});return true
 end,queueScript=function()return true end}
 function world:startBattle(opts)lastBattle=opts;return true end
 local collision={_mapDef={mapType=1},inBounds=function(x,y)return x>=0 and y>=0 and x<24 and y<24 end,warpAt=function()end,
 isWalkable=function()return true end,isWater=function(x)return x==8 end,behavior=function()return 2 end}
 moduleCache['src.core.game3.pokemon']=P
 moduleCache['src.core.game3.runtime']={getSession=function()return game.session end}
 game.session={map=mapId}
 moduleCache['src.core.game3.map']={current={}}
 moduleCache['src.core.game3.player']=player
 moduleCache['src.core.game3.collision']=collision
 moduleCache['src.core.game3.encounters']={tableFor=function()return nativeRecord end,terrainAt=function(x)return x==8 and 'water' or 'land' end}
 moduleCache['src.core.game3.battle']={isActive=function()return false end}
 moduleCache['src.core.game3.battle_bridge']={startWild=function(_,_,foe)lastBattle=foe;return true end}
 local uiStack={};moduleCache['src.ui.game3.stack']={push=function(k,v)uiStack[k]=v end,pop=function(k)uiStack[k]=nil end,has=function(k)return uiStack[k]~=nil end,busy=function()return next(uiStack)~=nil end}
 local nativeRequire=require
 _G.require=function(name)if moduleCache[name] then return moduleCache[name] end
  if name:find('game3',1,true) or name:find('src.ui.',1,true) then error('unavailable test service '..name) end
  return nativeRequire(name)
 end
 -- Use the actual 1025Dex National identity export, not an offset shim.
 local dexMod={exports=peer,game=game,content=mod.content,read=function(_,path)
  local f=assert(io.open(dexRoot..'/'..path));local s=f:read('*a');f:close();return s
 end}
 module(dexRoot..'/compat/species_numbers.lua')(dexMod)
 -- Migration must map nonuniform native slots, without overwriting old fields.
 if gen==3 then storage.search_levels={['277']=12,['411']=17,['410']=22,['463']=35};storage.registered={species=411,terrain='land'} end
 local NativeInput, textDraws
 if gen<3 then
  NativeInput=nativeRequire('src.core.Input');NativeInput:init();game.input=NativeInput
  local F=nativeRequire('src.render.Font');textDraws={}
  moduleCache['src.render.Font']={split=F.split,drawBox=function()end,draw=function(text,x,y)
   eq(x%1,0,'text x is native integer');eq(y%1,0,'text y is native integer')
   eq(x+#F.split(text)*8<=152,true,'text fits native right border')
   textDraws[#textDraws+1]=text
  end}
  love={graphics={push=function()end,pop=function()end,setColor=function()end,
   translate=function()end,scale=function(x,y)eq(x%1,0,'no fractional UI x scale');eq(y%1,0,'no fractional UI y scale')end,
   rectangle=function()end,draw=function()error('GB DexNav must not draw sprites')end}}
 end
 module('main.lua')(mod)
 eq(mod.exports.numbering,'national',id..' public numbering')
 eq(mod.exports.searchLevel(252),gen==3 and 12 or 0,'Treecko migration')
 if gen==3 then eq(mod.exports.searchLevel(358),17,'Chimecho migration');eq(mod.exports.searchLevel(386),22,'Deoxys migration');eq(storage.search_levels['411'],17,'legacy preserved') end
 eq(mod.exports.setSearchLevel(252,24),24,'National progress');eq(mod.exports.setSearchLevel(0,1),nil,'invalid number rejected')
 local list=mod.exports.localSpecies(mapId,'land')
 eq(list[1].species,252,id..' pool is National')
 if gen<3 then eq(list[2].species,399,'GB habitat addition') end
 if gen<3 then
  -- Native timing: input.step hook precedes promotion and registered-item use.
  NativeInput:keypressed('tab');NativeInput:keyreleased('tab')
  eq(NativeInput:wasPressed('select'),false,'edge not promoted yet')
  hooks['input.step'](function()end,game,1/60)
  local menu=stack:top();eq(menu and menu.dexnav,true,id..' SELECT opens text list')
  NativeInput:step()
  eq(NativeInput:wasPressed('select'),false,'opening edge cannot activate registered item')
  menu:update(1/60);menu:draw()
  eq(#textDraws>0,true,'text list rendered')
   NativeInput:sourcePress('select','test');NativeInput:sourceRelease('select','test')
  hooks['input.step'](function()end,game,1/60);NativeInput:step();menu:update(1/60)
  eq(storage.national_progress.registered.species,252,'menu SELECT registers National identity')
  NativeInput:sourcePress('down','test');NativeInput:sourceRelease('down','test')
  NativeInput:step();menu:update(1/60);menu:draw()
  NativeInput:sourcePress('a','test');NativeInput:sourceRelease('a','test')
  NativeInput:step();menu:update(1/60)
  eq(mod.exports.state().species,399,'text list A searches selected row')
  eq(stack:top()==menu,false,'search releases modal ownership')
  hooks['render.hud'](function()end,game,{gameWidth=480,gameHeight=432})
  mod.exports.stopSearch();NativeInput:reset()
  -- Controller route uses the same shortcut and does not reuse last frame.
  NativeInput:gamepadpressed(nil,'back');NativeInput:gamepadreleased(nil,'back')
  hooks['input.step'](function()end,game,1/60);NativeInput:step()
  eq(stack:top().dexnav,true,'controller SELECT opens list')
  NativeInput:sourcePress('b','test');NativeInput:sourceRelease('b','test')
  NativeInput:step();stack:top():update(1/60)
  eq(stack:top() and stack:top().dexnav or false,false,'B closes list')
  NativeInput:reset()
  quickMode='select';NativeInput:keypressed('tab')
  for frame=1,25 do hooks['input.step'](function()end,game,1/60);NativeInput:step() end
  eq(stack:top().dexnav,true,'SELECT hold opens list')
  NativeInput:keyreleased('tab');NativeInput:sourcePress('b','test');NativeInput:sourceRelease('b','test')
  NativeInput:step();stack:top():update(1/60)
  NativeInput:reset();quickMode='r'
 end
 eq(mod.exports.startSearch(game,252,'land'),true,id..' search starts')
 local state=mod.exports.state();eq(state.species,252,'public search identity')
 eq(state.tile.x==5 and state.tile.y==5,false,'WildFollowers occupied tile excluded')
 player.cellX,player.cellY=state.tile.x,state.tile.y
 eq(hooks['encounter.roll'](function()return {species='ordinary'}end,{}, {mapId=mapId}),nil,'hidden tile reserves ordinary battle')
 local roamer={roamer=true}
 eq(hooks['encounter.roll'](function()return roamer end,{}, {mapId=mapId}),roamer,'roamer retained')
 hooks['core.update'](function()end,game,0.016)
 eq(lastBattle~=nil,true,id..' battle starts')
 if gen==3 then eq(lastBattle.species,277,'GBA battle gets native slot')
 elseif gen==2 then eq(lastBattle.wild.species,'MON252','GBC battle native key');eq(lastBattle.wild.moves[1].id,'TACKLE','GBC move shape');eq(lastBattle.wild.dvs.attack<=15,true,'GBC DVs')
 else eq(lastBattle.enemy.mon.species,'MON252','GB battle native key');eq(lastBattle.enemy.mon.moves[1].id,'TACKLE','GB move shape');eq(lastBattle.enemy.curStats,lastBattle.enemy.mon.stats,'battle stats refresh') end
 eq(mod.exports.searchLevel(252),25,'battle adds progress')
 if gen==3 then
  game.session.version='emerald'
  eq(mod.exports.speciesNumbers.native(358),411,'Hoennto native identity remains exact')
  local adapter=module('src/gameboy.lua').bind(module('src/gen3.lua'),mod)
  eq(adapter.gameId(),'emerald','active campaign cartridge overrides launcher identity')
  game.session.version=nil
 end
 eq(mod.exports.state(),nil,'battle clears search')
 eq(mod.exports.startSearch(game,252,'land'),true,'second search')
 mapId='OTHER_REGION';hooks['core.update'](function()end,game,0.016)
 eq(mod.exports.state(),nil,'campaign map switch clears search')
 storage={national_progress={schema=1,levels={['252']=66}}};emit('save.loaded',{})
 eq(mod.exports.searchLevel(252),66,'new save cannot inherit cached progress')
 if gen==2 then
  mapId='ROUTE_TEST';world.daytime='NITE'
  eq(mod.exports.localSpecies(mapId,'land')[1].species,25,'night pool changes')
 end
 _G.require=nativeRequire
 print('PASS '..id)
end
print('PASS '..checks..' all-game compatibility assertions')
