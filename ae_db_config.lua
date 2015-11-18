local component = require("component")
local shell = require("shell")
local event = require("event")
local unicode = require("unicode")

local gpu = component.gpu

local bg_default = 0
local bg_button = 0xFF0000
local bg_button_hl = 0x00CC00

local me_max_columns = 3

local dirty = true
local query

gpu.setBackground(bg_default)

local me
if component.isAvailable("me_controller") then
  me = component.me_controller
elseif component.isAvailable("me_interface") then
  me = component.me_interface
else
  print("No ME inventory access (controller or full block interface) available.")
  os.exit()
end

local me_dirty = true
local me_items
local me_display
local me_cols, me_col_width, me_col_map
local me_result

local dbs = {}
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

if #dbs == 0 then
  print("No databases found.")
  os.exit()
end

print("Databases:")
for i = 1,#dbs do
  print(" "..i..") "..dbs[i].db.address.." ("..dbs[i].size..")")
end

print("Please select the database to change.")
local the_db
while not the_db do
  local result = tonumber(io.read())
  if result and result > 0 and result <= #dbs then
    the_db = dbs[result]
  else
    print("Invalid input, please try again.")
  end
end

local sw, sh = gpu.getResolution()

local cols = math.ceil(the_db.size/(sh-2))
local col_width = math.floor((sw-((cols-1)*2))/cols)

local col_map
local selected

function refreshMe()
  me_items = me.getItemsInNetwork()
end

refreshMe()

function initColmap()
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

function clearScreen()
  gpu.fill(1, 1, sw, sh, ' ')
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

function drawDelete()
  gpu.set(sw-16, sh, " Delete ")
end

function drawDeleteAll()
  gpu.set(2, sh, " Delete All ")
end

function drawRefresh()
  gpu.set(sw-19, sh, " Refresh ")
end

function drawCancel()
  gpu.set(sw-8, sh, " Cancel ")
end

function initMeColmap()
  me_col_map = {}
  for i = 1,me_cols do
    me_col_map[i] = {l=1+(i-1)*(me_col_width+2)}
    me_col_map[i].r = me_col_map[i].l + me_col_width - 1
  end
end

function initMeDisplay()
  me_display = {}
  if query then
    query = string.lower(query)
  end
  for i, item in ipairs(me_items) do
    if (not query) or string.find(string.lower(item.label), query) then
      table.insert(me_display, item)
    end
  end
  table.sort(me_display, function(a,b) return a.label < b.label end)
  me_cols = math.ceil(#me_display/(sh-2))
  if me_cols > me_max_columns then
    me_cols = me_max_columns
  end
  me_col_width = math.floor((sw-((me_cols-1)*2))/me_cols)
end

function displayMe()
  clearScreen()
  initMeColmap()
  local current_col = 1
  local current_row = 1
  
  for i = 1,#me_display do
    local s = ""
    if i<10 then
      s = "00"
    elseif i<100 then
      s = "0"
    end
    s = s..i.." "..me_display[i].label
    gpu.set(col_map[current_col].l, current_row, string.sub(s, 1, me_col_width))
    me_col_map[current_col][current_row] = i
    
    current_row = current_row + 1
    if current_row > (sh-2) then
      current_row = 1
      current_col = current_col + 1
      if current_col > me_cols then
        break
      end
    end
  end
end

function displayMeButtons()
  gpu.fill(1, sh, sw, sh, ' ')
  if query then
    gpu.set(2, sh, "Query: "..query)
  end
  gpu.setBackground(bg_button)
  drawRefresh()
  drawCancel()
  gpu.setBackground(bg_default)
end

function handleMeButtonTouch(x)
  if (x>=sw-19) and (x<=sw-10) then
    blinkButton(drawRefresh)
    refreshMe()
    me_dirty = true
  end
  if (x>=sw-8) and (x<=sw-1) then
    blinkButton(drawCancel)
    me_result = -1
  end
  gpu.setBackground(bg_default)
end

function handleMeTouch(screen, x, y, button, player)
  if button==1 then
    query = nil
    dirty = true
  else
    if y == sh then
      handleMeButtonTouch(x)
      return
    end
    for c = 1, me_cols do
      if (x >= me_col_map[c].l) and (x <= me_col_map[c].r) then
        local item = me_col_map[c][y]
        if item then
          me_result = me_display[item]
          break
        end
      end
    end
  end
end

function handleMeKey(kb, char, code, player)
  if (char == 8) and (code == 14) then
    if query then
      query = string.sub(query, 1, -2)
      if string.len(query) == 0 then
        query = nil
      end
      me_dirty = true
    end
  end
  if (char == 0) and (code == 211) then
    if query then
      query = string.sub(query, 2, -1)
      if string.len(query) == 0 then
        query = nil
      end
      me_dirty = true
    end
  end
  if char>0 then
    local ch = unicode.char(char)
    if not query then
      query = ""
    end
    query = query..ch
    me_dirty = true
  end
end

function handleMeEvent(ev, ...)
  if ev=="touch" then
    handleMeTouch(...)
  elseif ev=="key_down" then
    handleMeKey(...)
  end
end

function getNewitem()
  me_result = nil
  while true do
    if me_dirty then
      initMeDisplay()
      displayMe()
      displayMeButtons()
    end
    handleMeEvent(event.pull())
    if me_result then
      if me_result == -1 then
        return nil
      else
        return me_result
      end
    end
  end
end

function displayDbButtons()
  gpu.fill(1, sh, sw, sh, ' ')
  if selected then
    gpu.set(1, sh, string.sub(the_db.cache[selected], 1, sw-18))
    gpu.setBackground(bg_button)
    drawDelete()
  else
    gpu.setBackground(bg_button)
    drawDeleteAll()
  end
  drawQuit()
  gpu.setBackground(bg_default)
end

function handleDbButtonTouch(x, button)
	if selected then
	  if x <= sw-18 then
	    selected = nil
	    displayDbButtons()
	    return
	  elseif (x >= sw-16) and (x <= sw-8) then
	    blinkButton(drawDelete)
	    the_db.db.clear(selected)
	    selected = nil
	    dirty = true
	  end 
	else
	  if (x>=2) and (x<=13) then
      blinkButton(drawDeleteAll)
	    for i = 1,the_db.size do
	      the_db.db.clear(i)
	    end
	    dirty = true
	  end
	end
	if (x>=sw-6) and (x<=sw-1) then
	  blinkButton(drawQuit)
	  gpu.setBackground(bg_default)
	  clearScreen()
	  os.exit()
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
        if button==1 then
          selected = item
          displayDbButtons()
        else
          local newitem = getNewitem()
          if newitem then
            me.store(newitem, the_db.db.address, item, 1)
          end
          dirty = true
        end
        break
      end
    end
  end
end

while true do
  if dirty then
    buildCache()
    displayDb()
    displayDbButtons()
    
    dirty = false
  end
  local ev, _, x, y, button, player = event.pull("touch")
  handleDbTouch(x,y,button)
end
