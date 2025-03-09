require("typist.lib.cardarea-ext")

local tu = require("typist.lib.tblutils")

local cardarea_handler = require("typist.cardarea-handler")
local hand = require("typist.hand")
local layout = require("typist.layout")

local M = {}

local cheat_layer
M[G.STATES.SELECTING_HAND] = function(key, held_keys)
  if held_keys[layout.preview_deck] and not G.deck_preview then
    G.deck_preview = UIBox {
      definition = G.UIDEF.deck_preview(),
      config = { align = "tm", offset = { x = 0, y = -0.8 }, major = G.hand, bond = "Weak" },
    }
    G.E_MANAGER:add_event(Event {
      blocking = false,
      blockable = false,
      func = function()
        if not (tu.dig(G, { "CONTROLLER", "held_keys", layout.deck_preview })) then
          G.deck_preview:remove()
          G.deck_preview = nil
          return true
        end
      end,
    })
  end

  if held_keys[layout.cheat.leader_right] or held_keys[layout.cheat.leader_left] then
    cheat_layer(key)

  -- toggle card by position in hand
  elseif layout.free_select_map[key] then
    G.hand:toggle_card_by_index(layout.free_select_map[key])

  -- play hand
  elseif
    key == layout.proceed
    and G.buttons
    and G.buttons:get_UIE_by_ID("play_button").config.button
  then
    G.FUNCS.play_cards_from_highlighted()

  -- discard hand
  elseif
    key == layout.dismiss
    and G.buttons
    and G.buttons:get_UIE_by_ID("discard_button").config.button
  then
    G.FUNCS.discard_cards_from_highlighted()
  elseif key == layout.hand.invert_selection then
    hand.invert_selection()
  elseif key == layout.hand.deselect_all then
    G.hand:unhighlight_all()
    play_sound("cardSlide2", nil, 0.3)

  -- select the leftmost 5 cards
  elseif key == layout.hand.left5 then
    hand.left5()
  -- select the rightmost 5 cards
  elseif key == layout.hand.right5 then
    hand.right5()

  --
  elseif key == layout.hand.sort_by_rank then
    G.FUNCS.sort_hand_value(nil)
  elseif key == layout.hand.sort_by_suit then
    G.FUNCS.sort_hand_suit(nil)
  elseif key == layout.hand.reorder_by_enhancements then
    hand.reorder_by_enhancements()
  end
end

local best_hand
local fconf = fhotkey and { accept_flush = true, accept_str = true, accept_oak = true }
if fconf then
  print("FlushHotkeys detected, will use its `best_hand` implementation instead")
  best_hand = fhotkey.FUNCS.select_best_hand
else
  best_hand = hand.best_hand
end
cheat_layer = function(key)
  -- best hand overall
  if key == layout.cheat.best_hand then
    ---@diagnostic disable-next-line: redundant-parameter
    best_hand(G.hand.cards, fconf)
  -- best flush
  elseif key == layout.cheat.best_flush then
    hand.flush(hand.best_flush_suit())
  --[[ elseif key == layout.cheat.best_high_card then
    hand.best_high_card()
  elseif key == layout.cheat.worst_high_card then
    hand.worst_high_card() ]]
  -- select by suit
  elseif layout.cheat.suits_map[key] then
    hand.flush(layout.cheat.suits_map[key])
  -- select by rank
  elseif layout.cheat.ranks_map[key] then
    hand.by_rank(layout.cheat.ranks_map[key])
  -- because why not
  elseif
    key == layout.proceed
    and G.buttons
    and G.buttons:get_UIE_by_ID("play_button").config.button
  then
    G.FUNCS.play_cards_from_highlighted()
  elseif
    key == layout.dismiss
    and G.buttons
    and G.buttons:get_UIE_by_ID("discard_button").config.button
  then
    G.FUNCS.discard_cards_from_highlighted()
  end
end

M[G.STATES.ROUND_EVAL] = function(key)
  if key == layout.proceed then
    local cash_out_button
    for e, _ in pairs(G.ORPHANED_UIBOXES) do
      cash_out_button = e:get_UIE_by_ID("cash_out_button")
      if cash_out_button and cash_out_button.config.button then
        G.FUNCS.cash_out(cash_out_button)
        return
      end
    end
  end
end

-- pseudo-CardArea object to manipulate the shop as if it's one hand
local shop = setmetatable({}, { __index = { __typist_shop = true } })
M[G.STATES.SHOP] = function(key)
  -- reroll shop
  if
    key == layout.reroll
    and (G.GAME.dollars - G.GAME.current_round.reroll_cost >= G.GAME.bankrupt_at)
  then
    G.FUNCS.reroll_shop()

  -- switch to blind select
  elseif key == layout.proceed then
    G.FUNCS.toggle_shop()

  -- handle shop card actions
  elseif
    cardarea_handler(
      (function()
        shop.cards =
          tu.list_concat(G.shop_jokers.cards, G.shop_vouchers.cards, G.shop_booster.cards)
        shop.highlighted = tu.list_concat(
          G.shop_jokers.highlighted,
          G.shop_vouchers.highlighted,
          G.shop_booster.highlighted
        )
        return shop
      end)(),
      key
    )
  then -- do nothing
  end
