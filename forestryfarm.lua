--local robot = require("robot")
local os = require("os")

local tArgs = {...}

if #tArgs ~= 4 then
  print("wrong number of arguments")
  os.exit(false)
end

local left = false
if tArgs[1] == "l" then
  left = true
elseif tArgs[1] ~= "r" then
  print("Error! " .. tArgs[1])
  os.exit(false)
end

local depth = tArgs[2]
local width = tArgs[3]
local hoffset = tArgs[4]
if width > depth then
  print("Error: must go longer side first")
  os.exit(false)
end

local valid = false
if depth == 11 then
  if width == 11 then
    valid = true
  end
elseif depth == 14 then
  if width == 13 or width == 14 then
    valid = true
  end
end
