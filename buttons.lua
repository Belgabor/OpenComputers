local component = require("component")
local gpu = component.gpu


local buttons = {}

function makeBase()
  base = {}
  
  function base:getParameter(type)
      if self[type] ~= nil then
        return self[type]
      else
        if self.parent == nil then
          return nil
        else
          return self.parent[type]
        end
      end
  end
  
  function base:init(i)
    for k, v in pairs (i) do
      self[k] = v
    end
  end
  
  function base:getHilightColor()
    return self:getParameter("hilight_color")
  end
  
  function base:setHilightColor(color)
    self.hilight_color = color
  end

  function base:getHilightFontColor()
    return self:getParameter("hilight_font_color")
  end
  
  function base:setHilightFontColor(color)
    self.hilight_font_color = color
  end

  function base:getFontColor()
    return self:getParameter("font_color")
  end
  
  function base:setFontColor(color)
    self.font_color = color
  end

  function base:getButtonColor()
    return self:getParameter("button_color")
  end
  
  function base:setButtonColor(color)
    self.button_color = color
  end

  function base:getScreenColor()
    return self:getParameter("screen_color")
  end
  
  function base:setScreenColor(color)
    self.screen_color = color
  end

  return base
end

function int_makeButton(parent, tag, label, x, y, width, height, callback, parameter)
  nb = makeBase()
  nb.tag = tag
  nb.label = label
  nb.x = x
  nb.y = y
  nb.width = width
  nb.height = height
  nb.callback = callback
  nb.parameter = parameter
  nb.parent = parent
  nb.toggled = false
  nb.blink_duration = 1
  nb.features = {}
  
  function nb:addFeature(feature)
    self.features[feature] = true
  end
  
  function nb:authorize(player)
    if self.authorized == nil then
      self.authorized = {}
    end
    self.authorized[player] = true
  end
  
  function nb:check(x, y, player, noauto)
    if (player ~= nil) and (self.authorized ~= nil) then
      if not self.authorized[player] then
        return false
      end
    end
    if (x < self.x) or (x > self.x + self.width - 1) or (y < self.y) or (self.y > self.y + self.height - 1) then
      return false
    end
    if not noauto then
      if self.features["toggle"] then
        self.toggled = not self.toggled
        self:draw(false)
      end
      if self.features["blink"] then
        self:draw(true)
      end
      if self.callback ~= nil then
        self.callback(self.parameter, self.toggled, self.tag, self)
      end
      if self.features["blink"] then
        os.sleep(self.blink_duration)
        self:draw(false)
      end
    end
    
    return true
  end

  function nb:draw(hilight)
    local oldbg, oldgbt = gpu.getBackground()
    local oldfg, oldfgt = gpu.getForeground()

    if hilight or self.toggled then
      gpu.setBackground(self:getHilightColor(), false)
      gpu.setForeground(self:getHilightFontColor(), false)
    else
      if self.features['hidden'] then
        gpu.setBackground(self:getScreenColor(), false)
        gpu.setForeground(self:getScreenColor(), false)
      else
        gpu.setBackground(self:getButtonColor(), false)
        gpu.setForeground(self:getFontColor(), false)
      end
    end
    
    gpu.fill(self.x, self.y, self.width, self.height, ' ')
    gpu.set(self.x + math.floor((self.width - string.len(self.label))/2), self.y + math.floor(self.height/2), self.label)

    gpu.setBackground(oldbg, oldgbt)
    gpu.setForeground(oldfg, oldfgt)
  end
  
  function nb:setFeatures(features)
    if features == nil then
      self.features = {}
    else
      self.features = features
    end
  end

  return nb
end

function int_makePage(parent)
  np = makeBase()
  np.parent = parent
  np.buttons = {}

  function np:addButton(tag, label, x, y, width, height, callback, parameter)
    nb = int_makeButton(self,tag,label,x,y,width,height,callback,parameter)

    self.buttons[tag] = nb

    return nb
  end
  
  function np:check(x, y, player, noauto)
    for t,b in pairs(self.buttons) do
      if b:check(x, y, player, noauto) then
        return b
      end
    end
    return nil  
  end

  function np:draw(noclear)
    local oldbg, oldbgt = gpu.getBackground()

    if not noclear then
      local w,h = gpu.getResolution()
      gpu.setBackground(self:getScreenColor(), false)
      gpu.fill(1,1,w,h," ")
    end

    for t,b in pairs(self.buttons) do
      b:draw(false)
    end

    gpu.setBackground(oldbg, oldbgt)
  end
  
  function np:registerButton(button)
    self.buttons[button.tag] = button
  end  

  return np
end

function buttons.makePage(screen_color, font_color, button_color, hilight_color)
  np = int_makePage(nil)
  np.screen_color = screen_color
  np.font_color = font_color
  np.button_color = button_color
  np.hilight_color = hilight_color
  np.hilight_font_color = font_color

  return np
end

function buttons.makePaginator(screen_color, font_color, button_color, hilight_color)
  npg = makeBase()
  npg.screen_color = screen_color
  npg.font_color = font_color
  npg.button_color = button_color
  npg.hilight_color = hilight_color
  npg.hilight_font_color = font_color
  npg.pages = {}
  npg.page = 1
  
  npg.pages[1] = int_makePage(npg)
  
  function npg:draw(noclear)
    self.pages[self.page]:draw(noclear)
  end

  return npg
end

return buttons