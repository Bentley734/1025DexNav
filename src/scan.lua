-- Independent nearby-tile selection. Candidate facts come from the adapter.
local Scan={SPAN=5}
function Scan.pick(opts)
  local candidates,total,checked={},0,0
  for y=opts.py-Scan.SPAN,opts.py+Scan.SPAN+1 do
    for x=opts.px-Scan.SPAN,opts.px+Scan.SPAN+1 do
      checked=checked+1
      local distance=math.abs(x-opts.px)+math.abs(y-opts.py)
      if distance>0 and opts.isTarget(x,y) and (not opts.passable or opts.passable(x,y)) then
        local weight=math.max(1,12-distance)
        total=total+weight
        candidates[#candidates+1]={x=x,y=y,through=total}
      end
    end
  end
  if total==0 then return nil,nil,checked end
  local pick=opts.roll(total)
  for _,cell in ipairs(candidates) do
    if pick<cell.through then return cell.x,cell.y,checked end
  end
  -- A defensive fallback for callers supplying a nonconforming RNG.
  local cell=candidates[#candidates]
  return cell.x,cell.y,checked
end
return Scan
