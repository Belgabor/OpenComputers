local component = require("component")
local shell = require("shell")
local event = require("event")
local unicode = require("unicode")
local serialization = require("serialization")
local filesystem = require("filesystem")
local colors = require("colors")
local sides = require("sides")

local gpu = component.gpu
local redstone = component.redstone

local bg_default = 0
local bg_button = 0xFF0000
local bg_button_hl = 0x00CC00
local bg_title = 0xCCCCCC

local fg_default = 0xCCCCCC
local fg_title = 0x000000

function setColors(tag)
  if tag == "default" then
    gpu.setBackground(bg_default)
    gpu.setForeground(fg_default)
  elseif tag == "valid" then
    gpu.setBackground(bg_default)
    gpu.setForeground(0x00FF00)
  elseif tag == "craftable" then
    gpu.setBackground(bg_default)
    gpu.setForeground(0xFFFF00)
  elseif tag == "invalid" then
    gpu.setBackground(bg_default)
    gpu.setForeground(0xFF0000)
  end  
end

local interfaces = {
  component.proxy("1b9ae71b-dfb1-4b29-a370-be5897e77430"),
  component.proxy("f198827c-402c-4afa-b451-e81947e8ee5f")
}

local interface_sides = {
  sides.top,
  sides.east
}

local rs_side = sides.right
local rs_o_toggle_bus = colors.lime
local rs_o_activator = colors.lightblue
local rs_o_dispenser = colors.yellow
local rs_i_apothecary = colors.white
local rs_i_brewery = colors.orange
local rs_i_altar = colors.magenta

local recipe_folder = "/recipes"

local transposer_apothecary = sides.north
local transposer_brewery = sides.west
local transposer_altar = sides.south

local sleep_item_missing = 1
local sleep_pulse = 1
local sleep_wait_apothecary_water = 5
local sleep_wait_item_crafting = 5
local sleep_apothecary_seed_delay = 0.5
local sleep_brewery_item_delay = 0.5
local sleep_wait_brewery_crafting = 5
local sleep_wait_brewery_initiate_crafting = 2
local sleep_altar_start_delay = 1
local sleep_wait_altar_initiate_crafting = 2
local sleep_wait_altar_crafting = 5
local sleep_altar_finish_delay = 1

-- -------

local rs_level_apothecary_water = 243
local rs_level_brewery_crafting = 7
local rs_level_altar_crafting = 7
local rs_level_altar_done = 24

local sw, sh = gpu.getResolution()
local sw2 = math.floor(sw/2)

local dirty = True
local key_shift = false
local key_ctrl = false

local transposer
if (component.isAvailable("transposer")) then
  transposer = component.transposer
else
  transposer = component.inventory_controller
end

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

table.sort(recipes, function(a,b) return a.name < b.name end)

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

function drawCraft()
  gpu.set(2, sh, " Craft ")
end

function drawUp1()
  gpu.set(sw2+5, sh, " > ")
end

function drawUp10()
  gpu.set(sw2+8, sh, " > ")
end

function drawUp64()
  gpu.set(sw2+11, sh, " > ")
end

function drawUp100()
  gpu.set(sw2+14, sh, " > ")
end

function drawDown1()
  gpu.set(sw2-9, sh, " < ")
end

function drawDown10()
  gpu.set(sw2-12, sh, " < ")
end

function drawDown64()
  gpu.set(sw2-15, sh, " < ")
end

function drawDown100()
  gpu.set(sw2-18, sh, " < ")
end

local count_dirty
local the_count
local current_count

function displayCountButtons()
  gpu.fill(1, sh, sw, sh, ' ')
  
  local s = tostring(current_count)
  gpu.set(math.floor((sw-string.len(s))/2), sh, s)
  
  gpu.setBackground(bg_button)
  drawCraft()
  drawDown1()
  drawDown10()
  drawDown64()
  drawDown100()
  drawUp1()
  drawUp10()
  drawUp64()
  drawUp100()
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
  local count_cache = {}
  for i, set in ipairs(recipe.sets) do
    row = row + 1
    setColors("default")
    gpu.set(1, row, "Set #"..i)
    for x, item in ipairs(set) do
      row = row + 1
      local count = item.me.count
      if count_cache[item.hash] ~= nil then
        count = count_cache[item.hash]
      end
      if count >= current_count then
        setColors("valid")
      elseif item.me.craftable then
        setColors("craftable")
      else
        setColors("invalid")
      end
      gpu.set(3, row, count.." "..item.label)
      count_cache[item.hash] = count - current_count
    end
  end
  setColors("default")
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
  end
  if current_count < 1 then
    current_count = 1
  end
  if current_count ~= old then
    count_dirty = true
  end
