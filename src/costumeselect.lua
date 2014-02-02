local anim8 = require 'vendor/anim8'
local background = require 'selectbackground'
local character = require 'character'
local controls = require('inputcontroller').get()
local fonts = require 'fonts'
local Gamestate = require 'vendor/gamestate'
local Level = require 'level'
local Player = require 'player'
local sound = require 'vendor/TEsound'
local VerticalParticles = require "verticalparticles"
local window = require 'window'

local state = Gamestate.new()

local function nonzeroMod(a,b)
    local m = a%b
    if m==0 then
        return b
    else
        return m
    end
end

local function __NULL__() end

function state:init()

  VerticalParticles.init()
  background.init()

  self.side = 0 -- 0 for left, 1 for right
  self.level = 0 -- 0 through 3 for characters
  self.page = 'characterPage'
  self.rowLength = 10

  self.chartext = ""
  self.menutext = ""
  self.costtext = ""
  self.backtext = ""
  
end

function state:enter(previous, target)

  self.selectionBox = love.graphics.newImage('images/menu/selection.png')
  self.page = 'characterPage'
  self.characters = {}
  self.costumes = {}

  self.character_selections = {}
  self.character_selections[0] = {} -- left
  self.character_selections[1] = {} -- right
  self.character_selections[0][0] = 'jeff'
  self.character_selections[0][1] = 'britta'
  self.character_selections[0][2] = 'abed'
  self.character_selections[0][3] = 'annie'
  self.character_selections[1][0] = 'troy'
  self.character_selections[1][1] = 'shirley'
  self.character_selections[1][2] = 'pierce'
  
  -- TODO
  -- insufficient friends

  fonts.set('big')
  self.previous = previous
  self.target = target
  background.enter()
  background.setSelected(self.side, self.level)

  self.chartext = "PRESS " .. controls:getKey('JUMP') .. " TO CHOOSE CHARACTER"
  self.menutext = "PRESS " .. controls:getKey('START') .. " TO RETURN TO MENU"
  self.costext = "PRESS " .. controls:getKey('JUMP') .. " TO CHOOSE COSTUME" 
  self.backtext = "PRESS " .. controls:getKey('ATTACK') .. " TO CHANGE CHARACTER"

end

function state:character()
  local name = self.character_selections[self.side][self.level]

  if not name then
    return nil
  end

  return self:loadCharacter(name)
end

function state:loadCharacter(name)
  if not self.characters[name] then
    self.characters[name] = character.load(name)
    self.characters[name].rows = 1
    self.characters[name].columns = 1
    self.characters[name].count = 1
    self.characters[name].costume = 'base'
  end

  return self.characters[name]
end

function state:keypressed( button )
  if button == "START" then
    Gamestate.switch(self.previous)
    return
  end

  -- If any input is received while sliding, speed up
  if background.slideIn or background.slideOut then
    background.speed = 10
    return
  end
  
  if self.page == 'characterPage' then
    self:characterKeypressed(button)
  elseif self.page == 'costumePage' then
    self:costumeKeypressed(button)
  end
end
    
function state:characterKeypressed(button)
  local level = self.level
  local options = 4

  if button == 'LEFT' or button == 'RIGHT' then
    self.side = (self.side - 1) % 2
    sound.playSfx('click')
  elseif button == 'UP' then
    level = (self.level - 1) % options
    sound.playSfx('click')
  elseif button == 'DOWN' then
    level = (self.level + 1) % options
    sound.playSfx('click')
  end
  self.level = level

  if ( button == 'JUMP' ) and self.level == 3 and self.side == 1 then
    -- can't select insufficient friends
    sound.playSfx('unlocked')
  elseif button == 'JUMP' then 
    sound.playSfx('confirm')
    local name = self.character_selections[self.side][self.level]
    self.owsprite = love.graphics.newImage('images/characters/'..name..'/overworld.png')
    self.g = anim8.newGrid(36, 36, self.owsprite:getWidth(), self.owsprite:getHeight())
    local c = self.characters[name]
    self.number = #c.costumes
    self.columnLength = math.ceil(self.number / self.rowLength)
    self.lastRowLength = nonzeroMod(self.number, self.rowLength)
    self.page = 'costumePage'
  end

  background.setSelected(self.side, self.level)
end

