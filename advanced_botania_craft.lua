local component = require("component")
local shell = require("shell")
local event = require("event")
local unicode = require("unicode")
local serialization = require("serialization")
local filesystem = require("filesystem")

local gpu = component.gpu

local bg_default = 0
local bg_button = 0xFF0000
local bg_button_hl = 0x00CC00
local bg_title = 0xCCCCCC

local fg_default = 0xCCCCCC
local fg_title = 0x000000

local recipe_folder = "/recipes"

local sw, sh = gpu.getResolution()

local dirty = True
local key_shift = false
local key_ctrl = false

local me
if component.isAvailable("me_controller") then
  me = component.me_controller
elseif component.isAvailable("me_interface") then
  me = component.me_interface
else
  print("No ME inventory access (controller or full block interface) available.")
  os.exit()
end

local dbs
local have_dbs = false
function refreshDbs()
  dbs = {}
  for addr, dummy in component.list("database") do
    dbs[addr] = component.proxy(addr)
    have_dbs = true
  end
end

refreshDbs()

if not have_dbs then
  print("No databases found.")
  os.exit()
end

local recipes = {}
for fname in filesystem.list(recipe_folder) do
  local fullname = recipe_folder.."/"..fname
  if string.sub(fname, -9) == ".compiled" then
    print("Loading "..fname.."...")
    local f = io.open(fullname, "r")
    local r = serialization.unserialize(f:read("*all"))
    f:close()
    
    local recipe_broken = false
    for s, set in ipairs(r.sets) do
      for i, item in ipairs(set) do
        local db = dbs[item.db]
        
        if not db then
          recipe_broken = true
          print("  Error: Item '"..item.label.."' not found")
          break
        end
        
        local the_item = db.get(item.index)
        if not the_item then
          recipe_broken = true
          print("  Error: Item '"..item.label.."' not found")
          break
        end
        
        item.item = the_item
      end
      if recipe_broken then
        break
      end
    end
    
    if not recipe_broken then
      table.insert(recipes, r)
    end
  end
end

if #recipes == 0 then
  print("No valid recipes found.")
  os.exit()
end

