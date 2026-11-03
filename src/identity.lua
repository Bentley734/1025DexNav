-- Public numbers are National Dex numbers; engine identities stay opaque.
local Identity = {}
function Identity.new(mod, engine)
  local I = {}
  local function api()
    local ok, handle = pcall(function() return mod:find('1025dex') end)
    return ok and handle and handle.exports and handle.exports.speciesNumbers
  end
  function I.valid(n)
    n = tonumber(n)
    if n and n == n and n % 1 == 0 and n >= 1 and n <= 1025 then return n end
  end
  local function rows()
    return mod.game and mod.game.data and mod.game.data.pokemon or {}
  end
  function I.national(native)
    local A = api()
    if A and A.nationalOfSpecies then return I.valid(A.nationalOfSpecies(native)) end
    if engine.generation() == 3 then
      local P = engine.pokemon()
      if type(native) == 'string' and not tonumber(native) and P and P.speciesFromName then
        native = P.speciesFromName(native)
      end
      return P and P.national and I.valid(P.national(tonumber(native))) or nil
    end
    local row = rows()[native]
    return row and not row.form and I.valid(row.dex) or nil
  end
  function I.native(n)
    n = I.valid(n); if not n then return nil end
    local A = api()
    if A and A.speciesFromNational then return A.speciesFromNational(n) end
    if engine.generation() == 3 then
      local P = engine.pokemon()
      local id = P and P.speciesFromNational and P.speciesFromNational(n)
      if id and I.national(id) == n then return id end
    else
      for key, row in pairs(rows()) do
        if not row.form and tonumber(row.dex) == n then return key end
      end
    end
  end
  function I.record(n)
    local key = I.native(n)
    if engine.generation() == 3 then
      local P = engine.pokemon()
      key = key and P and P.keyName and P.keyName(key)
    end
    local hit = key and rows()[key]
    if hit then return hit end
    local R = mod.content and mod.content.pokemon
    if R and R.get and key then return R:get(key) end
  end
  function I.name(n)
    local row = I.record(n)
    if row and row.name then return row.name end
    local P = engine.generation() == 3 and engine.pokemon()
    local native = I.native(n)
    return native and P and P.name and P.name(native) or '#' .. tostring(n)
  end
  return I
end
return Identity
