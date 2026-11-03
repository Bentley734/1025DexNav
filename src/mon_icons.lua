-- Species icons (the engine's own 32x32 menu icons) plus a tiny baked star
-- for the potential readout.  Icons come from src/core/game3/pokemon.lua via
-- gen3.lua and are cached per species; when the engine or the ROM cache is
-- missing, every caller falls back to text.
local Icons = {}

local Gen3

function Icons.init(engine)
  Gen3 = engine
end

function Icons.available()
  return love ~= nil and love.graphics ~= nil
end

local cache = {}
function Icons.reset() cache = {} end

function Icons.get(species)
  local hit = cache[species]
  if hit and hit.image then
    if not hit.image.isReleased or not hit.image:isReleased() then return hit end
  end
  local icon = Gen3 and Gen3.pokemonIcon(species) or nil
  cache[species] = icon
  return icon or nil
end

--- Draw the species' icon into a `size` box at px, py.  `elapsed` drives the
--- animation: party-menu icons flip frame every 8/60 s (PartyMenu's default).
function Icons.draw(species, px, py, size, elapsed)
  if not Icons.available() then return false end
  if Gen3.drawIcon and Gen3.drawIcon(species,px,py,size,elapsed) then return true end
  local icon = Icons.get(species)
  if not (icon and icon.image) then return false end
  local frame = Icons.frameAt(icon.frames or 1, elapsed)
  local quad = icon.quads and (icon.quads[frame] or icon.quads[0] or icon.quads[1])
  if not quad then return false end
  local w = icon.w or 32
  local h = icon.h or 32
  local sx = size / w
  local sy = size / h
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(icon.image, quad, px, py, 0, sx, sy)
  return true
end

--- Which icon frame is showing after `elapsed` seconds.  Pure, so the
--- animation schedule is testable without a screen.
Icons.ANIM_PERIOD = 8 / 60
function Icons.frameAt(frames, elapsed)
  frames = tonumber(frames) or 1
  if frames <= 1 then return 0 end
  elapsed = tonumber(elapsed) or 0
  return math.floor(elapsed / Icons.ANIM_PERIOD) % frames
end

-- ------- potential star

local starImage

local STAR = {
  "...#...",
  "..###..",
  "#######",
  ".#####.",
  "..###..",
  ".##.##.",
  ".#...#.",
}

local function ensureStar()
  if starImage ~= nil then return starImage end
  starImage = false
  if not (Icons.available() and love.image and love.image.newImageData) then
    return nil
  end
  local data = love.image.newImageData(7, 7)
  for y = 1, 7 do
    local row = STAR[y]
    for x = 1, 7 do
      local on = row:sub(x, x) == "#"
      local v = on and 1 or 0
      data:setPixel(x - 1, y - 1, v, v, v, on and 1 or 0)
    end
  end
  local ok, image = pcall(love.graphics.newImage, data)
  if not ok then return nil end
  if image.setFilter then image:setFilter("nearest", "nearest") end
  starImage = image
  return image
end

--- One star; `filled` false draws the empty slot in a dim tint.
function Icons.star(px, py, filled)
  local image = ensureStar()
  if not image then return false end
  if filled then
    love.graphics.setColor(1, 0.84, 0.2, 1)
  else
    love.graphics.setColor(0.24, 0.24, 0.28, 1)
  end
  love.graphics.draw(image, px, py)
  love.graphics.setColor(1, 1, 1, 1)
  return true
end

return Icons