local cols = math.ceil(#recipes/(sh-2))
local col_width = math.floor((sw-((cols-1)*2))/cols)

local col_map

function initColmap()
  col_map = {}
  for i = 1,cols do
    col_map[i] = {l=1+(i-1)*(col_width+2)}
    col_map[i].r = col_map[i].l + col_width - 1
  end
end

function clearScreen()
  gpu.fill(1, 1, sw, sh, ' ')
end

function blinkButton(fun)
  gpu.setBackground(bg_button_hl)
  fun()
  os.sleep(0.2)
  gpu.setBackground(bg_button)
  fun()
end

function drawQuit()
  gpu.set(sw-6, sh, " Quit ")
end

function drawCancel()
  gpu.set(sw-8, sh, " Cancel ")
end

local count_dirty
local the_count
local current_count

function displayCountButtons()
  gpu.fill(1, sh, sw, sh, ' ')
  
  local s = tostring(current_count)
  gpu.set(math.floor((sw-string.len(s))/2), sh, s)
  
  gpu.setBackground(bg_button)
  drawCancel()
  gpu.setBackground(bg_default)
end

function displayCount(recipe)
  clearScreen()
  gpu.setForeground(fg_title)
  gpu.setBackground(bg_title)
  local n = recipe.name
  gpu.fill(1, 1, sw, 1, " ")
  gpu.set(math.floor((sw-string.len(n))/2), 1, n)
  
  gpu.setForeground(fg_default)
  gpu.setBackground(bg_default)
  local row = 2
  for i, set in ipairs(recipe.sets) do
    row = row + 1
    gpu.set(1, row, "Set #"..i)
    for x, item in ipairs(set) do
      row = row + 1
      gpu.set(3, row, item.me.count.." "..item.label)
    end
  end
    
end

function changeCount(diff)
  local old = current_count
  if (diff > 0) then
    if (diff > 1) and (current_count == 1) then
      current_count = diff
    else
      current_count = current_count + diff
    end
  else
    current_count = current_count + diff
    if current_count < 1 then
      current_count = 1
    end
  end
  if current_count ~= old then
    count_dirty = true
  end
end

function handleCountButtonTouch(x, button)
  if (x>=sw-8) and (x<=sw-1) then
    blinkButton(drawCancel)
    the_count = 0
  end
  gpu.setBackground(bg_default)
end

function handleCountTouch(screen, x, y, button, player)
  if (y == sh) then
    handleCountButtonTouch(x,button)
    return
  end
end

function handleCountKey(kb, char, code, player)
  if char == 0 then
    if code == 42 then
      key_shift = true
    elseif code == 29 then
      key_ctrl = true
    elseif code == 205 then
      if key_shift then
        changeCount(64)
      else
        changeCount(1)
      end
    elseif code == 203 then
      if key_shift then
        changeCount(-64)
      else
        changeCount(-1)
      end
    elseif code == 200 then
      if key_shift then
        changeCount(100)
      else
        changeCount(10)
      end
    elseif code == 208 then
      if key_shift then
        changeCount(-100)
      else
        changeCount(-10)
      end
    end
  end
end

function handleCountKeyUp(kb, char, code, player)
  if char == 0 then
    if code == 42 then
      key_shift = false
    elseif code == 29 then
      key_ctrl = false
    end
  end
end

function handleCountScroll(screen, x, y, direction, player)
  if key_shift then
    if key_ctrl then
      direction = direction * 64
    else
      direction = direction * 10
    end
  else
    if key_ctrl then
      direction = direction * 100
    end
  end
  changeCount(direction)
end

function handleCountEvent(ev, ...)
  if ev=="touch" then
    handleCountTouch(...)
  elseif ev=="key_down" then
    handleCountKey(...)
  elseif ev=="key_up" then
    handleCountKeyUp(...)
  elseif ev=="scroll" then
    handleCountScroll(...)
  end
end


function getCraftCount(recipe)
  clearScreen()
  gpu.set(1,1,"Querying ME...")
  for s, set in ipairs(recipe.sets) do
    for i, item in ipairs(set) do
      local info = me.getItemsInNetwork(item.item)[1]
      local lcraftable = #me.getCraftables(item.item)
      local lcount = 0
      if info then
        lcount = info.size
      end
      item.me = {count=lcount, craftable=(lcraftable > 0)}
    end
  end
  
  count_dirty = true
  the_count = -1
  current_count = 1
  while true do
    if count_dirty then
      displayCount(recipe)
      displayCountButtons(recipe)
      
      count_dirty = false
    end
    handleCountEvent(event.pull())
    
    if the_count >= 0 then
      return the_count
    end
  end
end

function craft(recipe)
  local n = getCraftCount(recipe)
  if (n==0) then
    return
  end
end

function displayRecipe()
  initColmap()
  clearScreen()
  local current_col = 1
  local current_row = 1
  
  for i, recipe in ipairs(recipes) do
    local s = ""
    if i<10 then
      s = "00"
    elseif i<100 then
      s = "0"
    end
    s = s..i.." "..recipe.name
    gpu.set(col_map[current_col].l, current_row, string.sub(s, 1, col_width))
    col_map[current_col][current_row] = i
    
    current_row = current_row + 1
    if current_row > (sh-2) then
      current_row = 1
      current_col = current_col + 1
    end
  end
end

function displayRecipeButtons()
  gpu.fill(1, sh, sw, sh, ' ')
  gpu.setBackground(bg_button)
  drawQuit()
  gpu.setBackground(bg_default)
end

function handleRecipeButtonTouch(x, button)
  if (x>=sw-6) and (x<=sw-1) then
    blinkButton(drawQuit)
    gpu.setBackground(bg_default)
    clearScreen()
    os.exit()
  end
  gpu.setBackground(bg_default)
end

function handleRecipeTouch(x, y, button)
  if (y == sh) then
    handleRecipeButtonTouch(x,button)
    return
  end
  for c = 1, cols do
    if (x >= col_map[c].l) and (x <= col_map[c].r) then
      local item = col_map[c][y]
      if item then
        craft(recipes[item])
        dirty = true
        break
      end
    end
  end
end

dirty = true
while true do
  if dirty then
    displayRecipe()
    displayRecipeButtons()
    
    dirty = false
  end
  local ev, _, x, y, button, player = event.pull("touch")
  handleRecipeTouch(x,y,button)
end
