local tu = require("typist.lib.tblutils")

local hu = require("typist.handutils")

local M = {}

M.left5 = function()
  local cards = {}
  for i, card in ipairs(G.hand.cards) do
    if i > 5 then break end
    table.insert(cards, card)
  end
  hu.highlight_hand(cards)
end

M.right5 = function()
  local cards = {}
  for i, card in tu.reversed_ipairs(G.hand.cards) do
    if i > 5 then break end
    table.insert(cards, card)
  end
  hu.highlight_hand(cards)
end

-- given a hand rank (jack=11, queen=12, king=13, ace=14)
-- select all cards in your hand with that rank
M.by_rank = function(rank)
  local cards = {}
  for _, card in pairs(G.hand.cards) do
    if hu.get_visible_rank(card) == rank and not tu.contains(G.hand.highlighted, card) then
      table.insert(cards, card)
    end
  end
  hu.highlight_hand(cards)
end

M.invert_selection = function()
  local unselected = tu.list_diff(G.hand.cards, G.hand.highlighted)
  table.sort(unselected, function(x, y)
    local action = hu.Action.select_discard_if_possible()
    return hu.card_importance(x, action) < hu.card_importance(y, action)
  end)
  hu.highlight_hand(tu.list_take(unselected, 5))
end

M.best_high_card = function()
  local best_card, _ = hu.high_card()
  hu.highlight_hand(hu.top_up_with_stones { best_card })
end
M.worst_high_card = function()
  local _, worst_card = hu.high_card()
  hu.highlight_hand(hu.top_up_with_stones { worst_card })
end

M.best_flush_suit = function()
  local best_score = -math.huge
  local best_suit

  local smeared_joker = next(find_joker("Smeared Joker"))
  local four_fingers = next(find_joker("Four Fingers"))

  local cards_by_suit = (
    smeared_joker
    and {
      Hearts = hu.select_cards_of_suit("Hearts", "Diamonds"),
      Clubs = hu.select_cards_of_suit("Spades", "Clubs"),
    }
  )
    or {
      Hearts = hu.select_cards_of_suit("Hearts"),
      Clubs = hu.select_cards_of_suit("Clubs"),
      Diamonds = hu.select_cards_of_suit("Diamonds"),
      Spades = hu.select_cards_of_suit("Spades"),
    }

  for suit, sorted_flush in pairs(cards_by_suit) do
    local base_score = 1000 * #sorted_flush
    local hands_to_check = {}

    if #sorted_flush >= 5 then table.insert(hands_to_check, tu.list_take(sorted_flush, 5)) end
    if four_fingers and #sorted_flush >= 4 then
      table.insert(hands_to_check, tu.list_take(sorted_flush, 4))
    end
    if #hands_to_check == 0 then
      table.insert(sorted_flush, { flipped = true })
      table.insert(hands_to_check, sorted_flush)
    end

    for _, hand in pairs(hands_to_check) do
      local score = base_score + hu.hand_importance(hand)
      if score > best_score then
        best_score = score
        best_suit = suit
      end
    end
  end

  return assert(best_suit, "there are no cards in your hand, you're so cooked")
end

M.flush = function(target_suit)
  local four_fingers = next(find_joker("Four Fingers"))
  local smeared_joker = next(find_joker("Smeared Joker"))

  local cards = {}

  if smeared_joker then
    if target_suit == "Spades" or target_suit == "Clubs" then
      cards = hu.select_cards_of_suit("Spades", "Clubs")
    end
    if target_suit == "Hearts" or target_suit == "Diamonds" then
      cards = hu.select_cards_of_suit("Hearts", "Diamonds")
    end
  else
    cards = hu.select_cards_of_suit(target_suit)
  end

  if #cards >= 5 then
    cards = tu.list_take(cards, 5)
  elseif four_fingers and #cards >= 4 then
    cards = tu.list_take(cards, 4)
  else
    cards = {}
    for _, card in tu.reversed_ipairs(G.hand.cards) do
      local suit = hu.get_visible_suit(card)
      if not (suit == target_suit or suit == hu.SuitNullReason.WILD) then
        table.insert(cards, card)
      end
    end
    table.sort(cards, function(x, y)
      local action = hu.Action.select_discard_if_possible()
      return hu.card_importance(x, action) > hu.card_importance(y, action)
    end)
    cards = tu.list_take(cards, 5)
  end

  hu.highlight_hand(cards)
end

M.best_hand = function()
  local possible_hands = hu.ranked_hands(G.hand.cards)
  hu.highlight_hand(hu.next_best_hand(possible_hands, G.hand.highlighted))
end

local card_order_by_modifier
-- stylua: ignore
card_order_by_modifier = tu.enum({
  hu.card_modifiers.edition.holo,
  hu.card_modifiers.enhancement.Lucky,
  hu.card_modifiers.enhancement.Mult,
  hu.card_modifiers.edition.foil,
  hu.card_modifiers.enhancement.Bonus,
  "EVERYTHING_ELSE",
  hu.card_modifiers.edition.polychrome,
  hu.card_modifiers.enhancement.Glass,
}, function() return card_order_by_modifier.EVERYTHING_ELSE end)
M.reorder_by_enhancements = function()
  table.sort(G.hand.cards, function(x, y)
    local x_order = card_order_by_modifier[hu.card_main_ability(x)]
    local y_order = card_order_by_modifier[hu.card_main_ability(y)]
    -- TODO: try to stack polychrome, glass and red seal on the very last card
    if x_order == y_order then
      return hu.card_importance(x, hu.Action.PLAY) < hu.card_importance(y, hu.Action.PLAY)
    else
      return x_order < y_order
    end
  end)
end

return M
