-- GB field readout uses the same pixel grid and font as native menus.
local Hud, engine = {}, nil
function Hud.init(adapter) engine=adapter end
local function clip(font,text,limit)
  text=tostring(text or '')
  local spans=font.split(text)
  return #spans>limit and text:sub(1,spans[limit].to) or text
end
function Hud.draw(_,viewport,opts)
  local search=opts and opts.search
  if not search or opts.enabled==false or opts.busy and opts.busy() then return end
  if not (love and love.graphics and viewport) then return end
  local F=engine.try('src.render.Font');if not F then return end
  local G=love.graphics
  G.push('all');G.translate(viewport.gameX or 0,viewport.gameY or 0)
  G.scale((viewport.gameWidth or 160)/160,(viewport.gameHeight or 144)/144)
  if search.tile and not search.customMarker then
    local x,y=engine.markerPoint(search.tile.x,search.tile.y)
    if x then
      x,y=math.floor(x*160/240),math.floor(y*144/160)-14
      G.setColor(1,0.9,0.15,1)
      G.rectangle('fill',x-3,y,6,2);G.rectangle('fill',x-1,y+2,2,2)
    end
  end
  G.setColor(1,1,1,1);F.drawBox(0,14,20,4)
  F.draw(clip(F,search.name,11),8,120)
  F.draw('Lv'..tostring(search.spec.level),104,120)
  local details=search.level>1 and search.spec.moveName or 'Searching...'
  if search.level>4 then details=clip(F,details,12)..' P'..tostring(search.spec.potential or 0) end
  F.draw(clip(F,details,18),8,128)
  G.pop()
end
return Hud
