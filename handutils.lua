local tu = require("typist.lib.tblutils")

local M = {}

M.Action = tu.enum({ "PLAY", "DISCARD" }, {
  select_discard_if_possible = function()
    return G.GAME.current_round.discards_left > 0 and M.Action.DISCARD or M.Action.PLAY
  end,
})

M.CardNullReason = { STONE = "Stone Card", MYSTERY = "back", WILD = "Wild Card" }

-- weights for how urgently a card should be played or discarded given its enhancements
local enhancement_weights = {
  seal = {
    Gold = { [M.Action.PLAY] = 20, [M.Action.DISCARD] = -10 },
    Blue = { [M.Action.PLAY] = -90, [M.Action.DISCARD] = -30 },
    Red = { [M.Action.PLAY] = 50, [M.Action.DISCARD] = 0 },
    Purple = { [M.Action.PLAY] = -20, [M.Action.DISCARD] = 50 },
  },
  edition = {
    holo = { [M.Action.PLAY] = 60, [M.Action.DISCARD] = -20 },
    foil = { [M.Action.PLAY] = 40, [M.Action.DISCARD] = 0 },
    polychrome = { [M.Action.PLAY] = 80, [M.Action.DISCARD] = -30 },
  },
  ability = {
    ["Default Base"] = { [M.Action.PLAY] = 0, [M.Action.DISCARD] = 0 },
    Wild = { [M.Action.PLAY] = -5, [M.Action.DISCARD] = 0 },
    Steel = { [M.Action.PLAY] = -70, [M.Action.DISCARD] = -60 },
    Glass = { [M.Action.PLAY] = 25, [M.Action.DISCARD] = 0 },
    Bonus = { [M.Action.PLAY] = 20, [M.Action.DISCARD] = 0 },
    Mult = { [M.Action.PLAY] = 30, [M.Action.DISCARD] = -20 },
    Stone = { [M.Action.PLAY] = -10, [M.Action.DISCARD] = 35 },
    Lucky = { [M.Action.PLAY] = 40, [M.Action.DISCARD] = -15 },
    Gold = { [M.Action.PLAY] = -25, [M.Action.DISCARD] = -25 },
  },
}

local card_null_reason_values = tu.valueset(M.CardNullReason)
M.get_visible_suit = function(card)
  for _, c in ipairs { card.ability.effect, card.ability.name, card.facing } do
    if card_null_reason_values[c] and not card.debuff then return c end
  end
  return card.base.suit
end
M.get_visible_rank = function(card)
  for _, v in ipairs { card.ability.effect, card.facing } do
    if card_null_reason_values[v] then return v end
  end
  return card.base.id
end

M.get_base_chips = function(rank)
  if rank == 14 then
    return 11
  elseif 13 == rank or rank == 12 or rank == 11 then
    return 10
  end
  return rank
end

-- TODO: we can maybe implement the joker interactions
M.card_importance = function(card, action)
  if card.flipped then return -20 end
  if card.debuff then return -5 end

  local importance = 0
  if card.seal then importance = importance + enhancement_weights.seal[card.seal][action] end
  if card.edition then
    for k, _ in pairs(enhancement_weights.edition) do
      importance = importance + (card.edition[k] and enhancement_weights.edition[k][action] or 0)
    end
  end
  if card.ability then
    local effect = string.gsub(card.ability.name, " Card", "")
    importance = importance + enhancement_weights.ability[effect][action]
  end

  return (M.get_base_chips(card.base.id) + importance) * (action == M.Action.DISCARD and -1 or 1)
end

-- add as many stones as will fit into the current hand
M.top_up_with_stones = function(cards)
  for _, card in ipairs(G.hand.cards) do
    if #cards >= 5 then break end
    if M.get_visible_suit(card) == M.CardNullReason.STONE then table.insert(cards, card) end
  end
  return cards
end

local function count_ranks(hand)
  local rank_occurrences = {}
  for _, card in ipairs(hand) do
    local rank = M.get_visible_rank(card)
    rank_occurrences[rank] = (rank_occurrences[rank] or 0) + 1
  end
  return rank_occurrences
end

M.are_ranks_same = function(hand1, hand2)
  local h1_rank_counts = count_ranks(hand1)
  for rank, h2_count in pairs(count_ranks(hand2)) do
    if h1_rank_counts[rank] ~= h2_count then return false end
    h1_rank_counts[rank] = nil
  end
  return next(h1_rank_counts) == nil
end

