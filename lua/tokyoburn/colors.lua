local util = require("tokyoburn.util")

local M = {}

-- TokyoBurn is Tokyo after dark with the city on fire: neon signage burning
-- over a charred, ember-warm ground.
--
-- Two families do all the work. The fire half -- blood red, molten orange,
-- bright yellow -- is the ambient one: it owns the gutter, the borders, the
-- folds, the selection, the statements, the strings, and every function name.
-- Red leads it, and it leads the theme.
--
-- The neon half -- electric blue, hot pink, acid green, cyan, violet -- is the
-- signage. It is fully saturated on purpose, and it is rare on purpose: it
-- marks the things worth looking at (TODOs, diagnostics, types, properties) so
-- they glow off the char rather than sitting in it. Nothing here is pastel;
-- everything is pushed to the top of its hue so it survives being laid on a
-- background this dark.
--
-- Rose pink is the seam between the two halves and is reserved for
-- highlighting: search matches, the matched bracket, the border of a focused
-- float.
--
-- Chrome that only marks a position (the cursor line and column, the ruler) is
-- desaturated out of both halves entirely.
---@class Palette
M.default = {
  none = "NONE",
  -- The ground is char, not brown: nearly black, with just enough red left in
  -- it to read as something that has been burning rather than something grey.
  --
  -- `bg` is load-bearing beyond its own colour -- every `util.darken` call
  -- blends against it, including the diff backgrounds -- so it stays fixed.
  bg_dark = "#190c08",
  bg = "#251812",
  bg_highlight = "#3d2016",
  -- The cursor crosshair and the 'colorcolumn' ruler are chrome, not syntax, so
  -- they are pulled out of the palette entirely: a true neutral grey (R=G=B),
  -- which is also why it can sit this dark and still be findable -- against a
  -- warm ground the absence of hue separates it as much as the lightness does.
  -- One value for all three, at 1.09 against the night background and 1.26 over
  -- a black terminal under `transparent`. It marks where the cursor is; it is
  -- not meant to read as a band across the buffer.
  bg_cursorline = "#1e1e1e",
  terminal_black = "#52291f",
  fg = "#ffeadf",
  fg_dark = "#e3c3b2",
  fg_gutter = "#8f5f4e",
  fg_LineNr = "#ff5c6e",
  dark3 = "#96584a",
  -- Comments sit almost on the greyscale axis (6% saturation): they are the one
  -- large block of text that should not take a side between fire and neon.
  comment = "#8a807b",
  dark5 = "#b5806c",
  -- Neon: the signage half. Saturation is the point -- these are meant to look
  -- lit rather than printed.
  blue = "#3db8ff",
  blue1 = "#18ccff",
  blue2 = "#4aa8ff",
  blue5 = "#6fd0ff",
  blue6 = "#b7ecff",
  blue7 = "#4a2018",
  cyan = "#19e6d6",
  teal = "#0fd6b4",
  green = "#4ae87f",
  green1 = "#72f59b",
  green2 = "#22b45e",
  magenta = "#ff5ad0",
  magenta2 = "#ff44ad",
  purple = "#b583ff",
  -- Fire: the ambient half, and the one that leads. The four reds are ordered
  -- by lightness so they stay apart in a buffer: `red1` is the hot one and
  -- belongs to errors and statements, `red` is structural (borders, folds,
  -- `self`), `red2` is the bright one that calls attention to a name -- the
  -- cursor's own line number and every function -- and `red3` is the light
  -- ember used for parameters. Yellow is no longer rationed: strings spend it.
  red = "#ff3b4e",
  red1 = "#ff2d4a",
  red2 = "#ff4a4a",
  red3 = "#ff7a85",
  red4 = "#ff3b4e",
  orange = "#ff7a29",
  yellow = "#ffe14a",
  -- The highlight accent, the seam between fire and neon: search matches, the
  -- matched bracket, the border of a focused float. Also lualine's normal mode,
  -- which is what it was originally mixed for.
  rose = "#ff6f9c",
  -- Soft tints used by the remaining lualine mode indicators.
  pastel_yellow = "#ffd977",
  pastel_orange = "#ffa861",
  pastel_red = "#ff8a8a",
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
  bg_dark = "#120806",
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
  -- `border_highlight` frames the focused float, so it takes the highlight
  -- accent rather than another structural red: against `border` (plain red) it
  -- is the pair that says which window you are actually in.
  colors.border_highlight = util.darken(colors.rose, 0.8)
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
  -- The visual selection stays red (the main colour, and the larger block of
  -- the two); search matches take rose, so a selection and a match are never
  -- the same wash of colour on screen at once.
  colors.bg_search = util.darken(colors.rose, 0.45)
  colors.fg_sidebar = colors.fg_dark
  -- colors.fg_float = styles.floats == "dark" and colors.fg_dark or colors.fg
  colors.fg_float = colors.fg

  colors.error = colors.red1
  -- `todo` is the loudest cool colour in the theme on purpose: a TODO is the
  -- one comment you want to catch across a warm, low-contrast buffer, and no
  -- warm hue can do that here without being mistaken for an error or a string.
  colors.todo = colors.blue1
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
