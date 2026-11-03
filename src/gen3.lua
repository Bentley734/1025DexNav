-- pcall-guarded door to the shared Gen 3 engine modules this mod draws with and
-- hands battles to.  Every require is cached and every caller tolerates nil,
-- so a module that moves in a future engine build costs the feature, not the
-- boot.  Declared in the manifest as engine_internals.
local Gen3 = {}

local cache = {}

--- pcall(require) with a false sentinel so a miss is cached, too.
local function try(name)
  local hit = cache[name]
  if hit ~= nil then return hit or nil end
  local ok, module = pcall(require, name)
  cache[name] = ok and module or false
  return ok and module or nil
end

Gen3.try = try
function Gen3.reset() cache = {} end

function Gen3.gameId()
  local V = try("src.core.GameVersion")
  if V and V.generation and V.generation() == 3 then
    local R = try("src.core.game3.runtime")
    local session = R and R.getSession and R.getSession()
    if session and session.version then return session.version end
  end
  return V and V.get and V.get() or nil
end

-- ------- the modules

function Gen3.pokemon() return try("src.core.game3.pokemon") end
function Gen3.items() return try("src.core.game3.items_data") end
function Gen3.collision() return try("src.core.game3.collision") end
function Gen3.map() return try("src.core.game3.map") end
function Gen3.player() return try("src.core.game3.player") end
function Gen3.battle() return try("src.core.game3.battle") end
function Gen3.battleBridge() return try("src.core.game3.battle_bridge") end
function Gen3.hud() return try("src.ui.game3.hud") end
function Gen3.stack() return try("src.ui.game3.stack") end
function Gen3.window() return try("src.ui.game3.window") end
function Gen3.font() return try("src.ui.game3.frlg_font") end
function Gen3.chrome() return try("src.ui.game3.chrome") end
function Gen3.display() return try("src.core.game3.display") end
function Gen3.message() return try("src.ui.game3.message") end
function Gen3.fieldEffects() return try("src.core.game3.field_effects") end

-- ------- state predicates

--- True when the overworld is live (a session exists, a map is loaded and no
--- battle is running) -- the same ground mod.world stands on.
function Gen3.fieldReady()
  local R = try("src.core.game3.runtime")
  local session = R and R.getSession and R.getSession()
  if not session then return false end
  local M = Gen3.map()
  if not (M and M.current) then return false end
  local B = Gen3.battle()
  if B and B.isActive and B.isActive() then return false end
  return true
end

--- The engine's own "something is on top of the field" predicate: battle,
--- message, choice, the modal UI stack, fades, any full-screen menu.
function Gen3.busy()
  local Hud = Gen3.hud()
  if Hud and Hud.busy then
    local ok, busy = pcall(Hud.busy)
    if ok then return busy == true end
  end
  local Stack = Gen3.stack()
  if Stack and Stack.busy and Stack.busy() then return true end
  local Message = Gen3.message()
  if Message and Message.isOpen and Message.isOpen() then return true end
  local B = Gen3.battle()
  if B and B.isActive and B.isActive() then return true end
  return false
end

--- Speak through the engine's native field textbox.  Returns false when the
--- message module is unavailable (headless tests) so callers can fall back.
function Gen3.say(game, text)
  local Hud = Gen3.hud()
  if not (Hud and Hud.openMessage and game) then return false end
  local ok = pcall(Hud.openMessage, game, text)
  return ok
end

-- ------- data helpers

function Gen3.playerCell()
  local P = Gen3.player()
  if P and type(P.cellX) == "number" and type(P.cellY) == "number" then
    return { x = P.cellX, y = P.cellY, facing = P.facing }
  end
  return nil
end

function Gen3.pokemonIcon(species)
  local P = Gen3.pokemon()
  if not (P and P.icon) then return nil end
  local ok, icon = pcall(P.icon, species)
  if ok then return icon end
  return nil
end

--- The player's pixel position (top-left of the 16x16 avatar), the anchor the
--- world camera is computed from.
function Gen3.playerPixels()
  local P = Gen3.player()
  if P and type(P.px) == "number" and type(P.py) == "number" then
    return { px = P.px, py = P.py }
  end
  return nil
end

--- The extracted field-effect engine: the tall-grass rustle is anchored to a
--- cell and drawn by the engine's own world pass.
function Gen3.tallGrassAt(cx, cy)
  local F = Gen3.fieldEffects()
  if F and F.tallGrassAt then pcall(F.tallGrassAt, cx, cy) end
end

function Gen3.clearTallGrass()
  local F = Gen3.fieldEffects()
  if F and F.clearTallGrass then pcall(F.clearTallGrass) end
end

--- Claim the engine's one tall-grass rustle slot for a cell and pin its
--- animation frame ourselves, so the grass can loop continuously instead of
--- playing once and parking on its last frame.
function Gen3.rustleFrame(cx, cy, step)
  local F = Gen3.fieldEffects()
  if not (F and F.tallGrassAt) then return end
  F.tallGrassAt(cx, cy)
  local fx = F._fx
  if fx and fx.cx == cx and fx.cy == cy then
    fx.step = math.floor(tonumber(step) or 0) % 5
    fx.timer = 0
  end
end

--- The engine's pret-parity RNG when it is loaded, math.random otherwise.
--- Returns an integer in [0, n-1], the C rand()%n contract.
function Gen3.roll(n)
  n = math.floor(tonumber(n) or 0)
  if n <= 0 then return 0 end
  local Rng = try("src.core.game3.rng")
  if Rng and Rng.Random then
    local ok, value = pcall(function() return Rng.Random() % n end)
    if ok and type(value) == "number" then return value end
  end
  return math.random(0, n - 1)
end

-- ------- the modal UI stack (the engine's own full-screen menu host)

function Gen3.pushLayer(id, layer)
  local Stack = Gen3.stack()
  if not Stack then return false end
  Stack.push(id, layer)
  return true
end

function Gen3.popLayer(id)
  local Stack = Gen3.stack()
  if Stack then Stack.pop(id) end
end

function Gen3.hasLayer(id)
  local Stack = Gen3.stack()
  return (Stack and Stack.has and Stack.has(id)) == true
end

--- True while the engine would route field input to our layer.
function Gen3.layerOnTop(id)
  local Stack = Gen3.stack()
  local top = Stack and Stack.top and Stack.top()
  return top ~= nil and top.id == id
end

return Gen3
