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

local fg_default = 0xCCCCCC
local fg_hilite = 0xFFFFFF
local fg_error = 0xFF0000

local recipe_types = {"altar", "apothecary", "brewery", "worktable"}
local recipe_folder = "/recipes"

local dirty = true
local query

gpu.setBackground(bg_default)
local sw, sh = gpu.getResolution()
local main_col_width = math.floor((sw-2)/2)
local main_r_column = main_col_width + 2
local main_l_data = 15
local main_dirty = true


local dbs
function refreshDbs()
  dbs = {}
  local i = 0
  for addr, dummy in component.list("database") do
    i = i + 1
    local temp = component.proxy(addr)
    local x1 = pcall(function() temp.get(10) end)
    local x2 = pcall(function() temp.get(26) end)
    local dbsize = 9
    if (x1 and x2) then
      dbsize = 81
    elseif x1 then
      dbsize = 25
    end
    dbs[i] = {db=temp, size=dbsize}
  end
end

refreshDbs()

if #dbs == 0 then
  print("No databases found.")
  os.exit()
end

local the_db

local r_type = ""
local r_name = ""
local r_sets = {{}}
local current_set = -1
local current_name = ""
local main_editing = false

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

function drawSave()
  gpu.set(sw-14, sh, " Save ")
end

function drawAddItem()
  gpu.set(2, sh, " Add Item ")
end

function drawAddSet()
  gpu.set(2, sh, " Add Set ")
end

function drawCancel()
  gpu.set(sw-8, sh, " Cancel ")
end

function drawRefresh()
  gpu.set(2, sh, " Refresh ")
end

function drawChangeDb()
  gpu.set(13, sh, " Change Database ")
end


function setFgError(is_error)
  if is_error then
    gpu.setForeground(fg_error)
  else
    gpu.setForeground(fg_default)
  end
end

local dbs_run
local cols
local col_width
local col_map

function initColmap()
  cols = math.ceil(the_db.size/(sh-2))
  col_width = math.floor((sw-((cols-1)*2))/cols)
  col_map = {}
  for i = 1,cols do
    col_map[i] = {l=1+(i-1)*(col_width+2)}
    col_map[i].r = col_map[i].l + col_width - 1
  end
end

function updateCache(i)
  local item = the_db.db.get(i)
  local s = ""
  if item then
    s = item.label
  end
  the_db.cache[i] = s 
end

function buildCache()
  the_db.cache = {}
  for i = 1,the_db.size do
    updateCache(i)
  end
end

function displayDbsButtons()
  gpu.fill(1, sh, sw, sh, ' ')
  gpu.setBackground(bg_button)
  drawCancel()
  gpu.setBackground(bg_default)
end

function displayDbs()
  clearScreen()
  for i = 1,#dbs do
    gpu.set(1, i, dbs[i].db.address.." ("..dbs[i].size..")")
  end
end

function handleDbsButtonTouch(x, button)
  if (x>=sw-8) and (x<=sw-1) then
    blinkButton(drawCancel)
    dbs_run = false
  end
  gpu.setBackground(bg_default)
end

function handleDbsTouch(x, y, button)
  if (y == sh) then
    handleDbsButtonTouch(x,button)
    return
  end
  if y <= #dbs then
    the_db = dbs[y]
    initColmap()
    buildCache()
    dbs_run = false
  end
end

function setDb()
  dbs_run = true
  refreshDbs()
  displayDbs()
  displayDbsButtons()

  while dbs_run do
    local ev, _, x, y, button, player = event.pull("touch")
    handleDbsTouch(x,y,button)
  end
end

function displayDb()
  clearScreen()
  initColmap()
  local current_col = 1
  local current_row = 1
  
  for i = 1,the_db.size do
    local s = ""
    if i<10 then
      s = "0"
    end
    s = s..i.." "..the_db.cache[i]
    gpu.set(col_map[current_col].l, current_row, string.sub(s, 1, col_width))
    col_map[current_col][current_row] = i
    
    current_row = current_row + 1
    if current_row > (sh-2) then
      current_row = 1
      current_col = current_col + 1
    end
  end
end

function displayDbButtons()
  gpu.fill(1, sh, sw, sh, ' ')
  gpu.setBackground(bg_button)
  drawRefresh()
  drawChangeDb()
  drawCancel()
  gpu.setBackground(bg_default)
end

local the_item

function handleDbButtonTouch(x, button)
  if (x>=2) and (x<=10) then
    blinkButton(drawRefresh)
    initColmap()
    buildCache()
    dirty = true
  end
  if (x>=13) and (x<=29) then
    blinkButton(drawChangeDb)
    gpu.setBackground(bg_default)
    setDb()
    dirty = true
  end
  if (x>=sw-8) and (x<=sw-1) then
    blinkButton(drawCancel)
    the_item = 0
  end
  gpu.setBackground(bg_default)
end

function handleDbTouch(x, y, button)
  if (y == sh) then
    handleDbButtonTouch(x,button)
    return
  end
  for c = 1, cols do
    if (x >= col_map[c].l) and (x <= col_map[c].r) then
      local item = col_map[c][y]
      if item then
        local ref_item = the_db.db.get(item)
        if ref_item ~= nil then
          the_item = {label=ref_item.label, hash=the_db.db.computeHash(item)}
        else
          the_item = {label="-- Spacer --", hash=nil}
        end
        break
      end
    end
  end
end

