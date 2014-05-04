local robot = require("robot")
local os = require("os")

local tArgs = {...}

local currentfarm = 1
local currentland = 5

local forward = 1
local up = 2
local down = 3
local farm = 1
local land = 2

local clear = false

function fail(reason)
  print(reason)
  os.exit(false)
end

function safeMove(dir)
  if dir == forward then
    -- forward
    local m, r = robot.detect()
    if m then
      robot.swing()
    end
    m, r = robot.forward()
    if not m then
      fail("Failed to move: "..r)
    end
  elseif dir == up then
    -- up
    local m, r = robot.detectUp()
    if m then
      robot.swingUp()
    end
    m, r = robot.up()
    if not m then
      fail("Failed to move: "..r)
    end
  elseif dir == down then
    -- down
    local m, r = robot.detectDown()
    if m then
      robot.swingDown()
    end
    m, r = robot.down()
    if not m then
      fail("Failed to move: "..r)
    end
  end
end

function safePlace(dir, type)
  if not clear then
    if type == farm then
      while robot.count(currentfarm) == 0 do
        currentfarm = currentfarm + 1
        if currentfarm > 4 then
          fail("Out of farm blocks.")
        end
      end
      robot.select(currentfarm)
    elseif type == land then
      while robot.count(currentland) == 0 do
        currentland = currentland + 1
        if currentland > 8 then
          fail("Out of farmland blocks.")
        end
      end
      robot.select(currentland)
    end
  end
  if dir == forward then
    -- forward
    local m, r = robot.detect()
    if m then
      robot.swing()
    end
    if not clear then
      m = robot.place()
      if not m then
        fail("Failed to place block, probably due to "..r)
      end
    end
  elseif dir == up then
    -- up
    local m, r = robot.detectUp()
    if m then
      robot.swingUp()
    end
    if not clear then
      m = robot.placeUp()
      if not m then
        fail("Failed to place block, probably due to "..r)
      end
    end
  elseif dir == down then
    -- down
    local m, r = robot.detectDown()
    if m then
      robot.swingDown()
    end
    if not clear then
      m = robot.placeDown()
      if not m then
        fail("Failed to place block, probably due to "..r)
      end
    end
  end
end

if #tArgs > 4 or #tArgs < 3 then
  print("wrong number of arguments")
  print("forestryfarm.lua orientation depth width [vertical_offset]")
  print("Use slots 1-4 for farm blocks, slots 5-8 for farmland blocks.")
  print("- orientation is 'r' or 'l' to build to the right or left respectively.\n  Add a 'c' to run in clear mode (make room, do not build farm). Recommended if large amounts of the target space are filled or you might get wrong blocks placed.\n  Alternatively you can add a 'v' to run in verify mode to validate parameters and supplies.")
  print("- depth must be the larger dimension")
  print("- vertical offset: by default the farm blocks are build flush with the farmland (0), use positive numbers to have them built higher (4 max)")
  return
end

local left = false
local verify = false
local mode = tArgs[1]
mode:lower()
if mode:find("l") then
  left = true
elseif not mode:find("r") then
  print("Error: No direction set " .. mode)
  return
end

if mode:find("c") then
  clear = true
  print("Running in clear mode")
end

if mode:find("v") then
  verify = true
  print("Running in verify mode")
end

local depth = tonumber(tArgs[2])
local width = tonumber(tArgs[3])
local voffset = 0

if #tArgs > 3 then
  voffset = tonumber(tArgs[4])
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
  -- check inventory
  local haveFarm = 0
  local haveLand = 0
  for i = 1,4 do
    haveFarm = haveFarm + robot.count(i)
  end
  for i = 5,8 do
    haveLand = haveLand + robot.count(i)
  end

  print("Dimensions ok, need")
  print("- "..nFarm.." farm blocks ("..haveFarm..")")
  print("- "..nLand.." farmland blocks ("..haveLand..")")
  if not clear then
    if haveFarm < nFarm or haveLand < nLand then
      print("Error: Not enough blocks in inventory")
      return
    end
  end
end

if voffset < 0 or voffset > 4 then
  print ("Error: invalid vertical offset "..voffset)
  return
end

if verify then
  return
end

safeMove(forward)
if left then
  robot.turnLeft()
  for i = 1,width do
    safeMove(forward)
  end
  robot.turnRight()
end

-- build land
local odd = true

function nextRow()
  if odd then
    robot.turnRight()
    safeMove(forward)
    robot.turnRight()
  else
    robot.turnLeft()
    safeMove(forward)
    robot.turnLeft()
  end
  odd = not odd
end

for x = 0,(wing-1) do
  for i = 1,(wing-x) do
    safeMove(forward)
  end
  for i = 1, (core_depth + (x*2)) do
    safePlace(down, land)
    safeMove(forward)
  end
  for i = 1,(wing-x-1) do
    safeMove(forward)
  end
  nextRow()
end

for x = 1,core_width do
  for i = 1,wing do
    safePlace(down, land)
    safeMove(forward)  
  end
  for i = 1,core_depth do
    safeMove(forward)
  end
  for i = 1,(wing-1) do
    safePlace(down, land)
    safeMove(forward)  
  end
  safePlace(down, land)
  nextRow()
end

for x = (wing-1),0,-1 do
  for i = 1,(wing-x) do
    safeMove(forward)
  end
  for i = 1, (core_depth + (x*2)) do
    safePlace(down, land)
    safeMove(forward)
  end
  for i = 1,(wing-x-1) do
    safeMove(forward)
  end
  if x > 0 then
    nextRow()
  end
end

-- move into position
for c = 1,2 do
  if odd then
    robot.turnLeft()
  else
    robot.turnRight()
  end
  for i = 1,wing do
    safeMove(forward)
  end
end

if voffset == 4 then
  safeMove(up)
else
  for c = 1, (3-voffset) do
    safeMove(down)
  end
end

for h = 1,4 do
  for x = 1,core_width do
    for y = 1,(core_depth - 1) do
      safePlace(down, farm)
      safeMove(forward)
    end
    safePlace(down, farm)
    if x < core_width then
      nextRow()
    end
  end
  safeMove(up)
  robot.turnAround()
end

