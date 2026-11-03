-- Search-level tuning values retained from the supplied 1025DexNav release.
-- These are gameplay percentages; the generator implementation is independent.
local C = {
  BANDS={5,10,25,50,100}, EGG_MOVE={21,46,58,63,65,83},
  SPECIAL_ABILITY={0,0,5,15,20,23}, ONE_STAR={0,14,17,17,15,8},
  TWO_STAR={0,1,9,16,17,24}, THREE_STAR={0,0,1,7,6,12},
}
function C.band(level)
  level=math.max(0,tonumber(level) or 0)
  for index,limit in ipairs(C.BANDS) do if level<limit then return index end end
  return 6
end
function C.levelBonus(level) return math.min(20,math.floor(math.max(0,tonumber(level) or 0)/4)) end
function C.roll(n) n=math.floor(tonumber(n) or 0); return n>0 and math.random(0,n-1) or 0 end
return C
