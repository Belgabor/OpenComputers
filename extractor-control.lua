local component = require("component")
local rs = component.redstone
local sides = require("sides")
local act
local getSlotSize

local s_act_extractor = sides.right
local s_rs_clutch = sides.up
local have_ecu = component.isAvailable("EngineControlUnit")

if (component.isAvailable("transposer")) then
  act = component.transposer
  getSlotSize = function(i) return component.transposer.getSlotStackSize(s_act_extractor, i) end
elseif (component.isAvailable("inventory_controller")) then
  act = component.inventory_controller
  getSlotSize = function(i) return component.inventory_controller.getSlotStackSize(s_act_extractor, i) end
else
  getSlotSize = function(i)
    a,b,c,d = component.Extractor.getSlot(i-1)
    return c
  end
end


-- EngineControlUnit.setECU(0) -> 4
while true do
  local signal = 2
  local max = getSlotSize(4) + getSlotSize(7)
  local s3 = getSlotSize(3) + getSlotSize(6)
  local s2 = getSlotSize(2) + getSlotSize(5)
  local s1 = getSlotSize(1)
  
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