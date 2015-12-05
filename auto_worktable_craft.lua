local component = require("component")
--local shell = require("shell")
--local event = require("event")
local unicode = require("unicode")
local serialization = require("serialization")
local filesystem = require("filesystem")
--local colors = require("colors")
local sides = require("sides")

local wt = component.Worktable

local recipe_folder = "/recipes"

local transposer_input = sides.east
local transposer_worktable = sides.south
local transposer_output = sides.west

local sleep_check_input = 5

-- ---

local transposer
if (component.isAvailable("transposer")) then
  transposer = component.transposer
else
  transposer = component.inventory_controller
end

local db = component.database

local recipes = {}
for fname in filesystem.list(recipe_folder) do
  local fullname = recipe_folder.."/"..fname
  if string.sub(fname, -7) == ".recipe" then
    print("Loading "..fname.."...")
    local f = io.open(fullname, "r")
    local r = serialization.unserialize(f:read("*all"))
    f:close()
    
    if r["rtype"] == "worktable" then
      local requirements = {}
      for i, item in ipairs(r.sets[1]) do
        if item.hash ~= nil then
          if requirements[item.hash] == nil then
            requirements[item.hash] = 0
          end
          requirements[item.hash] = requirements[item.hash] + 1
        end
      end
      r["requirements"] = requirements
      table.insert(recipes, r)
    end
  end
end

local input, input_hash

function refreshInput()
	input = {}
	input_hash = {}
	
	for i = 1,transposer.getInventorySize(transposer_input) do
	  local item = transposer.getStackInSlot(transposer_input, i)
	  if item then
	    if transposer.store(transposer_input, i, db.address, 1) then
        local hash = db.computeHash(1)
        input[i] = {item=item, hash=hash}
        if input_hash[hash] == nil then
          input_hash[hash] = {slots={i}, count=item["size"]}
        else
          table.insert(input_hash[hash]["slots"], i)
          input_hash[hash]["count"] = input_hash[hash]["count"] + item["size"]  
        end
	    else
	      print("Failed to store item: "..i)
	    end
	  end
	end
end

function checkRecipe(recipe)
  for hash, count in pairs(recipe.requirements) do
    if input_hash[hash] == nil then
      return false
    end
    if count > input_hash[hash].count then
      return false
    end
  end
  return true
end

function getSlot(hash)
	for s, slot in ipairs(input_hash[hash].slots) do
    if transposer.getSlotStackSize(transposer_input, slot) > 0 then
      return slot
    end
	end
end

function craftRecipe(recipe)
  for i, item in ipairs(recipe.sets[1]) do
    if item.hash ~= nil then
      local slot = getSlot(item.hash)
      input_hash[item.hash].count = input_hash[item.hash].count - 1
      transposer.transferItem(transposer_input, transposer_worktable, 1, slot, i)
    end
  end
  wt.trigger()
  transposer.transferItem(transposer_worktable, transposer_output, 64, 14)
end

function craft()
  for r, recipe in ipairs(recipes) do
    while checkRecipe(recipe) do
      print("Matched "..recipe.name)
      craftRecipe(recipe)
    end
  end
end

while true do
  refreshInput()
  craft()
  os.sleep(sleep_check_input)
end
