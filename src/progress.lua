-- Versioned National identity storage, separate from the original native keys.
local Progress = {}
function Progress.new(mod, identity, generation)
  local P, cache = {}, nil
  local function load()
    if cache then return cache end
    local saved = mod.save:get('national_progress')
    if type(saved) == 'table' and saved.schema == 1 then
      cache = { schema = 1, levels = {}, registered = nil }
      for key, value in pairs(type(saved.levels)=='table' and saved.levels or {}) do
        local n, v = identity.valid(key), tonumber(value)
        if n and v and v == v then cache.levels[tostring(n)] = math.max(0, math.min(100, math.floor(v))) end
      end
      local r = saved.registered
      if type(r) == 'table' and identity.valid(r.species) then
        cache.registered = { species = identity.valid(r.species), terrain = r.terrain == 'water' and 'water' or 'land' }
      end
      return cache
    end
    cache = { schema = 1, levels = {} }
    -- v0.1.13 ran exclusively on GBA; leave the original save fields intact.
    if generation() == 3 then
      local legacy=mod.save:get('search_levels')
      for native, value in pairs(type(legacy)=='table' and legacy or {}) do
        local n, v = identity.national(tonumber(native)), tonumber(value)
        if n and v and v == v then
          local key = tostring(n)
          cache.levels[key] = math.max(cache.levels[key] or 0, math.max(0, math.min(100, math.floor(v))))
        end
      end
      local r = mod.save:get('registered')
      local n = type(r) == 'table' and identity.national(r.species)
      if n then cache.registered = { species = n, terrain = r.terrain == 'water' and 'water' or 'land' } end
    end
    mod.save:set('national_progress', cache)
    return cache
  end
  function P.reset() cache = nil end
  function P.get(n) n = identity.valid(n); return n and load().levels[tostring(n)] or 0 end
  function P.set(n, value)
    n, value = identity.valid(n), tonumber(value)
    if not n or not value or value ~= value then return nil end
    value = math.max(0, math.min(100, math.floor(value)))
    load().levels[tostring(n)] = value; mod.save:set('national_progress', cache)
    return value
  end
  function P.register(n, terrain)
    n = identity.valid(n); if not n then return false end
    load().registered = { species = n, terrain = terrain == 'water' and 'water' or 'land' }
    mod.save:set('national_progress', cache); return true
  end
  function P.registered() local r = load().registered; return r and {species=r.species, terrain=r.terrain} end
  function P.all() local out = {}; for n, v in pairs(load().levels) do out[tonumber(n)] = v end; return out end
  return P
end
return Progress
