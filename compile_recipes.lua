local component = require("component")
local shell = require("shell")
local event = require("event")
local unicode = require("unicode")
local serialization = require("serialization")
local filesystem = require("filesystem")

local recipe_folder = "/recipes"

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

local recipes = {}
for fname in filesystem.list(recipe_folder) do
  local fullname = recipe_folder.."/"..fname
  if string.sub(fname, -7) == ".recipe" then
    table.insert(recipes, string.sub(fullname, 1, -8))
  elseif string.sub(fname, -9) == ".compiled" then
    filesystem.remove(fullname)
  end
end

local recipe_broken
for i, recipe in ipairs(recipes) do
  recipe_broken = false
  print("Compiling "..recipe.."...")
  local f = io.open(recipe..".recipe", "r")
  local r = serialization.unserialize(f:read("*all"))
  f:close()
  local comp = {name=r.name, rtype=r.rtype, sets={}}
  for s, set in ipairs(r.sets) do
    comp.sets[s] = {}
    for i, item in ipairs(set) do
      local citem = {label=item.label,hash=item.hash}
      
      if item.hash ~= nil then
        local the_db, the_index
        for d, db in ipairs(dbs) do
          local index = db.db.indexOf(item.hash)
          if index>0 then
            the_db = db.db.address
            the_index = index
          end
        end
        
        if not the_db then
          recipe_broken = true
          print("  Error: Item '"..item.label.."' not found")
          break
        end
        
        citem.db = the_db
        citem.index = the_index
      end
      
      comp.sets[s][i] = citem
    end
    if recipe_broken then
      break
    end
  end
  
  if not recipe_broken then
    local w = io.open(recipe..".compiled", "w")
    w:write(serialization.serialize(comp))
    w:close()
  end
end