end

M[G.STATES.BLIND_SELECT] = function(key)
  -- select blind
  if key == layout.proceed then
    local e =
      G.blind_select_opts[string.lower(G.GAME.blind_on_deck)]:get_UIE_by_ID("select_blind_button")

    if e.config.button == "pvp_ready_button" then G.FUNCS.pvp_ready_button(e) end

    if e.config.button == "mp_toggle_ready" then
      G.FUNCS.mp_toggle_ready(e)
    else
      G.FUNCS.select_blind(e)
    end

  -- skip blind
  elseif key == layout.skip then
    G.FUNCS.skip_blind(
      G.blind_select_opts[string.lower(G.GAME.blind_on_deck)]:get_UIE_by_ID("blind_extras")
    )

  -- reroll boss
  elseif key == layout.reroll then
    if
      (
        (G.GAME.used_vouchers["v_directors_cut"] and not G.GAME.round_resets.boss_rerolled)
        or G.GAME.used_vouchers["v_retcon"]
      ) and G.GAME.dollars - 10 >= G.GAME.bankrupt_at
    then
      G.FUNCS.reroll_boss()
    end
  else -- TODO: find and hover the current tag?
  end
end

-- close splash screen on any key press
M[G.STATES.SPLASH] = function()
  G:delete_run() -- this just deletes the run from global state, no save files affected
  G:main_menu()
end

M[G.STATES.MENU] = function(key)
  -- main menu
  if G.MAIN_MENU_UI and not G.SETTINGS.paused then
    -- the play button :)
    if key == layout.proceed then
      local the_play_button = G.MAIN_MENU_UI:get_UIE_by_ID("main_menu_play")
      if the_play_button then
        G.FUNCS.setup_run(the_play_button)
      else
        local mp_start = G.MAIN_MENU_UI:get_UIE_by_ID("lobby_menu_start")
        if mp_start then G.FUNCS.lobby_start_game(mp_start) end
      end
    end

  -- if a playable deck is in view
  elseif tu.dig(G.GAME, { "viewed_back", "effect", "center", "unlocked" }) then
    -- start a new run with it
    if key == layout.proceed then G.FUNCS.start_setup_run { config = { id = {} } } end

  -- if an exitable menu is visible
  elseif G.OVERLAY_MENU and not G.OVERLAY_MENU.config.no_esc then
    -- close it
    if key == layout.escape or key == layout.dismiss then G.FUNCS:exit_overlay_menu() end

  -- game over screen
  elseif G.OVERLAY_MENU and (G.GAME.won or G.STATE == G.STATES.GAME_OVER) then
    -- go to deck selection
    if key == layout.proceed then
      local new_run_button = G.OVERLAY_MENU:get_UIE_by_ID("from_game_over")
        or G.OVERLAY_MENU:get_UIE_by_ID("from_game_won")
      if new_run_button then G.FUNCS.notify_then_setup_run(new_run_button) end
    -- go to main menu
    elseif key == layout.escape then
      G.FUNCS.go_to_menu()
    -- start endless mode
    elseif key == layout.enter then
      if G.OVERLAY_MENU:get_UIE_by_ID("from_game_won") then
        G.FUNCS:exit_overlay_menu()
      elseif G.FUNCS.zen_restart_ante then
        G.FUNCS.zen_restart_ante(G.OVERLAY_MENU:get_UIE_by_ID("from_game_over"))
      end
    end
  end
end

local pack_event = { config = {} }
M[G.STATES.STANDARD_PACK] = function(key)
  if key == layout.dismiss then
    if G.FUNCS.can_skip_booster(pack_event) or pack_event.config.button then
      G.FUNCS.skip_booster(pack_event)
    end
  else
    cardarea_handler(G.pack_cards, key)
  end
end
M[G.STATES.PLANET_PACK] = M[G.STATES.STANDARD_PACK]
M[G.STATES.SPECTRAL_PACK] = M[G.STATES.STANDARD_PACK]
M[G.STATES.BUFFOON_PACK] = M[G.STATES.STANDARD_PACK]
M[G.STATES.TAROT_PACK] = M[G.STATES.STANDARD_PACK]
if G.STATES.SMODS_BOOSTER_OPENED then
  M[G.STATES.SMODS_BOOSTER_OPENED] = M[G.STATES.STANDARD_PACK]
end

return M
