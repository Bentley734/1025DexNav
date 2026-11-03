local G=assert(loadfile('src/generator.lua'))()
local C=assert(loadfile('src/chance.lua'))();G.init(C)
local checks=0
local function eq(a,b,m)checks=checks+1;assert(a==b,m)end
local zero=function()return 0 end
local last=function(n)return n-1 end
eq(G.potential(zero,0),0,'zero-percent stars cannot trigger')
eq(G.level(last,0,3,5),5,'inclusive upper encounter level')
eq(G.level(last,100,90,100),100,'level cap')
local id,second=G.ability(zero,0,{1,2})
eq(id,1,'zero-percent ability uses normal roll');eq(second,false,'no zero-percent special ability')
for _,gb in ipairs({false,true})do
 for stars=1,3 do
  local iv=G.ivs(zero,stars,gb);local perfect=0
  for _,k in ipairs(gb and {'atk','def','spe','spa'} or {'hp','atk','def','spe','spa','spd'}) do
   if iv[k]==31 then perfect=perfect+1 end
  end
  eq(perfect,stars,'potential always grants distinct native stats')
 end
end
local keys={TACKLE=true,GROWL=true}
local use={movesAtLevel=function()return {'TACKLE','GROWL'},{35,40}end,strictLevelUpMoves=function()return true end}
local moves,pp,bonus=G.moves(use,{},252,5,zero,100)
eq(moves[1],'TACKLE','GB move keys retained');eq(pp[2],40,'GB PP retained');eq(bonus,nil,'native GB progression')
print('PASS '..checks..' independent generator assertions')