M.high_card = function()
  G.hand:unhighlight_all()

  local max_score, min_score = -math.huge, math.huge
  local best, worst = G.hand.cards[1], G.hand.cards[#G.hand.cards]
  for _, card in ipairs(G.hand.cards) do
    local rank = M.get_visible_rank(card)
    if not (rank == M.CardNullReason.STONE or rank == M.CardNullReason.MYSTERY) then
      local score = M.card_importance(card, M.Action.PLAY)
      if score > max_score then
        max_score = score
        best = card
      end
      if score < min_score then
        min_score = score
        worst = card
      end
    end
  end

  return best, worst
end

M.select_cards_of_suit = function(...)
  local target_suits = tu.valueset { ... }
  -- Additionally, include any wild cards in hand
  target_suits[M.CardNullReason.WILD] = true

  local cards = {}
  for i = 1, #G.hand.cards do
    local card = G.hand.cards[i]
    if target_suits[M.get_visible_suit(card)] then table.insert(cards, card) end
  end

  table.sort(cards, function(x, y)
    return M.card_importance(x, M.Action.PLAY) > M.card_importance(y, M.Action.PLAY)
  end)
  return cards
end

M.hand_importance = function(hand)
  local res = 0
  for _, v in pairs(hand) do
    res = res + M.card_importance(v, M.Action.PLAY)
  end
  return res
end

M.ranked_hands = function(cards)
  local fives, fours, trips, twos = {}, {}, {}, {}
  local rank_counts = {}
  local four_fingers = next(find_joker("Four Fingers"))
  local smeared_joker = next(find_joker("Smeared Joker"))
  -- local shortcut = next(find_joker('Shortcut'))

  for _, card in pairs(cards) do
    local rank = M.get_visible_rank(card)
    if not (rank == M.CardNullReason.STONE or rank == M.CardNullReason.MYSTERY) then
      if not rank_counts[rank] then rank_counts[rank] = {} end
      table.insert(rank_counts[rank], card)
    end
  end
  for _, v in pairs(rank_counts) do
    table.sort(v, function(x, y)
      return M.card_importance(x, M.Action.PLAY) > M.card_importance(y, M.Action.PLAY)
    end)
    if #v >= 5 then table.insert(fives, tu.list_take(v, 5)) end
    if #v >= 4 then table.insert(fours, tu.list_take(v, 4)) end
    if #v >= 3 then table.insert(trips, tu.list_take(v, 3)) end
    if #v >= 2 then table.insert(twos, tu.list_take(v, 2)) end
  end

  local full_houses = {}
  for i = 1, #trips do
    for j = 1, #twos do
      if M.get_visible_rank(trips[i][1]) ~= M.get_visible_rank(twos[j][1]) then
        table.insert(full_houses, tu.list_concat(trips[i], twos[j]))
      end
    end
  end

  local two_pairs = {}
  for i = 1, (#twos - 1) do
    for j = i + 1, #twos do
      table.insert(two_pairs, M.top_up_with_stones(tu.list_concat(twos[i], twos[j])))
    end
  end

  -- add stone cards to hands
  for i = 1, #twos do
    twos[i] = M.top_up_with_stones(twos[i])
  end
  for i = 1, #trips do
    trips[i] = M.top_up_with_stones(trips[i])
  end
  for i = 1, #fours do
    fours[i] = M.top_up_with_stones(fours[i])
  end

  local straights = {}
  for i = 1, 10 do
    local has_straight = 1
    local straight = {}
    for j = i, i + 4 do
      local actual_rank = j
      if j == 1 then actual_rank = 14 end -- handle The Wheel blind
      if rank_counts[actual_rank] then
        table.insert(straight, rank_counts[actual_rank][1])
      elseif four_fingers and rank_counts[actual_rank - 1] then
        table.insert(straight, rank_counts[actual_rank - 1][1])
      else
        has_straight = 0
        break
      end
    end

    if has_straight == 1 then table.insert(straights, straight) end
  end

  local cards_by_suit = (
    smeared_joker
    and {
      M.select_cards_of_suit("Spades", "Clubs"),
      M.select_cards_of_suit("Hearts", "Diamonds"),
    }
  )
    or {
      M.select_cards_of_suit("Hearts"),
      M.select_cards_of_suit("Clubs"),
      M.select_cards_of_suit("Diamonds"),
      M.select_cards_of_suit("Spades"),
    }

  local flushes = {}
  for _, sorted_flush in ipairs(cards_by_suit) do
    if #sorted_flush >= 5 then table.insert(flushes, tu.list_take(sorted_flush, 5)) end
    if four_fingers and #sorted_flush >= 4 then
      table.insert(flushes, tu.list_take(sorted_flush, 4))
    end
  end

  table.sort(fives, function(x, y)
    return M.hand_importance(x) > M.hand_importance(y)
  end)
  table.sort(fours, function(x, y)
    return M.hand_importance(x) > M.hand_importance(y)
  end)
  table.sort(flushes, function(x, y)
    return M.hand_importance(x) > M.hand_importance(y)
  end)
  table.sort(straights, function(x, y)
    return M.hand_importance(x) > M.hand_importance(y)
  end)
  table.sort(trips, function(x, y)
    return M.hand_importance(x) > M.hand_importance(y)
  end)
  table.sort(full_houses, function(x, y)
    return M.hand_importance(x) > M.hand_importance(y)
  end)
  table.sort(two_pairs, function(x, y)
    return M.hand_importance(x) > M.hand_importance(y)
  end)
  table.sort(twos, function(x, y)
    return M.hand_importance(x) > M.hand_importance(y)
  end)
  local res = {}
  res = tu.list_concat(res, fives)
  res = tu.list_concat(res, fours)
  res = tu.list_concat(res, full_houses)
  res = tu.list_concat(res, flushes)
  res = tu.list_concat(res, straights)
  res = tu.list_concat(res, trips)
  res = tu.list_concat(res, two_pairs)
  res = tu.list_concat(res, twos)
  return res
end

M.next_best_hand = function(possible_hands, curr_hand)
  if #possible_hands == 1 then return possible_hands[1] end
  if #possible_hands == 0 then return {} end
  for i = 1, (#possible_hands - 1) do
    if M.are_ranks_same(possible_hands[i], curr_hand) then return possible_hands[i + 1] end
  end
  return possible_hands[1]
end

M.highlight_hand = function(cards)
  G.hand:unhighlight_all()
  for _, v in pairs(cards) do
    if not tu.contains(G.hand.highlighted, v) then G.hand:add_to_highlighted(v, true) end
  end
  if next(cards) then
    play_sound("cardSlide1")
  else
    play_sound("cancel")
  end
end

return M
