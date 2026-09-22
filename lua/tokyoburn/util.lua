local M = {}

M.bg = "#000000"
M.fg = "#ffffff"
M.day_brightness = 0.3

local set_hl = vim.api.nvim_set_hl
local floor = math.floor

-- `blend` is a pure function of (foreground, background, alpha), and the theme
-- asks for the same combinations over and over (e.g. `darken(bg_highlight, 0.4)`
-- is used by a dozen bufferline groups), so results are memoised for good.
local blend_cache = {}

-- `invert_color` is far more expensive (a full hex -> HSLuv -> hex round trip)
-- and gets called for every fg/bg/sp of every highlight when the day style is
-- active. The palette only holds a few dozen distinct colors, so caching turns
-- thousands of conversions into a few dozen.
local invert_cache = {}
local invert_cache_brightness = M.day_brightness

---@param c string
local function hexToRgb(c)
  return tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16)
end

local function channel(fg, bg, alpha)
  local ret = alpha * fg + (1 - alpha) * bg
  if ret < 0 then
    ret = 0
  elseif ret > 255 then
    ret = 255
  end
  return floor(ret + 0.5)
end

---@param foreground string foreground color
---@param background string background color
---@param alpha number|string number between 0 and 1. 0 results in bg, 1 results in fg
function M.blend(foreground, background, alpha)
  alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha

  local key = foreground .. background .. alpha
  local cached = blend_cache[key]
  if cached then
    return cached
  end

  local fr, fg, fb = hexToRgb(foreground)
  local br, bg, bb = hexToRgb(background)

  local hex = string.format("#%02x%02x%02x", channel(fr, br, alpha), channel(fg, bg, alpha), channel(fb, bb, alpha))
  blend_cache[key] = hex
  return hex
end

function M.darken(hex, amount, bg)
  return M.blend(hex, bg or M.bg, amount)
end

function M.lighten(hex, amount, fg)
  return M.blend(hex, fg or M.fg, amount)
end

function M.invert_color(color)
  if color == "NONE" then
    return color
  end

  -- `day_brightness` is configurable, so drop the cache whenever it changes
  if invert_cache_brightness ~= M.day_brightness then
    invert_cache = {}
    invert_cache_brightness = M.day_brightness
  end

  local cached = invert_cache[color]
  if cached then
    return cached
  end

  local hsluv = require("tokyoburn.hsluv")
  local hsl = hsluv.hex_to_hsluv(color)
  hsl[3] = 100 - hsl[3]
  if hsl[3] < 40 then
    hsl[3] = hsl[3] + (100 - hsl[3]) * M.day_brightness
  end

  local inverted = hsluv.hsluv_to_hex(hsl)
  invert_cache[color] = inverted
  return inverted
end

---@param group string
function M.highlight(group, hl)
  local style = hl.style
  if style then
    if type(style) == "table" then
      for k, v in pairs(style) do
        hl[k] = v
      end
    elseif style:lower() ~= "none" then
      -- handle old string style definitions
      for s in style:gmatch("([^,]+)") do
        hl[s] = true
      end
    end
    hl.style = nil
  end
  set_hl(0, group, hl)
end

-- Vim has no notion of an "old" and a "new" side of a diff. In every pane it
-- paints whatever that pane has and the others lack with DiffAdd, so lines that
-- exist only on the left come out green, exactly like lines added on the right.
-- Repainting those groups in all but the rightmost pane is the only way to tell
-- the sides apart.
--
-- DiffChange and DiffText follow DiffAdd for the same reason: a partly-changed
-- line is an addition on one side and a removal on the other, so the changed
-- span has to flip with it.
local OLD_PANE_WHL =
  "DiffAdd:TokyoburnDiffRemoved,DiffChange:TokyoburnDiffRemoved,DiffText:TokyoburnDiffRemovedText"

-- the source groups of the above. On an old pane any mapping of these has to
-- go, whoever wrote it, because ours has to be the one that wins; diffview.nvim
-- always points them at its own `DiffviewDiff*` groups, which is exactly why
-- both of its panes came out green.
local OVERRIDDEN = { DiffAdd = true, DiffChange = true, DiffText = true }

