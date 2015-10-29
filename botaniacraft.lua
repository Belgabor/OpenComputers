local component = require("component")
local transposer = component.transposer
local rs = component.redstone
local sides = require("sides")

local s_transposer_chest = sides.back
local s_transposer_altar = sides.left

local s_pc_dispenser = sides.front
local s_pc_altar = sides.left

-- getInventorySize
-- getSlotStackSize
-- getStackInSlot
-- transferItem(sourceSide, sinkSide, count, sourceSlot, sinkSlot)

rs.setOutput(s_pc_dispenser, 0)
while true do
  if (transposer.getSlotStackSize(s_transposer_chest, 1) == 0) then
    break
  end
  
  local i = 0
  while true do
    i = i + 1
    local s = transposer.getSlotStackSize(s_transposer_chest, i)
    if (i == 0) then
      break
    end
    transposer.transferItem(s_transposer_chest, s_transposer_altar, 1, i)
  end
  
  rs.setOutput(s_pc_dispenser, 15)
  os.sleep(1)
  rs.setOutput(s_pc_dispenser, 0)
  
  while true do
    if (rs.getInput(s_pc_altar) == 2) then
      break
    end
    os.sleep(1)
  end
  
  transposer.transferItem(s_transposer_chest, s_transposer_altar, 1, transposer.getInventorySize(s_transposer_chest))
  os.sleep(1)
  
  rs.setOutput(s_pc_dispenser, 15)
  os.sleep(1)
  rs.setOutput(s_pc_dispenser, 0)
  
  os.sleep(2)
end
