-- input.step runs before Input:step on GB. Inspect queued edges, never the
-- preceding frame's pressed table, and reserve only handled shortcut edges.
local Input = {}
function Input.pending(pad)
  if not pad or type(pad.pressQueue)~='table' then return pad end
  -- Native pad polling is idempotent; repairs missed hardware events before
  -- shortcut routing. Input:step still owns promotion and hold bookkeeping.
  if pad.pollPads then pad:pollPads() end
  local queued={}
  for _,button in ipairs(pad.pressQueue) do queued[button]=true end
  for src,dst in pairs(pad.aliases or {}) do if queued[src] then queued[dst]=true end end
  return {wasPressed=function(_,button)return queued[button]==true end,
    isDown=function(_,button)return pad:isDown(button) end}
end
function Input.consume(pad,button)
  if type(pad.pressQueue)~='table' then return end
  for i=#pad.pressQueue,1,-1 do
    local key=pad.pressQueue[i]
    if key==button or (pad.aliases or {})[key]==button then table.remove(pad.pressQueue,i) end
  end
end
return Input
