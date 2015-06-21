local component = require("component")
local me = component.me_controller
local gpu = component.gpu

local liquids = {lithium=true, tritium=true, deuterium=true}
local labels = {}
local prev = {}
for k in pairs(liquids) do
  prev[k] = 0
  labels[k] = "?"
end


while true do
  local liquids = me.getFluidsInNetwork()
  local current = {}
  for k in pairs(liquids) do
    current[k] = 0
  end
  for i, v in pairs(liquids) do
    if type(v) == "table" then
      if liquids[v.name] then
        current[v.name] = v.amount
        label[v.name] = v.label
      end
    end
  end

  local lens = {5,5,5}
  for k in pairs(liquids) do
    lens[1] = math.max(lens[1], string.len(labels[k]))
    lens[2] = math.max(lens[2], string.len(prev[k]))
    lens[3] = math.max(lens[3], string.len(current[k]))
  end

  local row = 1  
  gpu.fill(1, 1, lens[1]+lens[2]+lens[3]+2, #liquids, ' ')
  for k in pairs(liquids) do
    gpu.set(1, row, label[k])
    gpu.set(lens[1]+1+(lens[2] - string.len(prev[k])), row, prev[k])
    gpu.set(lens[1]+2+lens[2]+(lens[2] - string.len(current[k])), row, current[k])
    
    prev[k] = current[k]
    
    row = row + 1
  end
  
end