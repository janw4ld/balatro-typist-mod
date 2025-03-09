local tu = require("typist.lib.tblutils")

local M = {}

local layout = love.filesystem.getInfo("typist-layout")
    and love.filesystem.read("typist-layout"):gsub("%s+", "")
  or "qwerty"

local overrides = love.filesystem.getInfo("typist-overrides.lua")
  and love.filesystem.load("typist-overrides.lua")

-- stylua: ignore
M.free_select_map = ({
  dvorak = tu.enum {
    "a", "o", "e", "u", "i";
    "d", "h", "t", "n", "s";
    "f", "g", "c", "r", "l";
    "'", ",", ".", "p", "y";
  },
  qwerty = tu.enum {
    "a", "s", "d", "f", "g";
    "h", "j", "k", "l", ";";
    "y", "u", "i", "o", "p";
    "q", "w", "e", "r", "t";
  },
})[layout]

local function stitch(keymap, impls, l)
  local res = {}
  for k, v in pairs(impls) do
    res[keymap[k][l]] = v
  end
  return res
end

local global = tu.enum { "RUN_INFO", "OPTIONS" }
M.global_map = stitch({
  [global.RUN_INFO] = {
    dvorak = "q",
    qwerty = "x",
  },
  -- [global.OPTIONS] = {
  --   dvorak = "v",
  --   qwerty = ".",
  -- },
}, {
  [global.RUN_INFO] = function()
    if G.HUD and G.HUD:get_UIE_by_ID("run_info_button").config.button then G.FUNCS.run_info() end
  end,
  -- [global.OPTIONS] = G.FUNCS.options,
}, layout)

local cardarea = tu.enum { "HAND", "JOKERS", "CONSUMEABLES" }
-- stylua: ignore
M.cardarea_map = stitch({
  [cardarea.HAND] = {
    dvorak = "z",
    qwerty = "/",
  },
  [cardarea.JOKERS] = {
    dvorak = "/",
    qwerty = "[",
  },
  [cardarea.CONSUMEABLES] = {
    dvorak = "-",
    qwerty = "'",
  },
}, {
  [cardarea.HAND] = function() return G.hand end,
  [cardarea.JOKERS] = function() return G.jokers end,
  [cardarea.CONSUMEABLES] = function() return G.consumeables end,
}, layout)
M.select_multiple_right = "rshift"
M.select_multiple_left = "lshift"

M.preview_deck = ({
  dvorak = ";",
  qwerty = "z",
})[layout]

M.proceed = "space"
M.dismiss = "tab"
M.reroll = "r"
M.skip = "s"
M.buy = ({
  dvorak = "j",
  qwerty = "c",
})[layout]
M.buy_and_use = ({
  dvorak = "k",
  qwerty = "v",
})[layout]

M.enter = "return"
M.escape = "escape"

local function subscript_fields(keymap, l)
  local res = {}
  for k, v in pairs(keymap) do
    res[k] = v[l]
  end
  return res
end

M.hand = subscript_fields({
  deselect_all = {
    dvorak = "m",
    qwerty = "m",
  },
  invert_selection = {
    dvorak = "b",
    qwerty = "n",
  },
  left5 = {
    dvorak = "w",
    qwerty = ",",
  },
  right5 = {
    dvorak = "v",
    qwerty = ".",
  },
  reorder_by_enhancements = {
    dvorak = "x",
    qwerty = "b",
  },
  sort_by_rank = {
    dvorak = "k",
    qwerty = "v",
  },
  sort_by_suit = {
    dvorak = "j",
    qwerty = "c",
  },
}, layout)

--stylua: ignore
M.cheat = tu.override_merge(subscript_fields({
  leader_right = {
    dvorak = "l",
    qwerty = "p",
  },
  leader_left = {
    dvorak = "'",
    qwerty = "q",
  },
  -- best_high_card = {
  --   dvorak = "k",
  --   qwerty = "h",
  -- },
  -- worst_high_card = {
  --   dvorak = "j",
  --   qwerty = "l",
  -- },
}, layout), {
  best_hand = "b",
  best_flush = "f",
  suits_map = { s = "Spades", d = "Diamonds", c = "Clubs", h = "Hearts" },
  -- TODO: fix jqk conflict in dvorak
  ranks_map =  {
    ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8,
    ["9"] = 9, ["0"] = 10, ["1"] = 10, ["j"] = 11, ["q"] = 12, ["k"] = 13, ["a"] = 14,
  },
})

if overrides then M = tu.override_merge(M, overrides()) end

-- stylua: ignore
return setmetatable(M, {__index = {
  layout_name = layout,
  tostring = function()
    return "keymap = " .. tu.dump_to_string(M) .. "\nlayout_name = \"" .. layout.."\""
  end,
  print = function()
    io.write("keymap = ") tu.dump_to_stdout(M) io.write("\nlayout_name = \"" .. layout.."\"")
  end,
}})
