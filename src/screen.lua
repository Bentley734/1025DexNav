-- The DexNav screen: a modal layer on the engine's own Game3 UI stack, so
-- the engine routes field input to it, draws it in order, and treats it as
-- "busy" (no start menu, no field movement).
--
-- Layout at the engine's 240x160 FRLG scale, following the reference's
-- header / LAND+WATER panels / message-bar shape.  Species are the engine's
-- own 32x32 party icons, animated at the party menu's frame rate; the info
-- line is a single row because the FRLG font is 14px tall and the reference's
-- four-row right column would clip every value at this size.
local Screen = {}

local Gen3, Icons, Data

local ID = "gen3_dexnav"

function Screen.init(engine, icons, data)
  Gen3 = engine
  Icons = icons
  Data = data
end

local GAME_W, GAME_H = 240, 160
local CELL = 32 -- native icon size

-- A party icon is 32px tall. WATER gets a real 44px panel even for one row,
-- and expands to two full icon rows when the local pool needs it. In that
-- expanded state LAND remains accessible as a one-row pageable panel.
local HEADER_H = 20
local PANEL_L, PANEL_W = 4, 232
local INFO_Y, INFO_H = 134, 26

local function layoutFor(layer)
  local waterCount = layer and layer.ctx and #(layer.ctx.water or {}) or 0
  if waterCount == 0 then
    -- Do not leave a full empty WATER band above LAND on dry maps.
    return {
      water = { top = 22, height = 24, labelY = 26, iconY = 22,
        cols = 5, startX = 44, pitch = 34, rows = 1 },
      land = { top = 48, height = 84, labelY = 70, iconY = 50,
        cols = 6, startX = 44, pitch = 32, rowPitch = 32, rows = 2 },
      infoY = INFO_Y, infoH = INFO_H,
    }
  end
  if waterCount > 5 then
    return {
      water = { top = 22, height = 76, labelY = 49, iconY = 24,
        cols = 5, startX = 44, pitch = 34, rowPitch = 32, rows = 2 },
      land = { top = 100, height = 34, labelY = 110, iconY = 101,
        cols = 6, startX = 44, pitch = 32, rows = 1 },
      infoY = INFO_Y, infoH = INFO_H,
    }
  end
  return {
    water = { top = 22, height = 44, labelY = 37, iconY = 24,
      cols = 5, startX = 44, pitch = 34, rows = 1 },
    land = { top = 68, height = 66, labelY = 76, iconY = 69,
      cols = 6, startX = 44, pitch = 32, rowPitch = 32, rows = 2 },
    infoY = INFO_Y, infoH = INFO_H,
  }
end

local WHITE = { fg = { 1, 1, 1, 1 }, shadow = { 0.30, 0.30, 0.36, 1 } }
local DARK = { fg = { 0.14, 0.16, 0.22, 1 }, shadow = { 0.62, 0.65, 0.72, 1 } }
local DIM = { fg = { 0.74, 0.76, 0.82, 1 }, shadow = { 0.24, 0.24, 0.30, 1 } }
local GOLD = { fg = { 1, 0.84, 0.20, 1 }, shadow = { 0.40, 0.30, 0.02, 1 } }
local GREEN = { fg = { 1, 1, 1, 1 }, shadow = { 0.03, 0.20, 0.05, 1 } }
local ALERT = { fg = { 1, 0.55, 0.45, 1 }, shadow = { 0.40, 0.10, 0.08, 1 } }

local current -- the single open layer, if any

-- ------- drawing helpers

local function print(text, px, py, colors, maxWidth)
  local W = Gen3.window()
  if W and W.printPx then
    W.printPx(text, px, py, { colors = colors, maxWidth = maxWidth or GAME_W })
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

local function fill(px, py, pw, ph, r, g, b, a)
  love.graphics.setColor(r, g, b, a or 1)
  love.graphics.rectangle("fill", px, py, pw, ph)
  love.graphics.setColor(1, 1, 1, 1)
end

local function frame(px, py, pw, ph, r, g, b, a)
  love.graphics.setColor(r or 1, g or 1, b or 1, a or 1)
  love.graphics.rectangle("line", px - 0.5, py - 0.5, pw + 1, ph + 1)
  love.graphics.setColor(1, 1, 1, 1)
end

local function panel(px, py, pw, ph)
  local W = Gen3.window()
  if W and W.template then
    local tpl = W.template(px / 8, py / 8, pw / 8, ph / 8)
    W.fill(tpl, 1, 1, 1, 1)
    W.stdFrame(tpl)
  else
    fill(px, py, pw, ph, 1, 1, 1)
    frame(px, py, pw, ph, 0.1, 0.1, 0.15)
  end
