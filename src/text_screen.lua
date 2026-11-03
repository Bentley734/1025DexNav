-- Native 160x144 Game Boy list. No sprite atlas or fractional UI scaling.
local Screen = {}
local engine, Data, current, active
local ID, PAGE = 'gen3_dexnav', 5
function Screen.init(adapter, _, data) engine, Data = adapter, data end
function Screen.isOpen() return current ~= nil and engine.hasLayer(ID) end
function Screen.close() current=nil; engine.popLayer(ID) end
function Screen.reset() Screen.close() end
function Screen.setSearchActive(value) active=value==true end
function Screen.isSearchActive() return active==true end
local function rows(state) return state.ctx[state.terrain] end
local function clip(font,text,width)
  text=tostring(text or '')
  local spans=font.split(text)
  if #spans>width then return text:sub(1,spans[width].to) end
  return text
end
function Screen.open(_,ctx)
  Screen.reset()
  ctx.land=Data.speciesList(ctx.encounters,'land')
  ctx.water=Data.speciesList(ctx.encounters,'water')
  local state={ctx=ctx,terrain=#ctx.land>0 and 'land' or 'water',index=1}
  local reg=ctx.registered
  if reg then
    for i,row in ipairs(ctx[reg.terrain] or {}) do
      if row.species==reg.species then state.terrain=reg.terrain;state.index=i;break end
    end
  end
  function state.update() end
  function state.handleInput(input)
    if input:wasPressed('b') or input:wasPressed('start') then Screen.close();return end
    local list=rows(state)
    if input:wasPressed('up') and #list>0 then state.index=(state.index-2)%#list+1
    elseif input:wasPressed('down') and #list>0 then state.index=state.index%#list+1
    elseif input:wasPressed('left') or input:wasPressed('right') then
      state.terrain=state.terrain=='land' and 'water' or 'land';state.index=1;state.status=nil
    elseif input:wasPressed('l') and #list>0 then state.index=math.max(1,state.index-PAGE)
    elseif input:wasPressed('r') and #list>0 then state.index=math.min(#list,state.index+PAGE)
    elseif input:wasPressed('select') and list[state.index] then
      local row=list[state.index];ctx.onRegister(row.species,state.terrain);state.status='Registered!'
    elseif input:wasPressed('a') and list[state.index] then
      local row=list[state.index]
      -- Release modal ownership before starting a field search.
      Screen.close();ctx.onSearch(row.species,state.terrain)
    end
  end
  function state.draw()
    local F=engine.try('src.render.Font'); if not F then return end
    love.graphics.push('all');love.graphics.setColor(1,1,1,1)
    F.drawBox(0,0,20,18)
    F.draw('DEXNAV '..state.terrain:upper(),8,8)
    F.draw('LEFT/RIGHT: AREA',8,24)
    local list=rows(state)
    local first=math.floor((state.index-1)/PAGE)*PAGE+1
    for line=0,PAGE-1 do
      local row=list[first+line]
      if row then
        F.draw((first+line==state.index and '>' or ' ')..clip(F,row.name,12),8,40+line*12)
        F.draw(tostring(ctx.searchLevel(row.species)),120,40+line*12)
      end
    end
    if #list==0 then F.draw('No encounters here',8,48) end
    local row=list[state.index]
    local page=state.index..'/'..#list
    F.draw(clip(F,state.status or (row and ('No.'..row.species..' LV '..ctx.searchLevel(row.species)..' '..page) or 'Try the other area'),18),8,104)
    F.draw('A SEARCH  SEL REG',8,120)
    F.draw('B BACK  UP/DN PICK',8,128)
    love.graphics.pop()
  end
  if not engine.pushLayer(ID,state) then return false end
  current=state;return true
end
return Screen
