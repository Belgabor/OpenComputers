package.loaded.buttons = nil

local b = require("buttons")

local page = b.makePage(0x000000, 0xFFFFFF, 0x0000FF, 0x00FF00)
page:addButton("test", "Test", 10, 10, 20, 3)
page:draw()