---@return integer[] non-floating windows of the current tabpage
local function tab_windows()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
      wins[#wins + 1] = win
    end
  end
  return wins
end

---@param win integer
---@param old boolean paint this window as an old side of the diff
local function remap_diff(win, old)
  local current = vim.wo[win].winhighlight

  -- the common case by far: a window nobody has touched
  if current == "" then
    if old then
      vim.wo[win].winhighlight = OLD_PANE_WHL
    end
    return
  end

  local kept = {}
  for entry in current:gmatch("[^,]+") do
    local from, to = entry:match("^([^:]*):(.*)$")
    -- On an old pane we take these three over outright. Anywhere else we drop
    -- only our own mappings and leave the rest -- diffview.nvim's
    -- `DiffAdd:DiffviewDiffAdd` and the sidebars' `Normal:NormalSB` are theirs
    -- to set, and a new pane wants diffview's back.
    local ours = old and OVERRIDDEN[from] or vim.startswith(to or "", "TokyoburnDiff")
    if not ours then
      kept[#kept + 1] = entry
    end
  end
  if old then
    kept[#kept + 1] = OLD_PANE_WHL
  end

  local value = table.concat(kept, ",")
  if current ~= value then
    vim.wo[win].winhighlight = value
  end
end

-- winhighlight is window-local and outlives both the colorscheme and diff mode,
-- so every window ever marked has to be handed back, not just this tabpage's
local function clear_diff_panes()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      remap_diff(win, false)
    end
  end
end

local function mark_diff_panes()
  if vim.g.colors_name ~= "tokyoburn" then
    return
  end

  -- Diffview tabpages go through here too. It knows which revision is older,
  -- but it only acts on that with `enhanced_diff_hl`, and even then it hands
  -- both panes the same DiffChange and DiffText, so a changed line reads green
  -- on both sides. Its file panel is not a diff window, so it drops out below
  -- with the sidebars and never counts as a pane.
  local wins = tab_windows()

  local diffs = {}
  for _, win in ipairs(wins) do
    if vim.wo[win].diff then
      diffs[#diffs + 1] = win
    else
      remap_diff(win, false)
    end
  end

  -- left as nil for a lone diff window: it has nothing to be the other side of,
  -- so no pane is singled out and it keeps the plain green
  local new_pane
  if #diffs > 1 then
    -- rightmost is the new file; bottom-most breaks the tie between panes in
    -- the same column, which is what a horizontal `:diffsplit` leaves behind
    new_pane = diffs[1]
    local pos = vim.api.nvim_win_get_position(new_pane)
    local new_row, new_col = pos[1], pos[2]
    for i = 2, #diffs do
      pos = vim.api.nvim_win_get_position(diffs[i])
      if pos[2] > new_col or (pos[2] == new_col and pos[1] > new_row) then
        new_pane, new_row, new_col = diffs[i], pos[1], pos[2]
      end
    end
  end

  for _, win in ipairs(diffs) do
    remap_diff(win, new_pane ~= nil and win ~= new_pane)
  end
end

---@param config Config
function M.autocmds(config)
  local group = vim.api.nvim_create_augroup("tokyoburn", { clear = true })

  vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = group,
    callback = function()
      -- winhighlight outlives the colorscheme, so hand the windows back
      -- untouched rather than pointing them at a group about to be cleared
      clear_diff_panes()
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })

  if config.diff_right_is_new then
    -- these events arrive in bursts (opening a diff fires WinNew, WinEnter and
    -- OptionSet back to back), and only the layout they settle on matters, so
    -- coalesce them into a single pass
    local queued = false
    local update = function()
      if queued then
        return
      end
      queued = true
      -- deferred: on WinClosed the window is still in the tabpage list, and a
      -- `:diffsplit` has not finished moving windows about yet either
      vim.schedule(function()
        queued = false
        mark_diff_panes()
      end)
    end
    local events = { "VimEnter", "WinEnter", "WinNew", "WinClosed", "TabEnter" }
    -- WinResized covers the layout changing under a window that stays current,
    -- which `:wincmd H` / `:wincmd r` do without firing any of the others. It
    -- only exists from 0.9, and the plugin still supports 0.8.
    if vim.fn.exists("##WinResized") == 1 then
      events[#events + 1] = "WinResized"
    end
    vim.api.nvim_create_autocmd(events, { group = group, callback = update })
    vim.api.nvim_create_autocmd("OptionSet", {
      group = group,
      pattern = "diff",
      callback = update,
    })
    -- diffview.nvim reapplies its own window options, `winhighlight` included,
    -- every time it puts a file in a pane, which wipes the remap. These fire
    -- after it has done so. They cost nothing when diffview is not installed.
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = { "DiffviewDiffBufWinEnter", "DiffviewViewPostLayout", "DiffviewViewOpened" },
      callback = update,
    })
    update() -- a diff may already be open when the colorscheme loads
  end

  local sidebar_whl = "Normal:NormalSB,SignColumn:SignColumnSB"
  local function set_whl()
    local whl = vim.wo.winhighlight
    if whl == "" then
      vim.wo.winhighlight = sidebar_whl
    elseif not whl:find("NormalSB", 1, true) then
      vim.wo.winhighlight = whl .. "," .. sidebar_whl
    end
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = table.concat(config.sidebars, ","),
    callback = set_whl,
  })
  if vim.tbl_contains(config.sidebars, "terminal") then
    vim.api.nvim_create_autocmd("TermOpen", {
      group = group,
      callback = set_whl,
    })
  end
