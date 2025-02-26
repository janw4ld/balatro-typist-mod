require("typist.lib.cardarea-ext")

local tu = require("typist.lib.tblutils")

local layout = require("typist.layout")

-- returns whether or not the method did anything, if it returns false then we
-- should fallthrough to the next key handler branches
return function(area, key, held_keys)
  local target = layout.free_select_map[key]

  -- if no cards selected, select the target card
  if target and #area.highlighted == 0 then
    CardArea.toggle_card_by_index(area, target)
    return true -- otherwise out of bounds will falltrough to other card areas and confuse players
  end

  if not (#area.highlighted == 1 or area == G.hand) then return false end
  local c = area.highlighted[1]
  local e = { config = { ref_table = c }, UIBox = { states = {} } }

  -- sell the card if possible
  if key == layout.dismiss then
    if c:can_sell_card() then
      c:sell_card()
      for _, j in ipairs(G.jokers.cards) do
        j:calculate_joker { selling_card = true }
      end
    end

  -- use consumable or pick from a pack
  elseif
    (key == layout.proceed or key == layout.buy_and_use)
    and (area == G.pack_cards or (c.ability.consumeable and c:can_use_consumeable()))
  then
    G.FUNCS.use_card(e)

  -- deselect it no matter its position
  elseif key == layout.hand.deselect_all then
    c:click()

  -- use voucher or pack
  elseif
    area.__typist_shop
    and (key == layout.buy or key == layout.buy_and_use)
    and (c.ability.set == "Voucher" or c.ability.set == "Booster")
    and (G.FUNCS.can_redeem(e) or e.config.button or G.FUNCS.can_open(e) or e.config.button)
  then
    G.FUNCS.use_card(e)

  -- buy consumable or joker
  elseif area.__typist_shop and key == layout.buy and (G.FUNCS.can_buy(e) or e.config.button) then
    e.config.id = nil
    G.FUNCS.buy_from_shop(e)

  -- buy and use consumable
  elseif
    area.__typist_shop
    and key == layout.buy_and_use
    and c.ability.consumeable
    and (G.FUNCS.can_buy_and_use(e) or e.config.button)
  then
    e.config.id = "buy_and_use"
    G.FUNCS.buy_from_shop(e)

  -- or
  elseif target then
    local src_pos = tu.list_index_of(area.cards, c)

    -- if it's also the target card, deselect it
    if src_pos == target then
      CardArea.toggle_card_by_index(area, target)

    -- if it's a shop card change the selection with no need to deselect first
    elseif area.__typist_shop or area == G.pack_cards then
      CardArea.toggle_card_by_index(area, src_pos)
      CardArea.toggle_card_by_index(area, target)

    -- if ctrl is held, select the target card as well but only in booster hands
    elseif
      area == G.hand
      and held_keys[layout.select_multiple]
      and (G.STATE == G.STATES.TAROT_PACK or G.STATE == G.STATES.SPECTRAL_PACK)
    then
      CardArea.toggle_card_by_index(area, target)

    -- otherwise, move the highligted card to the target position
    else
      target = target > #area.cards and #area.cards or target
      tu.list_move_item(area.cards, src_pos, target)
      play_sound("cardFan2", nil, 0.5)
    end
  else
    return false
  end

  return true
end
