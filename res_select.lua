local component = require("component")
local event = require("event")

local gpu = component.gpu
local screen = component.screen

local sw, sh = gpu.getResolution()
local wmin = 10
local hmin = 10
local wmax, hmax = gpu.maxResolution()

local run = true
local old_mode = screen.isTouchModeInverted()
screen.setTouchModeInverted(true)

function clearScreen()
  gpu.fill(1, 1, sw, sh, ' ')
end

function draw()
	clearScreen()
	gpu.fill(1, 1, sw, 1, 'X')
  gpu.fill(1, sh, sw, 1, 'X')
  gpu.fill(1, 2, 1, sh-2, 'X')
  gpu.fill(sw, 2, sw, sh-2, 'X')
  local s = sw.."x"..sh
  gpu.set((sw-string.len(s))/2, sh/2, s)
end

function handleTouch(x,y,button)
  if (button == 1) then
    run = false
    return
  end
	if x < (sw/3) then
    sw = sw-1
	end
  if x > (2*sw/3) then
    sw = sw+1
  end
  if y < (sh/3) then
    sh = sh-1
  end
  if y > (2*sh/3) then
    sh = sh+1
  end
  if sw < wmin then
    sw = wmin
  end
  if sw > wmax then
  	sw = wmax
  end
  if sh < hmin then
  	sh = hmin
  end
  if sh > hmax then
  	sh = hmax
  end
  gpu.setResolution(sw, sh)
end

while run do
  draw()
  local ev, _, x, y, button, player = event.pull("touch")
  handleTouch(x,y,button)  
end

clearScreen()
print(sw.."x"..sh)
screen.setTouchModeInverted(old_mode)