end

-- The info panel's 26px height is intentionally not tile-aligned. At the
-- bottom of the 160px canvas the standard 8px frame therefore leaves only
-- two pixels of its final left/right edge tiles visible. Clip those partial
-- edge tiles, then restore the white content area right to the canvas edge.
local function bottomPanel(px, py, pw, ph)
  love.graphics.push("all")
  love.graphics.setScissor(0, 0, GAME_W, GAME_H - 2)
  panel(px, py, pw, ph)
  love.graphics.pop()
  fill(px, GAME_H - 2, pw, 2, 1, 1, 1, 1)
end

-- ------- the layer

local function listOf(ctx, panel)
  if panel == "water" then return ctx.water or {} end
  return ctx.land or {}
end

local function selected(layer)
  local list = listOf(layer.ctx, layer.panel)
  return list[layer.index] or nil
end

local function switchPanel(layer)
  local target = layer.panel == "land" and "water" or "land"
  if #listOf(layer.ctx, target) == 0 then
    layer.status = "No " .. target .. " Pokemon here."
    return
  end
  layer.panel = target
  layer.index = 1
  layer.status = nil
end

local function move(layer, delta)
  local list = listOf(layer.ctx, layer.panel)
  if #list == 0 then return end
  local index = layer.index + delta
  if index < 1 then index = #list end
  if index > #list then index = 1 end
  layer.index = index
  layer.status = nil
end

local function pageCapacity(layer, terrain)
  local layout = layoutFor(layer)
  local spec = terrain == "water" and layout.water or layout.land
  return spec.cols * spec.rows
end

local function search(layer)
  local row = selected(layer)
  if not row then
    layer.status = "That Pokemon can't be searched!"
    return
  end
  layer.ctx.onSearch(row.species, layer.panel)
  Screen.close()
end

local function register(layer)
  local row = selected(layer)
  if not row then
    layer.status = "That Pokemon can't be searched!"
    return
  end
  layer.ctx.onRegister(row.species, layer.panel)
  layer.status = row.name .. " registered!"
end

-- ------- drawing

local function cellX(spec, col)
  return spec.startX + (col - 1) * spec.pitch
end

local function cellY(spec, row)
  return spec.iconY + (row - 1) * (spec.rowPitch or spec.pitch)
end

local function drawCell(layer, row, px, py)
  local drawn = false
  if Icons then
    drawn = Icons.draw(row.species, px, py, CELL, layer.anim)
  end
  if not drawn then
    fill(px, py, CELL, CELL, 0.90, 0.91, 0.95, 1)
    frame(px, py, CELL, CELL, 0.45, 0.48, 0.55, 1)
    print(row.name:sub(1, 6), px + 2, py + 9, DARK, CELL)
  end
  return drawn
end

local function drawCursor(px, py, blink)
  local on = blink < 0.5
  frame(px - 2, py - 2, CELL + 4, CELL + 4,
    on and 1 or 0.72, on and 0.84 or 0.56, on and 0.2 or 0.10, 1)
end

