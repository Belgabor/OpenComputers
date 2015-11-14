local component = require("component")
local modem = component.modem
local shell = require("shell")
local event = require("event")

local args, opts = shell.parse(...)

local commport = 1
local nm = "nanomachines"
local effects = {}
local have_effects = false

if #args == 0 then
  print("Commands:")
  print("status [all] ", "Print player and nanomachine status. Adding 'all' queries all input channels for status")
  print("examine      ", "Go through all input channels and check for effects. The list is stored and displayed on 'status' and 'list' commands")
  print("list         ", "List all stored input channel information (unimplemented)")
  print("on <input>   ", "Turn on input #<input>")
  print("off [<input>]", "Turn off input #<input>. Without a specific input it deactivates all")
  print("save         ", "Store nanomachine configuration in a fresh nanomachine item in your inventory. Note: This isn't officially documented, so it might go away.")
  print("drain        ", "Checks nanomachine power drain")
  os.exit()
end

modem.open(commport)

function send(command, arg1, arg2)
  if arg1 == nil then
    return modem.broadcast(commport, nm, command)
  elseif arg2 == nil then
    return modem.broadcast(commport, nm, command, arg1)
  else
    return modem.broadcast(commport, nm, command, arg1, arg2)
  end
end

function receive(answer)
  local ev, rec, send, port, dist, check_nm, message, m_arg1, m_arg2 = event.pull(10, "modem_message", nil, nil, commport, nil, nm)
  if ev == nil then
    print("Failed to communicate on port "..commport)
    os.exit()
  end
  if (message ~= answer) then
    print("Unexpected Response '"..message.."'. Expected: "..answer)
    os.exit()
  end
  return m_arg1, m_arg2
end

-- Establish connection
send("setResponsePort", commport)
while true do
  local m_args = receive("port")
  if (m_args ~= commport) then
    print("Unexpected Response:", m_args)
    os.exit()
  end
  break
end

function activeEffects()
  send("getActiveEffects")
  x1 = receive("effects")
  local r = "None"
  if #x1 > 2 then
    r = string.sub(x1, 2, -2)
  end
  print("Active Effects:", r)
end

function activate(inp)
  send("setInput", inp, true)
  local x1, x2 = receive("input")
  if (x1 ~= inp) or (x2 ~= true) then
    print("Failed to activate input "..inp..":", x1, x2)
    os.exit()
  end
end

function deactivate(inp)
  send("setInput", inp, false)
  local x1, x2 = receive("input")
  if (x1 ~= inp) or (x2 ~= false) then
    print("Failed to deactivate input "..inp..":", x1, x2)
    os.exit()
  end
end

function readEffects(player)
  effects = {}
  local f = io.open(player..".inputs", "r")
  if f then
    for l in f:lines() do
      local _, _, inp, eff = string.find(l, "(%d+),(.+)")
      effects[tonumber(inp)] = eff
      have_effects = true
    end
    f:close()
  end
end

function printEffects()
  for i, e in pairs(effects) do
    print("Input #"..i, e)
  end
end

send("getName")
local name, _ = receive("name")

readEffects(name)


print("Connection established! Hello "..name.."!")

if args[1] == "status" then
  local h1, h2, h3
  send("getPowerState")
  h1, h2 = receive("power")
  print("Power:", h1.."/"..h2)
  send("getHealth")
  h1, h2 = receive("health")
  print("Health:", h1.."/"..h2)
  send("getHunger")
  h1, h2 = receive("hunger")
  print("Hunger:", h1)
  print("Saturation:", h2)
  send("getExperience")
  h1 = receive("experience")
  print("Level:", h1)
  send("getAge")
  h1 = receive("age")
  print("Age:", h1)
  activeEffects()
  send("getTotalInputCount")
  h1 = receive("totalInputCount")
  send("getSafeActiveInputs")
  h2 = receive("safeActiveInputs")
  send("getMaxActiveInputs")
  h3 = receive("maxActiveInputs")
  print("Inputs (safe/max/total):", h2.."/"..h3.."/"..h1)
  
  if have_effects then
    print("Known input effects:")
    printEffects()
  end
  
  if (#args > 1) and (args[2]=="all") then
    for i = 1,h1 do
      send("getInput", i)
      local inp, x = receive("input")
      print("Input", inp, x)
    end
  end
elseif args[1] == "examine" then
  send("getTotalInputCount")
  local inps = receive("totalInputCount")
  print("Total Inputs:", inps)
  if have_effects then
    print("Current input effects:")
    printEffects()
  end
  print("Examining input effects...")
  for i = 1,inps do
    local x1, x2
    activate(i)
    send("getActiveEffects")
    x1 = receive("effects")
    local r = "None"
    if #x1 > 2 then
      r = string.sub(x1, 2, -2)
      effects[i] = r
    else
      effects[i] = nil
    end
    print("Input #"..i, r)
    deactivate(i)
  end
  print("Summary:")
  printEffects()
  local f = io.open(name..".inputs", "w")
  if f then
    for i, e in pairs(effects) do
      f:write(i, ",", e, "\n")
    end
    f:close()
  end
elseif args[1] == "on" then
  if #args < 2 then
    print("Error: 'on' requires the input number as argument")
    os.exit()
  end
  local inp = tonumber(args[2])
  if inp==nil then
    print("Error: '"..args[2].."' is not a number")
    os.exit()
  end
  activate(inp)
  activeEffects()
elseif args[1] == "off" then
  if #args < 2 then
    send("getTotalInputCount")
    local inps = receive("totalInputCount")
    print("Total Inputs:", inps)
    print("Deactivating all inputs...")
    for i = 1,inps do
      deactivate(i)
    end
  else
    local inp = tonumber(args[2])
    if inp==nil then
      print("Error: '"..args[2].."' is not a number")
      os.exit()
    end
    deactivate(inp)
  end
  activeEffects()
elseif args[1] == "save" then
  print("Saving nanomachines configuration")
  send("saveConfiguration")
  local success, error = receive("saved")
  if success then
    print("OK!")
  else
    print("Error:", error)
  end
elseif args[1] == "drain" then
  local duration = 10
  if #args > 1 then
    duration = tonumber(args[2])
    if duration==nil then
      print("Error: '"..args[2].."' is not a number")
      os.exit()
    end
  end
  print("Checking power drain...")
  local h1, h2, h3
  send("getPowerState")
  h1, h2 = receive("power")
  local x = os.time()
  print("Current Power: "..h1)
  os.sleep(duration)
  send("getPowerState")
  h3, h2 = receive("power")
  x = (os.time() - x)/72
  print("Actual time taken: "..x.." seconds")
  local drain = h1-h3
  print("Power drained (total/per sec): "..drain.."/"..(drain/x))
  local left = h3*x/drain
  print("Estimated time left: "..math.floor(left/60).." minutes "..(left % 60).." seconds")
else
  print("Unknown argument:", args[1])
end