function state:costumeKeypressed(button)

  local name = self.character_selections[self.side][self.level]
  local row = self.characters[name].rows
  local column = self.characters[name].columns

  if button == "LEFT" then
    if row == self.columnLength then
      column = nonzeroMod(column - 1 , self.lastRowLength)
    else
      column = nonzeroMod(column - 1 , self.rowLength)
    end
    sound.playSfx('click')

  elseif button == "RIGHT" then
    if row == self.columnLength then
      column = nonzeroMod(column + 1 , self.lastRowLength)
    else
      column = nonzeroMod(column + 1 , self.rowLength)
    end
    sound.playSfx('click')

  elseif button == "DOWN" then
    if (row == self.columnLength - 1 and column > self.lastRowLength)  then
      row = 1
    else
      row = nonzeroMod(row + 1, self.columnLength)
    end
    sound.playSfx('click')

  elseif button == "UP" then
    if (row == 1 and column > self.lastRowLength) then
      row = self.columnLength - 1
	else
      row = nonzeroMod(row - 1, self.columnLength)
    end
    sound.playSfx('click')
  end
    
  self.characters[name].rows = row
  self.characters[name].columns = column
  self.characters[name].count = (row - 1)*self.rowLength + column
	
  if button == "JUMP" then
    sound.playSfx('confirm')
    if self:character() then
      self:changeCostume()
    end
	
  elseif button == "ATTACK" then
    sound.playSfx('click')
    self.page = 'characterPage'
  end
  


end

function state:changeCostume()
  local player = Player.factory() -- expects existing player object
  local name = self.character_selections[self.side][self.level]
  local c = self:loadCharacter(name)
  local sheet = c.costumes[self.characters[name].count].sheet
  
  character.pick(name, sheet)
  player.character = character.current()
  
  Gamestate.switch(self.target)
end

function state:leave()
  fonts.reset()
  background.leave()
  VerticalParticles.leave()
  -- need more stuff deleted here

  self.character_selections = nil
  self.characters = nil
  self.costumes = nil
  self.previous = nil -- seriously?
  self.music = nil
end

function state:update(dt)
  background.update(dt)
  VerticalParticles.update(dt)
end

function state:drawCharacter(name, x, y, offset)
  local char = self:loadCharacter(name)
  local key = name .. 'base'

  if not self.costumes[key] then
    self.costumes[key] = character.getCostumeImage(name, 'base')
  end

  local image = self.costumes[key]

  if not char.mask then
    char.mask = love.graphics.newQuad(0, char.offset, 48, 35, image:getWidth(), image:getHeight())
  end

  if offset then
    love.graphics.drawq(image, char.mask, x, y, 0, -1, 1)
  else
    love.graphics.drawq(image, char.mask, x, y)
  end
end


function state:draw()

  if self.page == 'characterPage' then
    background.draw()
  
  -- Only draw the details on the screen when the background is up
    if not background.slideIn then
    
      love.graphics.setColor(255, 255, 255, 255)
      local name = ""

      if self:character() then
        name = self:character().costumes[1].name
      end

      love.graphics.printf(self.chartext, 0, window.height - 65, window.width, 'center')
      love.graphics.printf(self.menutext, 0, window.height - 45, window.width, 'center')

      love.graphics.printf(name, 0, 23, window.width, 'center')

      local x, y = background.getPosition(1, 3)
      love.graphics.setColor(255, 255, 255, 200)
      love.graphics.print("INSUFFICIENT", x, y + 5, 0, 0.5, 0.5, 12, -6)
      love.graphics.print(  "FRIENDS"   , x, y + 5, 0, 0.5, 0.5, -12, -32)
      love.graphics.setColor(255, 255, 255, 255)
    end

    for i=0,1,1 do
      for j=0,3,1 do
        local character_name = self.character_selections[i][j]
        local x, y = background.getPosition(i, j)
        if character_name then
          self:drawCharacter(character_name, x, y, i == 0)
        end
      end
    end
  end
    
  if self.page == 'costumePage' then
  
    local name = self.character_selections[self.side][self.level]
    local c = self.characters[name]

    VerticalParticles.draw()
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.printf(self.costext, 0, window.height - 75, window.width, 'center')
    love.graphics.printf(self.backtext, 0, window.height - 55, window.width, 'center')

	local spacingX = 40
	local spacingY = 40

    local x = (window.width - self.rowLength*spacingX)/2 - 40
	local y = 10

	local i = 1
	local j = 1

    local row = self.characters[name].rows
    local column = self.characters[name].columns

	for k = 1, #c.costumes do
      self.overworld = anim8.newAnimation('once', self.g(c.costumes[k].ow, 1), 1)
      self.overworld:draw(self.owsprite, x + spacingX*i, y + spacingY*j)
	  if i < self.rowLength then
	    i = i + 1
      else
        i = 1
		j = j + 1
	  end
    end
	love.graphics.draw(self.selectionBox, x - 2 + spacingX*column, y  + spacingY*row)
    love.graphics.printf(c.costumes[self.characters[name].count].name, 0, 23, window.width, 'center')
  end
  
end

return state
