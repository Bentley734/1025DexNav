-- Independent hidden encounter generator; no external DexNav implementation.
local G, Chance = {}, nil
function G.init(chance) Chance=chance end
local function percentage(roll,percent) return roll(100)<math.max(0,math.min(100,percent or 0)) end
function G.potential(roll,level)
  local band=Chance.band(level)
  local r=roll(100)
  for star,table_ in ipairs({Chance.THREE_STAR,Chance.TWO_STAR,Chance.ONE_STAR}) do
    local weight=table_[band] or 0
    if r<weight then return 4-star end
    r=r-weight
  end
  return 0
end
function G.wantsSpecialMove(roll,level) return percentage(roll,Chance.EGG_MOVE[Chance.band(level)]) end
function G.ability(roll,level,ids)
  if not ids or #ids==0 then return nil end
  local second=#ids>1 and percentage(roll,Chance.SPECIAL_ABILITY[Chance.band(level)])
  return ids[second and 2 or 1+roll(#ids)],second==true
end
function G.heldItem(roll,level,common,rare)
  if not common and not rare then return 0 end
  common,rare=common or 0,rare or 0
  if common==rare then return common end
  local boost=math.floor(math.max(0,math.min(100,tonumber(level) or 0))/2)
  local r=roll(100)
  if rare~=0 and r<5+boost then return rare end
  if common~=0 and r<55+boost then return common end
  return 0
end
function G.level(roll,level,low,high)
  low=math.max(1,math.floor(tonumber(low) or 2))
  high=math.max(low,math.floor(tonumber(high) or low))
  return math.min(100,low+roll(high-low+1)+Chance.levelBonus(level))
end
function G.ivs(roll,stars,gameboy)
  local iv,keys={}, {'hp','atk','def','spe','spa','spd'}
  for _,key in ipairs(keys) do iv[key]=roll(32) end
  if gameboy then keys={'atk','def','spe','spa'} end
  -- Sampling without replacement always awards the displayed number of stars.
  for _=1,math.min(3,math.max(0,tonumber(stars) or 0)) do
    local index=1+roll(#keys);iv[table.remove(keys,index)]=31
  end
  return iv
end
function G.moves(use,record,n,level,roll,searchLevel)
  local moves,pp={},{}
  if use.movesAtLevel then
    local m,p=use.movesAtLevel(n,level)
    for i,id in ipairs(m or {}) do
      if i>4 then break end
      moves[i]=id;pp[i]=(p or {})[i] or use.movePp(id)
    end
  end
  local strict=use.strictLevelUpMoves and use.strictLevelUpMoves()
  local pool=record and record.tmhm
  local bonus
  if not strict and pool and #pool>0 and G.wantsSpecialMove(roll,searchLevel) then
    bonus=use.moveId(pool[1+roll(#pool)])
    if bonus then table.insert(moves,1,bonus);table.insert(pp,1,use.movePp(bonus)) end
  end
  if #moves==0 then
    local id=use.moveId('TACKLE')
    if id then moves[1]=id;pp[1]=use.movePp(id) end
  end
  for i=1,4 do moves[i]=moves[i] or 0;pp[i]=pp[i] or 0 end
  moves[5],pp[5]=nil,nil
  return moves,pp,bonus
end
function G.build(opts)
  local roll=opts.roll or Chance.roll
  local use,record=opts.use or {},opts.record or {}
  local level=G.level(roll,opts.searchLevel,opts.slot and opts.slot.min,opts.slot and opts.slot.max)
  local stars=G.potential(roll,opts.searchLevel)
  local ids=use.abilityIds and use.abilityIds(opts.species)
  local ability,special=G.ability(roll,opts.searchLevel,ids)
  local moves,pp,bonus=G.moves(use,record,opts.species,level,roll,opts.searchLevel)
  return {species=opts.species,level=level,potential=stars,ivs=G.ivs(roll,stars,opts.generation and opts.generation<3),
    ability=ability,specialAbility=special,
    item=G.heldItem(roll,opts.searchLevel,record.itemCommon,record.itemRare),moves=moves,pp=pp,bonusMove=bonus}
end
return G
