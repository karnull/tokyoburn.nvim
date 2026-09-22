local util = require("tokyoburn.util")

local M = {}

-- TokyoBurn is a pastel theme on a warm dark background, skewed towards red and
-- pink but keeping genuinely distinct blue, green, cyan and purple hues so that
-- syntax groups (e.g. functions vs variables) stay high-contrast and readable.
---@class Palette
M.default = {
  none = "NONE",
  bg_dark = "#1b110d",
  bg = "#251812",
  bg_highlight = "#3a261d",
  terminal_black = "#4d362c",
  fg = "#f5e8dd",
  fg_dark = "#dcc6b6",
  fg_gutter = "#a37e6d",
  fg_LineNr = "#ff8a99",
  dark3 = "#9a6555",
  comment = "#b58e7c",
  dark5 = "#c39a86",
  blue0 = "#5a3a55",
  blue = "#82c0ff",
  cyan = "#86e0d6",
  blue1 = "#8fd0ff",
  blue2 = "#8ec2ff",
  blue5 = "#a8d8ff",
  blue6 = "#cdeaff",
  blue7 = "#4a2e2a",
  magenta = "#f6a3d0",
  magenta2 = "#ff7eb6",
  purple = "#c8a2ff",
  orange = "#ffb27a",
  yellow = "#ffe08a",
  green = "#a6e3a1",
  green1 = "#b8e6a0",
  green2 = "#8fcf8a",
  teal = "#7fd5c0",
  red = "#ff8088",
  red1 = "#ff6b75",
  red2 = "#5e1f24",
  red3 = "#ff97a0",
  red4 = "#ff8088",
  -- Soft tints used by the lualine mode indicators.
  rose = "#ff9bb3",
  pastel_yellow = "#ffe9a8",
  pastel_orange = "#ffcb98",
  pastel_red = "#ffa3a3",
  -- Diff mode works from these two, stepped onto the theme ground in `M.setup`.
  --
  -- Both are far too bright to use as line backgrounds directly (text sits at
  -- ~3:1 on them), so `M.setup` blends them down the way `bg_visual` and
  -- `bg_search` are built, which is also what keeps them in the same family as
  -- the rest of the palette.
  --
  -- The red is deliberately kept darker than the green rather than matched to
  -- it. Red-green deficiency flattens these two hues towards each other, so the
  -- lightness gap is what carries the distinction: it holds them ~22 dE apart
  -- under deuteranopia, where an equal-lightness pair would collapse to ~8.
  diff_red = "#ff007f",
  diff_green = "#228b22",
  git = { change = "#8ec2ff", add = "#a6e3a1", delete = "#ff8088" },
  gitSigns = {
    add = "#5f8f57",
    change = "#5f7fa8",
    delete = "#a8555f",
  },
}

M.night = {
  bg = "#1f130e",
  bg_dark = "#160d09",
}
M.day = M.night

---@return ColorScheme
function M.setup(opts)
  opts = opts or {}
  local config = require("tokyoburn.config")
  local options = config.options
  local is_day = config.is_day()

  local style = is_day and options.light_style or options.style

  -- Color Palette
  -- `deepcopy` is required: the nested tables (`git`, `gitSigns`) are mutated
  -- below, and a plain merge would hand out references into `M.default`.
  ---@class ColorScheme: Palette
  local colors = vim.tbl_deep_extend("force", vim.deepcopy(M.default), M[style] or {})

  util.bg = colors.bg
  util.day_brightness = options.day_brightness

  -- Two pairs, one per side of a diff: the new side (rightmost window) is
  -- green, every older side red. Within a pair the line background is the
  -- quieter step and the `*_text` step is brighter, so the words that actually
  -- differ stand out from the rest of their line. The two `*_text` steps are
  -- about as far from their own line background as each other (~1.4:1), which
  -- is what keeps the two sides reading as the same design.
  colors.diff = {
    -- a partly-changed line carries the same background as a wholly new one
    add = util.darken(colors.diff_green, 0.52),
    change = util.darken(colors.diff_green, 0.52),
    text = util.darken(colors.diff_green, 0.78),
    delete = util.darken(colors.diff_red, 0.3),
    delete_text = util.darken(colors.diff_red, 0.5),
  }

  colors.git.ignore = colors.dark3
  colors.black = util.darken(colors.bg, 0.8, "#000000")
  colors.border_highlight = util.darken(colors.yellow, 0.8)  -- b l u e
  colors.border = colors.red

  -- Popups and statusline always get a dark background
  colors.bg_popup = colors.bg_dark
  colors.bg_statusline = colors.none

  -- Sidebar and Floats are configurable
  local styles = options.styles
  colors.bg_sidebar = styles.sidebars == "transparent" and colors.none
    or styles.sidebars == "dark" and colors.bg_dark
    or colors.bg

  colors.bg_float = styles.floats == "transparent" and colors.none
    or styles.floats == "dark" and colors.bg_dark
    or colors.bg

  colors.bg_visual = util.darken(colors.red1, 0.4)
  colors.bg_search = util.darken(colors.yellow, 0.45)
  colors.fg_sidebar = colors.fg_dark
  -- colors.fg_float = styles.floats == "dark" and colors.fg_dark or colors.fg
  colors.fg_float = colors.fg

  colors.error = colors.red1
  colors.todo = colors.blue
  colors.warning = colors.yellow
  colors.info = colors.blue2
  colors.hint = colors.teal

  colors.delta = {
    add = util.darken(colors.green2, 0.45),
    delete = util.darken(colors.red1, 0.45),
  }

  options.on_colors(colors)
  if opts.transform and is_day then
    util.invert_colors(colors)
  end

  return colors
end

return M
