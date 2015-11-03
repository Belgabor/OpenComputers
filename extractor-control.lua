local component = require("component")
local rs = component.redstone
local sides = require("sides")

if (component.isAvailable("transposer")) then
  local act = component.transposer
else
  local act = component.inventory_controller
end

local s_act_extractor = sides.right
local s_rs_clutch = sides.up
local have_ecu = component.isAvailable("EngineControlUnit")

-- EngineControlUnit.setECU(0) -> 4
while true do
  local signal = 2
  local max = act.getSlotStackSize(s_act_extractor, 4) + act.getSlotStackSize(s_act_extractor, 7)
  local s3 = act.getSlotStackSize(s_act_extractor, 3) + act.getSlotStackSize(s_act_extractor, 6)
  local s2 = act.getSlotStackSize(s_act_extractor, 2) + act.getSlotStackSize(s_act_extractor, 5)
  local s1 = act.getSlotStackSize(s_act_extractor, 1)
  
  if (s3 > max) then
    signal = 1
    max = s3
  end
  if (s2 > max) then
    signal = 1
    max = s2
  end
  if (s1 > max) then
    signal = 0
    max = s1
  end
  
  if ((max > 0) and (act.getSlotStackSize(s_act_extractor, 8) < 64) and (act.getSlotStackSize(s_act_extractor, 9) < 64)) then
    if (have_ecu) then
      component.EngineControlUnit.setECU(4)
    end
    rs.setOutput(s_rs_clutch, signal)
    os.sleep(1)
  else
    if (have_ecu) then
      component.EngineControlUnit.setECU(0)
    end
    os.sleep(5)
  end  
end