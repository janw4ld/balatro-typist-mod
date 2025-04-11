G.SETTINGS.__typist = G.SETTINGS.__typist or {}
G.SETTINGS.__typist.card_hover_duration = G.SETTINGS.__typist.card_hover_duration or 10

local M = {}

local last_hover = {}
local no_op = function()
  return true
end
function CardArea:__typist_toggle_card_by_index(index)
  local target = self.cards[index]
  if not target then
    play_sound("cancel")
    return
  end

  if last_hover.e and not last_hover.e.complete then
    last_hover.e.complete = true
    last_hover.card:stop_hover()
    last_hover.e.func = no_op
  end

  target:click()

  target:hover()
  if G.E_MANAGER then
    last_hover.card = target

    -- hover duration 0 means infinite hover
    if G.SETTINGS.__typist.card_hover_duration <= 0 and target.highlighted then return end

    last_hover.e = Event {
      -- while selecting a card, hover it for a longer duration than deselection
      delay = target.highlighted and G.SETTINGS.__typist.card_hover_duration or 0.2, -- seconds
      timer = "REAL",
      trigger = "after",
      blockable = false,
      blocking = false,
      func = function()
        target:stop_hover()
        return true
      end,
    }
    G.E_MANAGER:add_event(last_hover.e)
  end

  return target.highlighted and target
end
M.toggle_card_by_index = CardArea.__typist_toggle_card_by_index

return M
