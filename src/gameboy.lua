-- Independently implemented adapter for the engine's two Game Boy worlds.
local GB = {}
function GB.bind(engine, mod)
  local original = {}
  for key, fn in pairs(engine) do original[key] = fn end
  local layers = {}
  function engine.overworld()
    local world = mod.world
    return world and world.overworld and world:overworld()
  end
  function engine.generation()
    local V = engine.try('src.core.GameVersion')
    return V and V.generation and V.generation() or mod.generation or 3
  end
  local function gb() return engine.generation() < 3 end
  function engine.playerCell()
    if not gb() then return original.playerCell() end
    local w = engine.overworld(); local p = w and w.player
    return p and {x=p.cellX, y=p.cellY, facing=p.facing}
  end
  function engine.playerPixels()
    if not gb() then return original.playerPixels() end
    local w = engine.overworld(); local p = w and w.player
    return p and {px=p.px or p.cellX*16, py=p.py or p.cellY*16}
  end
  function engine.fieldReady()
    if not gb() then return original.fieldReady() end
    local w = engine.overworld()
    return w ~= nil and w.map ~= nil and not w.battleActive
  end
  function engine.busy()
    if not gb() then return original.busy() end
    local w, game = engine.overworld(), mod.game
    if not w or not game then return true end
    if w.busy and w:busy() then return true end
    if w.transitioning or w.engaging or w.battleActive or w.flyAnim or w.teleportOut
      or w.healAnim or w.emote or w.pikaHop then return true end
    if w.runner and w.runner.isRunning and w.runner:isRunning() then return true end
    if #(w.scriptMoves or {}) > 0 then return true end
    local top = game.stack and game.stack:top()
    if engine.generation() == 1 then return top ~= w end
    -- Gen 2's field is a service, while every menu and battle is a stack state.
    return top ~= nil
  end
  function engine.say(game, text)
    if not gb() then return original.say(game, text) end
    local w = mod.world
    if not (w and w.queueScript) then return false end
    local ok, result = pcall(w.queueScript, w, {{'text', text}})
    return ok and result == true
  end
  function engine.window()
    if not gb() then return original.window() end
    local F = engine.try('src.render.Font')
    return F and {printPx=function(text,x,y,opts)
      local limit = math.floor((opts and opts.maxWidth or 240)/8)
      F.draw(tostring(text):sub(1,limit),x,y)
    end}
  end
  function engine.font()
    if not gb() then return original.font() end
    return {measure=function(text) return #tostring(text)*8 end}
  end
  function engine.display() return gb() and {W=160,H=144} or original.display() end
  function engine.pushLayer(id, layer)
    if not gb() then return original.pushLayer(id,layer) end
    local game = mod.game
    if not (game and game.stack) or engine.busy() then return false end
    local state = {id=id, isOpaque=true, dexnav=true}
    function state:update(dt) layer.update(dt); layer.handleInput(game.input) end
    function state:draw()
      layer.draw()
    end
    layers[id] = state; game.stack:push(state); return true
  end
  function engine.popLayer(id)
    if not gb() then return original.popLayer(id) end
    local stack = mod.game and mod.game.stack
    local state = layers[id]; layers[id] = nil
    if not stack or not state then return end
    if stack:top() == state then stack:pop(); return end
    -- Reset only our state; a campaign hand-off may have pushed another screen.
    for i = #(stack.states or {}), 1, -1 do
      if stack.states[i] == state then table.remove(stack.states,i); break end
    end
  end
  function engine.hasLayer(id)
    if not gb() then return original.hasLayer(id) end
    for _, state in ipairs(mod.game and mod.game.stack and mod.game.stack.states or {}) do
      if state == layers[id] then return true end
    end
    return false
  end
  function engine.drawIcon(n, x, y, size, elapsed)
    if not gb() then return false end
    local I = engine.try('src.ui.PokemonIcon')
    local key = engine.identity and engine.identity.native(n)
    if not I or not key then return false end
    love.graphics.push('all'); love.graphics.translate(x,y); love.graphics.scale(size/16,size/16)
    local ok = I.draw(mod.game,{species=key,hp=1,maxHp=1},0,0,{counter=(elapsed or 0)*60})
    love.graphics.pop(); return ok == true
  end
  function engine.markerPoint(x,y)
    if not gb() then return nil end
    local w=engine.overworld();local camera=w and w.camera
    if not camera then return nil end
    return (x*16-math.floor(camera.x)+8)*240/160,
      (y*16-math.floor(camera.y)+12)*160/144
  end
  -- The screen-space marker belongs to DexNav. Never take the player's grass FX.
  engine.clearTallGrass = function() end
  engine.rustleFrame = function() end
  function engine.pokemonIcon(n)
    if gb() then return nil end
    local native = engine.identity and engine.identity.native(n)
    return native and original.pokemonIcon(native)
  end
  return engine
end
return GB
