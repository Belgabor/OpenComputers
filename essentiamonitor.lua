local component = require("component")
local ser = require("serialization")
local me = component.me_controller
local gpu = component.gpu
local fs = component.filesystem

local screen_width = 80
local screen_height = 28
local store_fn = "/aspects.list"
local aspects = {}
local s_aspects = {}
local w_label = 5
local w_amount = 3

component.screen.setTouchModeInverted(true)
gpu.setResolution(screen_width, screen_height)

local s = fs.size(store_fn)

if s > 0 then
  local h = fs.open(store_fn, "r")
  local temp = fs.read(h, s)
  aspects = ser.unserialize(temp)
  fs.close(h)
end

function storeAspects()
  local h = fs.open(store_fn, "w")
  fs.write(h, ser.serialize(aspects))
  fs.close(h)
  
  s_aspects = {}
  for n in pairs(aspects) do
    table.insert(s_aspects, n)
  end
  table.sort(s_aspects)
end

function getAspects()
  local fluids = me.getFluidsInNework()
  for k in pairs(aspects) do
    aspects[k] = 0
  end
  w_amount = 3
  local new_aspect = false
  for i, f in pairs(fluids) do
    if type(f) == "table" then
      if f.name and (string.sub(f.name, 1, 7) == "gaseous") and (string.sub(f.name, -8, -1) == "essentia") then
        local name = string.sub(f.label, 1, -5)
        local amount = f.amount / 250
        
        if aspects[name] == nil then
          new_aspect = true
        end
        aspects[name] = amount
        w_label = math.max(w_label, string.len(name))
        w_amount = math.max(w_amount, string.len(amount))
      end
    end
  end
  
  if new_aspect then
    storeAspects()
  end
end

function draw()
  gpu.fill(1, 1, screen_width, screen_height, ' ')
  local row = 1
  
  local w_column = w_label + w_amount + 1
  local space = screen_width - (2*w_column)
  local x = math.floor(space/3)
  
  local a = x
  local b = x
  local f = space - (3*x)
  if f == 1 then
    b = b + 1
  elseif f == 2 then
    a = a + 1
  end
  local column = 1 + a
  
  for i, n in ipairs(s_aspects) do
    gpu.set(column, row, n)
    local amount = aspects[n]
    gpu.set(column + w_label + 1 + (w_amount - string.len(amount)), row, tostring(amount))
    
    row = row+1
    if row > screen_height then
      row = 1
      column = column + w_column + b
    end
  end
end;

getAspects()
storeAspects()
draw()

while true do
  getAspects()
  draw()
  os.sleep(5)
end


