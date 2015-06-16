local component = require("component")
local sides = require("sides")
local robot = require("robot")
local s = require("serialization")
local event = require("event")
local inv = component.inventory_controller
local mod = component.modem

local selectors = {}
local private_sel = {}
local private_allowed = {}
private_allowed["7e0252e2-54a6-4d07-b5c6-c520839371b0"] = 1

local rcv_port = 4901
local snd_port = 4902
mod.open(rcv_port)

function scanSelectors()
  robot.turnLeft()
  
  selectors = {}
  local slots = inv.getInventorySize(sides.front)
  for i = 1,slots do
    local item = inv.getStackInSlot(sides.front, i)
    if item ~= nil then
      label = item["label"]
      if string.sub(label, 1, 1) == "~" then
        label = string.sub(label, 2, -1)
      else
        selectors[i] = label
      end
      private_sel[i] = label
    end
  end

  robot.turnRight()
end

function setLocation(loc)
  robot.turnLeft()

  inv.suckFromSlot(sides.front, loc)
  inv.equip()
  robot.useUp(sides.front)
  inv.equip()
  inv.dropIntoSlot(sides.front, loc)

  robot.turnRight()
end

function extractLocation(loc)
  robot.turnLeft()
  inv.suckFromSlot(sides.front, loc)
  robot.turnRight()
  inv.dropIntoSlot(sides.front, 1)  
end


scanSelectors()

while true do
  local _, _, from, port, _, command, param = event.pull("modem_message")
  if port ~= rcv_port then
    goto continue
  end
  if command == "getSelectors" then
    print("getSelectors", from)
    if (param == 1) and (private_allowed[from] ~= nil) then
      mod.broadcast(snd_port, "selectors", s.serialize(private_sel))
    else
      mod.broadcast(snd_port, "selectors", s.serialize(selectors))
    end
  elseif command == "rescan" then
    scanSelectors()
  elseif command == "extract" then
    extractLocation(param)
  elseif command == "quit" then
    break
  elseif command == "select" then
    if (selectors[param] ~= nil) or ((private_sel[param] ~= nil) and (private_allowed[from] ~= nil)) then
      setLocation(param)
    end
  end
  ::continue::
end
