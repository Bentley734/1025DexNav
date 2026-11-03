-- Production resolver and generator, with the live 1025Dex move rules.
local dexRoot=assert(arg[1]);local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local R=assert(loadfile(dexRoot..'/dex/src/gen3moves.lua'))()
local rules=assert(loadfile(dexRoot..'/dex/data/species/generated/gen3_moves.lua'))()
local game='firered';local active=true
local api={vanillaWildMoves=function(sp,lv)
 local dex=sp>450 and sp-64 or sp
 local row=rules.extended[dex]
 return R.atLevel(row and row.learnset or rules.native[game=='emerald' and 'rse' or 'frlg'][dex],lv,function()return 20 end)
end}
local D=assert(loadfile('src/data.lua'))()
D.init({generation=function()return 3 end,pokemon=function()return {movesAtLevel=function()return {33,45},{35,40}end}end},
 {find=function()return active and {exports=api}or nil end}, {native=function(n)return n>386 and n+64 or n end})
local G=assert(loadfile('src/generator.lua'))()
G.init({EGG_MOVE={[1]=100},band=function()return 1 end})
for _,family in ipairs({'firered','leafgreen','emerald'})do game=family
 for dex=1,1025 do for lv=1,100 do
  local sp=dex>386 and dex+64 or dex
  local expected,expectedPp=api.vanillaWildMoves(sp,lv)
  local moves,pp,bonus=G.moves(D.resolver,{tmhm={'53'}},dex,lv,function()return 0 end,1000)
  eq(bonus,nil,'no bonus TM with Dex')
  for i=1,4 do eq(moves[i],expected[i]or 0,'preview matches wild moves');eq(pp[i],expectedPp[i]or 0,'preview PP matches')end
 end end
end
active=false;eq(D.resolver.strictLevelUpMoves(),false,'vanilla standalone feature preserved')
local moves,pp,bonus=G.moves(D.resolver,{tmhm={'53'}},4,3,function()return 0 end,1000)
eq(bonus,53,'standalone bonus retained');eq(moves[1],53,'standalone TM still generated')
print('PASS: '..checks..' DexNav preview / 1025 species / FRLG and Emerald / no bonus TMs / standalone fallback checks')
