local util = require("tokyoburn.util")
local theme = require("tokyoburn.theme")
local config = require("tokyoburn.config")

local M = {}

function M._load(style)
  if style and not M._style then
    M._style = require("tokyoburn.config").options.style
  end
  if not style and M._style then
    require("tokyoburn.config").options.style = M._style
    M._style = nil
  end
  M.load({ style = style, use_background = style == nil })
end

---@param opts Config|nil
function M.load(opts)
  if opts then
    require("tokyoburn.config").extend(opts)
  end
  util.load(theme.setup())
end

M.setup = config.setup

-- keep for backward compatibility
M.colorscheme = M.load

return M