local function drawPanel(layer, terrain, spec, title)
  local list = listOf(layer.ctx, terrain)
  panel(PANEL_L, spec.top, PANEL_W, spec.height)
  print(title, PANEL_L + 4, spec.labelY, GOLD)
  local capacity = spec.cols * spec.rows
  local first = layer.panel == terrain and math.floor((layer.index-1)/capacity)*capacity or 0
  local shown = math.min(#list-first, capacity)
  for i = 1, shown do
    local row = list[first+i]
    local col = (i - 1) % spec.cols + 1
    local line = math.floor((i - 1) / spec.cols) + 1
    local px = cellX(spec, col)
    local py = cellY(spec, line)
    drawCell(layer, row, px, py)
    if layer.panel == terrain and layer.index == first+i then
      drawCursor(px, py, layer.blink)
    end
  end
  if #list == 0 then
    print("no " .. terrain .. " encounters", spec.startX, spec.labelY, DIM,
      PANEL_W - spec.startX)
  end
end

--- Two rows: the selected species' numbers, then the controls hint or the
--- transient status message.  Every string stays on one 14px row.
local function drawInfo(layer, layout)
  local infoY, infoH = layout.infoY, layout.infoH
  bottomPanel(PANEL_L, infoY, PANEL_W, infoH)
  local ctx = layer.ctx
  local line1 = infoY
  local line2 = infoY + 13
  local x0 = PANEL_L + 4
  local limit = PANEL_L + PANEL_W - 4

  local row = selected(layer)
  if row then
    local sl = ctx.searchLevel(row.species) or 0
    local bonus = math.floor(sl / 4)
    if bonus > 20 then bonus = 20 end
    local x = x0
    local function seg(text, colors)
      local w = measure(text)
      if x + w > limit then return end
      print(text, x, line1, colors, limit - x)
      x = x + w + 8
    end
    seg(row.name, WHITE)
    seg(tostring(layer.index).."/"..tostring(#listOf(ctx,layer.panel)), DIM)
    seg("LV " .. sl, DIM)
    seg("+" .. bonus, DIM)
    local ability = Data.specialAbilityName(row.species)
    if ability then seg("ABL " .. ability, DIM) end
  else
    print("Nothing here.", x0, line1, DIM, PANEL_W - 8)
  end

  if layer.status then
    print(layer.status, x0, line2, ALERT, PANEL_W - 8)
  else
    print("A SEARCH   SEL REG   B BACK", x0, line2, DIM, PANEL_W - 8)
  end
end

local function drawHeader()
  fill(0, 0, GAME_W, HEADER_H, 0.06, 0.08, 0.18, 1)
  love.graphics.setColor(1, 1, 1, 0.22)
  love.graphics.rectangle("fill", 0, HEADER_H - 1, GAME_W, 1)
  love.graphics.setColor(1, 1, 1, 1)
  print("DEXNAV", 6, 2, WHITE)
  fill(176, 2, 58, 13, 0.13, 0.55, 0.20, 1)
  frame(176, 2, 58, 13, 0.05, 0.30, 0.09, 1)
  print("A:SEARCH", 182, 2, GREEN)
end

local function drawBackdrop()
  fill(0, 0, GAME_W, GAME_H, 0.10, 0.13, 0.26, 1)
  for y = 0, GAME_H - 1, 8 do
    fill(0, y, GAME_W, 4, 0.11, 0.145, 0.285, 1)
  end
end

local layer = {}

function layer.draw()
  if not (love and love.graphics) then return end
  local layout = layoutFor(layer)
  drawBackdrop()
  drawHeader()
  drawPanel(layer, "water", layout.water, "WATER")
  drawPanel(layer, "land", layout.land, "LAND")
  drawInfo(layer, layout)
end

function layer.update(dt)
  local step = tonumber(dt) or 0
  layer.blink = (layer.blink + step) % 1
  layer.anim = (layer.anim or 0) + step
end

function layer.handleInput(input)
  if not (input and input.wasPressed) then return end
  if input:wasPressed("b") or input:wasPressed("start") then
    Screen.close()
  elseif input:wasPressed("a") then
    search(layer)
  elseif input:wasPressed("select") then
    register(layer)
  elseif input:wasPressed("up") or input:wasPressed("down") then
    switchPanel(layer)
  elseif input:wasPressed("l") then
    move(layer, -pageCapacity(layer, layer.panel))
  elseif input:wasPressed("r") then
    move(layer, pageCapacity(layer, layer.panel))
  elseif input:wasPressed("left") then
    move(layer, -1)
  elseif input:wasPressed("right") then
    move(layer, 1)
  end
end

function layer.isOpen()
  return current == layer and Gen3 and Gen3.hasLayer and Gen3.hasLayer(ID) or false
end

-- ------- open/close

function Screen.isOpen()
  return current ~= nil
end

function Screen.close()
  current = nil
  if Gen3 and Gen3.popLayer then Gen3.popLayer(ID) end
end

--- Drop any layer left on the engine stack by a previous load of this mod.
function Screen.reset()
  current = nil
  if Gen3 and Gen3.popLayer then Gen3.popLayer(ID) end
end

local searchActive = false

function Screen.setSearchActive(active)
  searchActive = active == true
end

function Screen.isSearchActive()
  return searchActive
end

--- ctx = { game, mapId, encounters, searchLevel(species), registered,
---         onSearch(species, terrain), onRegister(species, terrain) }
function Screen.open(_, ctx)
  Screen.reset()
  local land = {}
  local water = {}
  if ctx.encounters then
    land = Data.speciesList(ctx.encounters, "land")
    water = Data.speciesList(ctx.encounters, "water")
  end
  ctx.land = land
  ctx.water = water

  layer.ctx = ctx
  layer.panel = #land > 0 and "land" or "water"
  layer.index = 1
  layer.status = searchActive and "Searching..." or nil
  layer.blink = 0
  layer.anim = 0

  if ctx.registered and ctx.registered.species then
    local list = listOf(ctx, ctx.registered.terrain or "land")
    for i, row in ipairs(list) do
      if row.species == ctx.registered.species then
        layer.panel = ctx.registered.terrain or "land"
        layer.index = i
        break
      end
    end
  end

  if not Gen3.pushLayer(ID, layer) then return false end
  current = layer
  return true
end

return Screen