end

function handleCountButtonTouch(x, button)
  if (x>=2) and (x<=8) then
    blinkButton(drawCraft)
    the_count = current_count
  elseif (x>=sw2-18) and (x<sw2-15) then
    blinkButton(drawDown100)
    changeCount(-100)
  elseif (x>=sw2-15) and (x<sw2-12) then
    blinkButton(drawDown64)
    changeCount(-64)
  elseif (x>=sw2-12) and (x<sw2-9) then
    blinkButton(drawDown10)
    changeCount(-10)
  elseif (x>=sw2-9) and (x<sw2-6) then
    blinkButton(drawDown1)
    changeCount(-1)
  elseif (x>=sw2+5) and (x<sw2+8) then
    blinkButton(drawUp1)
    changeCount(1)
  elseif (x>=sw2+8) and (x<sw2+11) then
    blinkButton(drawUp10)
    changeCount(10)
  elseif (x>=sw2+11) and (x<sw2+14) then
    blinkButton(drawUp64)
    changeCount(64)
  elseif (x>=sw2+14) and (x<sw2+17) then
    blinkButton(drawUp100)
    changeCount(100)
  elseif (x>=sw-8) and (x<=sw-1) then
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

function displayCraftTitle(title)
  clearScreen()
  gpu.set(1,1,"Crafting "..title)
end

function displayCraftIteration(n, o)
  gpu.fill(1, 2, sw, 1, " ")
  gpu.set(1,2,"Iteration: "..n.."/"..o)
end

function displayCraftStatus(status)
  gpu.fill(1, 3, sw, 1, " ")
  gpu.set(1, 3, "Status: "..status)
end

function clearInterfaces()
  for i, iface in ipairs(interfaces) do
    for s = 1,8 do
      iface.setInterfaceConfiguration(s)
    end
  end
end

function disableInterfaces(doit)
  if doit then
    redstone.setBundledOutput(rs_side, rs_o_toggle_bus, 255)
  else
    redstone.setBundledOutput(rs_side, rs_o_toggle_bus, 0)
  end
end

function pulse(color)
  redstone.setBundledOutput(rs_side, color, 255)
  os.sleep(sleep_pulse)
  redstone.setBundledOutput(rs_side, color, 0)
end

function craftApothecary(recipe)
  displayCraftStatus("Crafting: Filling petal apothecary")
  while true do
    pulse(rs_o_activator)
    if redstone.getBundledInput(rs_side, rs_i_apothecary) == rs_level_apothecary_water then
      break
    end
    os.sleep(sleep_wait_apothecary_water)
  end
  
  displayCraftStatus("Crafting: Dropping items")
  local current_interface = 1
  local current_slot = 1
  for i = 1, #recipe.sets[1] do
    while not transposer.transferItem(interface_sides[current_interface], transposer_apothecary, 1, current_slot, 1) do
      os.sleep(sleep_wait_item_crafting)
    end
    
    current_slot = current_slot + 1
    if current_slot > 8 then
      current_slot = 1
      current_interface = current_interface + 1
    end
  end
  
  os.sleep(sleep_apothecary_seed_delay)
  
  for i = 1, #recipe.sets[2] do
    while not transposer.transferItem(interface_sides[current_interface], transposer_apothecary, 1, current_slot, 1) do
      os.sleep(sleep_wait_item_crafting)
    end
    
    current_slot = current_slot + 1
    if current_slot > 8 then
      current_slot = 1
      current_interface = current_interface + 1
    end
  end
end

