local colors = require("tokyoburn.colors").setup({ transform = true })
local config = require("tokyoburn.config").options

local tokyoburn = {}

tokyoburn.normal = {
  a = { bg = colors.red , fg = colors.black },
  b = { bg = colors.black , fg = colors.red },
  c = { bg = colors.bg_statusline, fg = colors.fg_sidebar },
}

tokyoburn.insert = {
  a = { bg = colors.blue, fg = colors.black },
  b = { bg = colors.black , fg = colors.blue },
}

tokyoburn.command = {
  a = { bg = colors.green, fg = colors.black },
  b = { bg = colors.black , fg = colors.green },
}

tokyoburn.visual = {
  a = { bg = colors.teal , fg = colors.black },
  b = { bg = colors.black , fg = colors.teal },
}

tokyoburn.replace = {
  a = { bg = colors.yellow , fg = colors.black },
  b = { bg = colors.black , fg = colors.yellow },
}

tokyoburn.terminal = {
  a = {bg = colors.green1, fg = colors.black },
  b = {bg = colors.black , fg=colors.green1 },
}

tokyoburn.inactive = {
  a = { bg = colors.bg_statusline, fg = colors.blue },
  b = { bg = colors.bg_statusline, fg = colors.fg_gutter, gui = "bold" },
  c = { bg = colors.bg_statusline, fg = colors.fg_gutter },
}

if config.lualine_bold then
  for _, mode in pairs(tokyoburn) do
    mode.a.gui = "bold"
  end
end

return tokyoburn