function getItem()
  the_item = nil
  dirty = true
  while true do
    if dirty then
      displayDb()
      displayDbButtons()
      
      dirty = false
    end
    local ev, _, x, y, button, player = event.pull("touch")
    handleDbTouch(x,y,button)
    
    if the_item == 0 then
      return nil
    elseif the_item then
      return the_item
    end
  end
end

function displayMainButtons()
  gpu.fill(1, sh, sw, sh, ' ')
  if main_editing then
    gpu.set(2, sh, "Name: "..current_name)
  elseif current_set > 0 then
    gpu.setBackground(bg_button)
    drawAddItem()
  else
    gpu.setBackground(bg_button)
    drawAddSet()
  end
  gpu.setBackground(bg_button)
  drawSave()
  drawQuit()
  gpu.setBackground(bg_default)
end

function displayMain()
  clearScreen()
  setFgError(r_name=="")
  gpu.set(1, 1, "Name:")
  gpu.set(main_l_data, 1, r_name)
  if current_set == 0 then
    gpu.setForeground(fg_hilite)
  else
    setFgError(r_type=="")
  end
  gpu.set(1, 2, "Type:")
  gpu.set(main_l_data, 2, r_type)
  for i = 1,#r_sets do
    if i==current_set then
      gpu.setForeground(fg_hilite)
    else
      setFgError(#r_sets[i]==0)
    end
    gpu.set(1, 2+i, "Set #"..i.." ("..#r_sets[i]..")")
  end
  
  if current_set == 0 then
    for i, t in ipairs(recipe_types) do
      if (t==r_type) then
        gpu.setForeground(fg_hilite)
      else
        gpu.setForeground(fg_default)
      end
      gpu.set(main_r_column, i, t)
    end
  elseif current_set>0 then
    gpu.setForeground(fg_default)
    for i, item in ipairs(r_sets[current_set]) do
      local s = ""
      if (i<10) then
        s = "0"
      end
      gpu.set(main_r_column, i, s..i.." "..item.label)
    end
  end
  
  gpu.setForeground(fg_default)
end

function finishEditing(commit)
  if commit then
    r_name = current_name
  end
  main_editing = false
  main_dirty = true
end

function doSave()
  if r_name == "" or r_type == "" then
    return false
  end
  for i, set in ipairs(r_sets) do
    if #set == 0 then
      return false
    end
  end
  local data = {name=r_name, rtype=r_type, sets=r_sets}
  if not filesystem.exists(recipe_folder) then
    filesystem.makeDirectory(recipe_folder)
  end
  local f = io.open(recipe_folder.."/"..r_name..".recipe", "w")
  if not f then
    return false
  end
  f:write(serialization.serialize(data))
  f:close()
  return true
end

function doQuit()
  gpu.setBackground(bg_default)
  gpu.setForeground(0xFFFFFF)
  clearScreen()
  os.exit()
end

function handleMainButtonTouch(x, button)
  if main_editing and (button==1) and (x>=2) and (x<=sw-16) then
    current_name = ""
    main_dirty = true
    return
  end
  if current_set <= 0 then
    if (x>=2) and (x<=10) then
      blinkButton(drawAddSet)
      table.insert(r_sets, {})
      main_dirty = true
    end
  else
    if (x>=2) and (x<=11) then
      blinkButton(drawAddItem)
      gpu.setBackground(bg_default)
      if not the_db then
        setDb()
      end
      if the_db then
        local item = getItem()
        if item then
          table.insert(r_sets[current_set], item)
        end
      end
      main_dirty = true
    end
  end
  if (x>=sw-14) and (x<=sw-9) then
    blinkButton(drawSave)
    if doSave() then
      doQuit()
    else
      os.sleep(0.2)
      blinkButton(drawSave)
      os.sleep(0.2)
      blinkButton(drawSave)
    end
  end
  if (x>=sw-6) and (x<=sw-1) then
    blinkButton(drawQuit)
    doQuit()
  end
  gpu.setBackground(bg_default)
end

function handleMainTouch(screen, x, y, button, player)
  if y == sh then
    handleMainButtonTouch(x, button)
    return
  end
  if x <= main_col_width then
    if y==1 then
      if main_editing and (button == 1) then
        finishEditing(false)
        return
      end
      main_editing = true
      current_name = r_name
      main_dirty = true
      return
    end
    if (button == 0) and main_editing then
      finishEditing(true)
    end
    if y==2 then
      if current_set == 0 then
        current_set = -1
      else
        current_set = 0
      end
      main_dirty = true
    elseif (y>=3) and (y<=(2+#r_sets)) then
      local s_set = y-2
      if current_set == s_set then
        current_set = -1
      else
        current_set = s_set
      end
      main_dirty = true
    end
  elseif x>= main_r_column then
    if current_set == 0 then
      if y <= #recipe_types then
        r_type = recipe_types[y]
        current_set = -1
        main_dirty = true
      end
    end
  end
end

function handleMainKey(kb, char, code, player)
  if main_editing then
    if (char == 8) and (code == 14) then
      if current_name ~= "" then
        current_name = string.sub(current_name, 1, -2)
        main_dirty = true
      end
      return
    end
    if (char == 13) and (code == 28) then
      finishEditing(true)
      return
    end
    if char>0 then
      local ch = unicode.char(char)
      current_name = current_name..ch
      main_dirty = true
    end
  end
end

function handleMainEvent(ev, ...)
  if ev=="touch" then
    handleMainTouch(...)
  elseif ev=="key_down" then
    handleMainKey(...)
  end
end

while true do
  if main_dirty then
    displayMain()
    displayMainButtons()
    
    main_dirty = false
  end
  handleMainEvent(event.pull())
end
