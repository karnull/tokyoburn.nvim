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

---@param config Config
function M.autocmds(config)
  local group = vim.api.nvim_create_augroup("tokyoburn", { clear = true })

  vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = group,
    callback = function()
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })

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
