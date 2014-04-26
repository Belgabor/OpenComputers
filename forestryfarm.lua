--local robot = require("robot")
local os = require("os")

local tArgs = {...}

function moveFail(resaon)
  print("Failed to move: "..reason)
  os.exit(false)
end

function safeMove(dir)
  if dir == 1 then
    -- forward
    local m, r = robot.detect()
    if m then
      robot.swing()
    end
    m, r = robot.forward()
    if not m then
      moveFail(r)
    end
  elseif dir == 2 then
    -- up
    local m, r = robot.detectUp()
    if m then
      robot.swingUp()
    end
    m, r = robot.up()
    if not m then
      moveFail(r)
    end
  elseif dir == 2 then
    -- down
    local m, r = robot.detectDown()
    if m then
      robot.swingDown()
    end
    m, r = robot.down()
    if not m then
      moveFail(r)
    end
  end
end

if #tArgs > 4 or #tArgs < 3 then
  print("wrong number of arguments")
  print("forestryfarm.lua orientation depth width [vertical_offset]")
  print("- orientation is 'r' or 'l' to build to the right or left respectively")
  print("- depth must be the larger dimension")
  print("- vertical offset: by default the farm blocks are build flush with the farmland (0), use positive numbers to have them built higher (4 max)")
  return
end

local left = false
if tArgs[1] == "l" then
  left = true
elseif tArgs[1] ~= "r" then
  print("Error! " .. tArgs[1])
  return
end

local depth = tArgs[2]
local width = tArgs[3]
local voffset = 0

if #tArgs > 3 then
  voffset = tArgs[4]
end

if width > depth then
  print("Error: must go longer side first")
  return
end

local valid = false
local core_depth = 0
local core_width = 0
if depth == 11 then
  core_depth = 3
  if width == 11 then
    core_width = 3
    valid = true
  end
elseif depth == 14 then
  core_depth = 4
  if width == 13 or width == 14 then
    core_width = width - 10
    valid = true
  end
elseif depth == 17 then
  core_depth = 5
  if width == 15 or width == 17 then
    core_width = width - 12
    valid = true
  end
end
local wing = (depth - core_depth) / 2
local nFarm = core_depth * core_width * 4
local nLand = (2 * wing * core_width) + (2 * core_depth * wing) + (2 * wing * (wing-1))

if not valid then
  print("Error: "..depth.."x"..width.." is not a valid farm size.")
  return
else
  print("Dimensions ok, need")
  print("- "..nFarm.." farm blocks")
  print("- "..nLand.." farmland blocks")
end

if voffset < 0 or voffset > 4 then
  print ("Error: invalid vertical offset "..voffset)
  return
end

safeMove(1)
if left then
  robot.turnLeft()
  for i = 1,width do
    safeMove(1)
  end
  robot.turnRight()
end

