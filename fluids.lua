local component = require("component")
local shell = require("shell")
local text = require("text")
local me = component.me_controller
local gpu = component.gpu

local args, options = shell.parse(...)

local liquids = {}
local liquid_width = 5
local amount_width = 4
local columns = 1
local sw, sh = gpu.getResolution()

function getLiquids()
  liquids = {}
  liquid_width = 5
  amount_width = 4
  local me_liquids = me.getFluidsInNetwork()
  for k, v in pairs(me_liquids) do
    if type(v) == "table" then
      liquids[v.name] = v.amount
      liquid_width = math.max(liquid_width, string.len(v.name))
      amount_width = math.max(amount_width, string.len(v.amount))
    end
  end
  columns = math.floor(sw / (liquid_width + amount_width + 3))
end

if (#args == 0) or (args[1] == 'list') then
  local i = columns
  local s = ""
  
  getLiquids()

  local s_liquids = {}
  for n in pairs(liquids) do
    table.insert(s_liquids, n)
  end
  table.sort(s_liquids)
  
  for x, n in ipairs(s_liquids) do
    s = s .. text.padRight(n, liquid_width) .. " " .. text.padLeft(liquids[n], amount_width) .. "  "
    i = i - 1
    if i == 0 then
      i = columns
      print(s)
      s = ""
    end
  end
  
  if s ~= "" then
    print(s)
  end  
elseif args[1] == 'monitor' then
  local q_liquids = text.tokenize(args[2]:gsub(",", " "))
  table.sort(q_liquids)
  getLiquids()
  local pre_liquids = {}
  local t = tonumber(args[3])
  
  for k, v in pairs(q_liquids) do
    pre_liquids[v] = (liquids[v] ~= nil) and liquids[v] or 0
  end
  
  os.sleep(t)
  getLiquids()
  for k, v in ipairs(q_liquids) do
    local current = (liquids[v] ~= nil) and liquids[v] or 0
    local diff = current-pre_liquids[n]
    print(text.padRight(v, liquid_width) .. " " .. text.padLeft(pre_liquids[n], amount_width) .. " " .. text.padLeft(current, amount_width) .. " " .. text.padLeft(diff, amount_width) .. " " .. text.padLeft(diff/t, amount_width))
  end
else
  local q_liquids = text.tokenize(args[2]:gsub(",", " "))
  table.sort(q_liquids)
  getLiquids()
  for k, v in ipairs(q_liquids) do
    print(text.padRight(v, liquid_width) .. " " .. text.padLeft(liquids[n], amount_width))
  end
end