function craftBrewery(recipe)
  displayCraftStatus("Crafting: Dropping items")
  local current_interface = 1
  local current_slot = 1
  for i = 1, #recipe.sets[1] do
    while not transposer.transferItem(interface_sides[current_interface], transposer_brewery, 1, current_slot, 1) do
      os.sleep(sleep_wait_item_crafting)
    end
    
    current_slot = current_slot + 1
    if current_slot > 8 then
      current_slot = 1
      current_interface = current_interface + 1
    end
  end
  
  os.sleep(sleep_brewery_item_delay)
  
  for i = 1, #recipe.sets[2] do
    while not transposer.transferItem(interface_sides[current_interface], transposer_brewery, 1, current_slot, 1) do
      os.sleep(sleep_wait_item_crafting)
    end
    
    current_slot = current_slot + 1
    if current_slot > 8 then
      current_slot = 1
      current_interface = current_interface + 1
    end
  end

  displayCraftStatus("Crafting: Waiting for brewery to finish")
  os.sleep(sleep_wait_brewery_initiate_crafting)
  while redstone.getBundledInput(rs_side, rs_i_brewery) == rs_level_brewery_crafting do
    os.sleep(sleep_wait_brewery_crafting)
  end
end

function craftAltar(recipe)
  displayCraftStatus("Crafting: Dropping items")
  local current_interface = 1
  local current_slot = 1
  for i = 1, #recipe.sets[1] do
    while not transposer.transferItem(interface_sides[current_interface], transposer_altar, 1, current_slot, 1) do
      os.sleep(sleep_wait_item_crafting)
    end
    
    current_slot = current_slot + 1
    if current_slot > 8 then
      current_slot = 1
      current_interface = current_interface + 1
    end
  end
  
  os.sleep(sleep_altar_start_delay)
  pulse(rs_o_dispenser)
  
  displayCraftStatus("Crafting: Waiting for altar to finish")
  os.sleep(sleep_wait_altar_initiate_crafting)
  while redstone.getBundledInput(rs_side, rs_i_altar) ~= rs_level_altar_done do
    os.sleep(sleep_wait_altar_crafting)
  end
  
  displayCraftStatus("Crafting: Finishing altar crafting")
  for i = 1, #recipe.sets[2] do
    while not transposer.transferItem(interface_sides[current_interface], transposer_altar, 1, current_slot, 1) do
      os.sleep(sleep_wait_item_crafting)
    end
    
    current_slot = current_slot + 1
    if current_slot > 8 then
      current_slot = 1
      current_interface = current_interface + 1
    end
  end
  
  os.sleep(sleep_altar_finish_delay)
  pulse(rs_o_dispenser)

end

local crafting = {
  altar=craftAltar,
  apothecary=craftApothecary,
  brewery=craftBrewery
}

function craft(recipe)
  local count = getCraftCount(recipe)
  if (count==0) then
    return
  end

  displayCraftTitle(recipe.name)
  displayCraftStatus("Setting up")
  
  local current_interface = 1
  local current_slot = 1
  
  clearInterfaces()
  disableInterfaces(false)
  
  for s, set in ipairs(recipe.sets) do
    for i, item in ipairs(set) do
      interfaces[current_interface].setInterfaceConfiguration(current_slot, item.db, item.index, 1)
      
      current_slot = current_slot + 1
      if current_slot > 8 then
        current_slot = 1
        current_interface = current_interface + 1
      end
    end
  end
  
  for n = 1, count do
    displayCraftIteration(n,count)
    displayCraftStatus("Waiting for items")
    
    item_missing = true
    while item_missing do
      local current_interface = 1
      local current_slot = 1
      item_missing = false
      for s, set in ipairs(recipe.sets) do
        for i, item in ipairs(set) do
          local c = transposer.getSlotStackSize(interface_sides[current_interface], current_slot)
          if c == 0 then
            item_missing = true
            break
          end
          
          current_slot = current_slot + 1
          if current_slot > 8 then
            current_slot = 1
            current_interface = current_interface + 1
          end
        end
        if item_missing then
          break
        end
      end
      if item_missing then
        os.sleep(sleep_item_missing)
      end
    end
    
    if n == count then
      -- Last iteration, prevent ae crafting of components
      disableInterfaces(true)
    end
   
    displayCraftStatus("Crafting")
    crafting[recipe.rtype](recipe)
  end
  displayCraftStatus("Finishing up")
  clearInterfaces()
  disableInterfaces(false)
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

clearInterfaces()
disableInterfaces(false)

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
