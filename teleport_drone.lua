
local function proxyFor(name, required)
  local address = component and component.list(name)()
  if not address and required then
    error("missing component '" .. name .. "'")
  end
  return address and component.proxy(address) or nil
end

--local sides = require("sides")
local drone = proxyFor("drone", true)
local inv = proxyFor("inventory_controller", true)
local mod = proxyFor("modem", true)

local selectors = {}
local private_sel = {}
local private_allowed = {}
private_allowed["7e0252e2-54a6-4d07-b5c6-c520839371b0"] = 1

local rcv_port = 4901
local snd_port = 4902
--[[
  north 2
  south 3
  west 4
  east 5
]]
local side_input = 3
local side_output = 4 
mod.open(rcv_port)

function scanSelectors()
  selectors = {}
  local slots = inv.getInventorySize(side_input)
  for i = 1,slots do
    local item = inv.getStackInSlot(side_input, i)
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
end

function setLocation(loc)
  inv.suckFromSlot(side_input, loc)
  inv.equip()
  drone.useUp(side_input)
  inv.equip()
  inv.dropIntoSlot(side_input, loc)
end

function extractLocation(loc)
  inv.suckFromSlot(side_input, loc)
  inv.dropIntoSlot(side_output, 1)  
end

-- from serialization.lua
function serialize(value, pretty)
  local kw =  {["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true,
               ["elseif"]=true, ["end"]=true, ["false"]=true, ["for"]=true,
               ["function"]=true, ["goto"]=true, ["if"]=true, ["in"]=true,
               ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true,
               ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
               ["until"]=true, ["while"]=true}
  local id = "^[%a_][%w_]*$"
  local ts = {}
  local function s(v, l)
    local t = type(v)
    if t == "nil" then
      return "nil"
    elseif t == "boolean" then
      return v and "true" or "false"
    elseif t == "number" then
      if v ~= v then
        return "0/0"
      elseif v == math.huge then
        return "math.huge"
      elseif v == -math.huge then
        return "-math.huge"
      else
        return tostring(v)
      end
    elseif t == "string" then
      return string.format("%q", v):gsub("\\\n","\\n")
    elseif t == "table" then
      if ts[v] then
        error("recursion")
      end
      ts[v] = true
      local i, r = 1, nil
      local f
      if pretty then
        local ks, sks, oks = {}, {}, {}
        for k in pairs(v) do
          if type(k) == "number" then
            table.insert(ks, k)
          elseif type(k) == "string" then
            table.insert(sks, k)
          else
            table.insert(oks, k)
          end
        end
        table.sort(ks)
        table.sort(sks)
        for _, k in ipairs(sks) do
          table.insert(ks, k)
        end
        for _, k in ipairs(oks) do
          table.insert(ks, k)
        end
        local n = 0
        f = table.pack(function()
          n = n + 1
          local k = ks[n]
          if k ~= nil then
            return k, v[k]
          else
            return nil
          end
        end)
      else
        f = table.pack(pairs(v))
      end
      for k, v in table.unpack(f) do
        if r then
          r = r .. "," .. (pretty and ("\n" .. string.rep(" ", l)) or "")
        else
          r = "{"
        end
        local tk = type(k)
        if tk == "number" and k == i then
          i = i + 1
          r = r .. s(v, l + 1)
        else
          if tk == "string" and not kw[k] and string.match(k, id) then
            r = r .. k
          else
            r = r .. "[" .. s(k, l + 1) .. "]"
          end
          r = r .. "=" .. s(v, l + 1)
        end
      end
      ts[v] = nil -- allow writing same table more than once
      return (r or "{") .. "}"
    else
        error("unsupported type: " .. t)
    end
  end
  local result = s(value, 1)
  local limit = type(pretty) == "number" and pretty or 10
  return result
end

scanSelectors()

while true do
  local msg, _, from, port, _, command, param = computer.pullSignal()
  if (msg ~= "modem_message") or (port ~= rcv_port) then
    goto cont
  end
  if command == "getSelectors" then
    print("getSelectors", from)
    if (param == 1) and (private_allowed[from] ~= nil) then
      mod.broadcast(snd_port, "selectors", serialize(private_sel))
    else
      mod.broadcast(snd_port, "selectors", serialize(selectors))
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
  ::cont::
end
