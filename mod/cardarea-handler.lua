require("typist.mod.cardarea-ext")

local tu = require("typist.lib.tblutils")

local layout = require("typist.mod.layout")

-- returns whether or not the method did anything, if it returns false then we
-- should fallthrough to the next key handler branches
return function(area, key, held_keys)
  local target = layout.top_area_free_select_map[key]
    or (not area.__typist_top_area and layout.free_select_map[key])

  -- if no cards selected, select the target card
  if target and #area.highlighted == 0 then
    CardArea.__typist_toggle_card_by_index(area, target)
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

  -- deselect it no matter its position
  elseif key == layout.hand.deselect_all then
    if area.__typist_top_area then
      if G.__typist_TOP_AREA.active_selection then
        G.__typist_TOP_AREA.active_selection.ambient_tilt = 0.2
        G.__typist_TOP_AREA.active_selection:click()
      end
      G.__typist_TOP_AREA.active_selection = nil
    else
      CardArea.unhighlight_all(area)
    end

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

  -- use consumable or pick from a pack
  elseif not area.__typist_shop and (key == layout.proceed or key == layout.buy_and_use) then
    if (c.ability.consumeable and c:can_use_consumeable()) or area == G.pack_cards then
      G.FUNCS.use_card(e)
    end

  -- or
  elseif target then
    local src_pos = tu.list_index_of(area.cards, c)

    -- if it's also the target card, deselect it
    if src_pos == target then
      CardArea.__typist_toggle_card_by_index(area, target)

    -- if it's a shop or top area card change the selection with no need to deselect first
    elseif area.__typist_shop or area.__typist_top_area or area == G.pack_cards then
      CardArea.__typist_toggle_card_by_index(area, src_pos)
      CardArea.__typist_toggle_card_by_index(area, target)

    -- if shift is held, select the target card as well but only in booster hands
    elseif
      area == G.hand
      and (held_keys[layout.select_multiple_right] or held_keys[layout.select_multiple_left])
      and (
        G.STATE == G.STATES.TAROT_PACK
        or G.STATE == G.STATES.SPECTRAL_PACK
        or G.STATE == G.STATES.SMODS_BOOSTER_OPENED
      )
    then
      CardArea.__typist_toggle_card_by_index(area, target)

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
