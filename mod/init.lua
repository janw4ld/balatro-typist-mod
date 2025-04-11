local tu = require("typist.lib.tblutils")

local cardarea_handler = require("typist.mod.cardarea-handler")
local layout = require("typist.mod.layout")

print(layout.tostring())

G.SETTINGS.__typist = G.SETTINGS.__typist or {}

if fhotkey then
  print("FlushHotkeys detected, unhooking it from the keyboard :)")
  Controller.key_press_update = assert(fhotkey.FUNCS.keyupdate_ref)
end

-- pseudo-CardArea object to manipulate jokers and consumable as if they're one hand
local top_area = setmetatable({}, { __index = { __typist_top_area = true } })
return function(Controller, key) -- order defines precedence
  -- if text input is active, skip over keybind handlers
  if G.CONTROLLER and G.CONTROLLER.text_input_hook then -- do nothing
  elseif layout.global_map[key] then
    layout.global_map[key]()
  elseif G.SETTINGS.paused then
    require("typist.mod.state-handlers")[G.STATES.MENU](key)
  elseif
    (function()
      for leader, area in pairs(layout.cardarea_map) do
        if Controller.held_keys[leader] then
          local a = area()
          return a and cardarea_handler(a, key, Controller.held_keys)
        end
      end
    end)()
  then -- nothing :)
  elseif
    (function()
      if layout.free_select_two_electric_boogaloo[key] then
        top_area.cards = tu.list_concat(G.jokers.cards, G.consumeables.cards)
        top_area.highlighted = tu.list_concat(G.jokers.highlighted, G.consumeables.highlighted)
        return cardarea_handler(top_area, key, Controller.held_keys)
      end
    end)()
  then -- nothing here too
  elseif require("typist.mod.state-handlers")[G.STATE] and G.GAME.STOP_USE == 0 then
    require("typist.mod.state-handlers")[G.STATE](key, Controller.held_keys)
  end

  if Controller.held_keys["d"] and key == "x" then debug.debug() end
end