end

function M.syntax(syntax)
  for group, colors in pairs(syntax) do
    M.highlight(group, colors)
  end
end

---@param colors ColorScheme
function M.terminal(colors)
  -- dark
  vim.g.terminal_color_0 = colors.black
  vim.g.terminal_color_8 = colors.terminal_black

  -- light
  vim.g.terminal_color_7 = colors.fg_dark
  vim.g.terminal_color_15 = colors.fg

  -- colors
  vim.g.terminal_color_1 = colors.red
  vim.g.terminal_color_9 = colors.red

  vim.g.terminal_color_2 = colors.green
  vim.g.terminal_color_10 = colors.green

  vim.g.terminal_color_3 = colors.yellow
  vim.g.terminal_color_11 = colors.yellow

  vim.g.terminal_color_4 = colors.blue
  vim.g.terminal_color_12 = colors.blue

  vim.g.terminal_color_5 = colors.magenta
  vim.g.terminal_color_13 = colors.magenta

  vim.g.terminal_color_6 = colors.cyan
  vim.g.terminal_color_14 = colors.cyan
end

---@param colors ColorScheme
function M.invert_colors(colors)
  if type(colors) == "string" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return M.invert_color(colors)
  end
  for key, value in pairs(colors) do
    colors[key] = M.invert_colors(value)
  end
  return colors
end

---@param hls Highlights
function M.invert_highlights(hls)
  local invert = M.invert_color
  for _, hl in pairs(hls) do
    if hl.fg then
      hl.fg = invert(hl.fg)
    end
    if hl.bg then
      hl.bg = invert(hl.bg)
    end
    if hl.sp then
      hl.sp = invert(hl.sp)
    end
  end
end

---@param theme Theme
function M.load(theme)
  -- only needed to clear when not the default colorscheme
  if vim.g.colors_name then
    vim.cmd("hi clear")
  end

  vim.o.termguicolors = true
  vim.g.colors_name = "tokyoburn"

  M.syntax(theme.highlights)

  if theme.config.terminal_colors then
    M.terminal(theme.colors)
  end

  M.autocmds(theme.config)

  -- only pay for a timer when there is actually something deferred
  if theme.defer and next(theme.defer) ~= nil then
    vim.defer_fn(function()
      M.syntax(theme.defer)
    end, 100)
  end
end

return M
