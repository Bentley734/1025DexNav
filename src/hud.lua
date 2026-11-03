-- The field HUD: a bottom strip over the FireRed frame, drawn from the
-- engine's render.hud hook (screen-space, LOVE window units).  Information
-- is gated by search level exactly like the reference's OAM icons:
--
--   search level > 1  first move
--   search level > 2  ability, held item (item only when one was rolled)
--   search level > 4  potential stars
--
-- The species icon sits at the left of the strip; without it the strip is
-- text-only and one line shorter.
local Hud = {}

local Gen3, Icons

function Hud.init(engine, icons)
  Gen3 = engine
  Icons = icons
end

local GAME_W, GAME_H = 240, 160

local WHITE = { fg = { 1, 1, 1, 1 }, shadow = { 0.30, 0.30, 0.36, 1 } }
local DIM = { fg = { 0.74, 0.76, 0.82, 1 }, shadow = { 0.24, 0.24, 0.30, 1 } }
local GOLD = { fg = { 1, 0.84, 0.20, 1 }, shadow = { 0.40, 0.30, 0.02, 1 } }
local ALERT = { fg = { 1, 0.55, 0.45, 1 }, shadow = { 0.42, 0.12, 0.10, 1 } }

local function print(text, px, py, colors, maxWidth)
  local W = Gen3.window()
  if W and W.printPx then
    W.printPx(text, px, py, { colors = colors, maxWidth = maxWidth })
  end
end

local function measure(text)
  local F = Gen3.font()
  if F and F.measure then
    local ok, w = pcall(F.measure, text, {})
    if ok and type(w) == "number" then return w end
  end
  return #tostring(text or "") * 8
end

--- opts = { search = the active search state, enabled = toggle,
---          busy = function() -> engine UI on top }
function Hud.draw(game, viewport, opts)
  if not (viewport and love and love.graphics) then return end
  local search = opts and opts.search
  if not search or opts.enabled == false then return end
  if opts.busy and opts.busy() then return end

  local sl = tonumber(search.level) or 0
  local showMove = sl > 1
  local showAbility = sl > 2
  local showStars = sl > 4
  local reveal = showMove
  local h = reveal and 34 or 20
  local y0 = GAME_H - h

  local gw = tonumber(viewport.gameWidth) or GAME_W
  local gh = tonumber(viewport.gameHeight) or GAME_H
  local sx = gw / GAME_W
  local sy = gh / GAME_H

  love.graphics.push()
  love.graphics.translate(viewport.gameX or 0, viewport.gameY or 0)
  love.graphics.scale(sx, sy)

  -- A hidden-tile marker: the engine's own rustle plays on grass tiles, but a
  -- clearly moving pointer on top makes the spot unambiguous.  Surf tiles get
  -- rings instead (the engine has no native per-cell water effect).
  if search.tile and not search.customMarker then
    local pp = Gen3.playerPixels and Gen3.playerPixels()
    if pp then
      local D = Gen3.display()
      local W = (D and D.W) or GAME_W
      local H = (D and D.H) or GAME_H
      local camX = math.floor(pp.px + 8 - W / 2)
      local camY = math.floor(pp.py + 8 - H / 2)
      local cx = search.tile.x * 16 - camX + 8
      local cy = search.tile.y * 16 - camY + 12
      if Gen3.markerPoint then
        local mx,my=Gen3.markerPoint(search.tile.x,search.tile.y)
        if mx then cx,cy=mx,my end
      end
      local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
      if search.terrain == "water" then
        local ellipse = love.graphics.ellipse
        local circle = love.graphics.circle
        for i = 0, 1 do
          local p = ((now * 0.9) + i * 0.5) % 1
          local r = 3 + p * 10
          love.graphics.setColor(0.78, 0.92, 1, (1 - p) * 0.75)
          if ellipse then
            ellipse("line", cx, cy, r, r * 0.5)
          elseif circle then
            circle("line", cx, cy, r)
          end
        end
        love.graphics.setColor(1, 1, 1, 1)
      else
        -- a downward chevron, bobbing so it always reads as "here"
        local y = cy - 16 + math.sin(now * 5) * 1.5
        love.graphics.setColor(1, 0.9, 0.25, 0.95)
        love.graphics.rectangle("fill", cx - 5, y, 10, 2)
        love.graphics.rectangle("fill", cx - 3, y + 3, 6, 2)
        love.graphics.rectangle("fill", cx - 1, y + 6, 2, 2)
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  -- strip
  love.graphics.setColor(0.05, 0.05, 0.09, 0.84)
  love.graphics.rectangle("fill", 0, y0, GAME_W, h)
  love.graphics.setColor(1, 1, 1, 0.16)
  love.graphics.rectangle("fill", 0, y0, GAME_W, 1)
  love.graphics.setColor(1, 1, 1, 1)

  local species = search.species
  local iconDrawn = Icons and Icons.draw(species, 3, y0 - 8, 28, search.elapsed) or false
  local x = iconDrawn and 36 or 6
  local line1 = y0 + 3

  local name = search.name or tostring(species)
  print(name, x, line1, WHITE, 110)
  x = x + measure(name) + 4

  local label = "Lv" .. tostring(search.spec and search.spec.level or "?")
  print(label, x, line1, DIM, 40)
  x = x + measure(label) + 5

  if showStars and Icons then
    local stars = tonumber(search.spec and search.spec.potential) or 0
    for i = 1, 3 do
      Icons.star(x, line1 + 3, i <= stars)
      x = x + 9
    end
  end

  -- proximity prompt on the right: the reference's sight states
  local prox = search.proximity
  local hint
  if type(prox) == "number" then
    if prox < 3 then
      hint = "!"
    elseif prox < 6 then
      hint = "SNEAK"
    end
  end
  if hint then
    local w = measure(hint)
    print(hint, GAME_W - 6 - w, line1, hint == "!" and GOLD or ALERT, 60)
  end

  if reveal then
    local line2 = y0 + 19
    local px = 6
    local pieces = {}
    if showMove then
      pieces[#pieces + 1] = { search.spec and search.spec.moveName or "----", WHITE }
    end
    if showAbility then
      pieces[#pieces + 1] = { search.abilityName or "----", DIM }
      if search.spec and tonumber(search.spec.item) and search.spec.item ~= 0 then
        pieces[#pieces + 1] = { search.itemName or "----", DIM }
      end
    end
    for _, piece in ipairs(pieces) do
      local text = tostring(piece[1])
      if #text > 14 then text = text:sub(1, 12) .. ".." end
      print(text, px, line2, piece[2], 70)
      px = px + measure(text) + 8
      if px > GAME_W - 20 then break end
    end
  end

  love.graphics.pop()
end

return Hud
