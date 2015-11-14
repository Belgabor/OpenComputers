local component = require("component")
local sides = require("sides")
local shell = require("shell")

local args, options = shell.parse(...)

local act
local getSlotSize

local s_act_extractor = sides.right
local s_rs_clutch = sides.up
local min_process = 5

local speed = 1024
local torque = 256

local cvts = {}
local i = 0
for addr, dummy in component.list("AdvancedGears") do
  i = i + 1
  cvts[i] = component.proxy(addr)
end

local ecus = {}
i = 0
for addr, dummy in component.list("EngineControlUnit") do
  i = i + 1
  ecus[i] = component.proxy(addr)
end

local cvt_setting = {}

-- Setting 1, 512 torque
if (torque < 512) then
  cvt_setting[1] = -(512/torque)
else
  cvt_setting[1] = torque/512
end

-- Setting 2, 1 torque
cvt_setting[2] = torque

-- Setting 3, 256 torque
if (torque < 256) then
  cvt_setting[3] = -(256/torque)
else
  cvt_setting[3] = torque/256
end

-- Check validity
local err = false
for i = 1,3 do
  local n_cvts = math.ceil(math.log(math.abs(cvt_setting[i]))/math.log(32))
  local x = "OK"
  if (n_cvts > #cvts) then
    if (i==2) then
      x = "Inefficient ("..cvt_setting[2]..")"
      cvt_setting[2] = 32^#cvts
    else
      x = "ERROR!"
      err = true
    end
  end
  local s, t
  if (cvt_setting[i] < 0) then
    s = -speed / cvt_setting[i]
    t = -torque*cvt_setting[i]
  else
    s = speed * cvt_setting[i]
    t = torque/cvt_setting[i]
  end
  print(i, cvt_setting[i], n_cvts, s, t, x)
end

if (err) then
  os.exit()
end

function setECU(s)
  for i, e in pairs(ecus) do
    e.setECU(s)
  end
end

function setRatio(r)
  for i, cvt in pairs(cvts) do
    if (math.abs(r)>=32) then
      cvt.setRatio(32 * (r/math.abs(r)))
      r = r / 32
    else
      cvt.setRatio(r)
      r = 1
    end
  end
end

if (component.isAvailable("transposer")) then
  act = component.transposer
  getSlotSize = function(i) return component.transposer.getSlotStackSize(s_act_extractor, i) end
elseif (component.isAvailable("inventory_controller")) then
  act = component.inventory_controller
  getSlotSize = function(i) return component.inventory_controller.getSlotStackSize(s_act_extractor, i) end
else
  getSlotSize = function(i)
    a,b,c,d = component.Extractor.getSlot(i-1)
    if (c==nil) then return 0 end
    return c
  end
end

if (#args > 0) then
  if (args[1] == "off") then
    if (#ecus > 0) then
      setECU(0)
    else
      print("No ECU available!")
    end
    os.exit()
  end
end

local x = 0

local old_step = 0
local old_size = 0

-- EngineControlUnit.setECU(0) -> 4
while true do
  local signal = 2
  local s = {}
  
  s[1] = getSlotSize(1)
  s[2] = getSlotSize(2) + getSlotSize(5)
  s[3] = getSlotSize(3) + getSlotSize(6)
  s[4] = getSlotSize(4) + getSlotSize(7)
  
  local max = s[4]
  local current_step = 4
  
  if (s[3] > max) then
    max = s[3]
    current_step = 3
  end
  if (s[2] > max) then
    max = s[2]
    current_step = 2
  end
  if (s[1] > max) then
    max = s[1]
    current_step = 1
  end
  
  if (max < 64) then
    if ((old_step > 0) and (current_step ~= old_step) and (s[old_step]>0) and ((s[old_step] + min_process)>old_size)) then
      current_step = old_step
    end
  end
  
  if (current_step == 4) then
    signal = 2
  elseif (current_step == 1) then
    signal = 0
  else
    signal = 1
  end
  
  if ((max > 0) and (getSlotSize(8) < 64) and (getSlotSize(9) < 64)) then
    if (x==0) then
      x = os.time()
    end
    if (current_step ~= old_step) then
      old_step = current_step
      old_size = s[current_step]
    end
    if (s[current_step] > old_size) then
      old_size = s[current_step]
    end
    
    if (#ecus>0) then
      setECU(4)
    end
    setRatio(cvt_setting[signal+1])
    os.sleep(1)
  else
    old_size = 0
    old_step = 0
    if (#ecus>0) then
      setECU(0)
    end
    if (x>0) then
      print((os.time()-x)/72)
      x = 0
    end
    os.sleep(5)
  end  
end