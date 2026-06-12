local colors = require("tokyoburn.colors").setup({ transform = true })
local config = require("tokyoburn.config").options

local tokyoburn = {}

tokyoburn.normal = {
  a = { bg = colors.rose, fg = colors.black },
  b = { bg = colors.black, fg = colors.rose },
  c = { bg = colors.bg_statusline, fg = colors.fg_sidebar },
}

tokyoburn.insert = {
  a = { bg = colors.pastel_yellow, fg = colors.black },
  b = { bg = colors.black, fg = colors.pastel_yellow },
}

tokyoburn.command = {
  a = { bg = colors.green, fg = colors.black },
  b = { bg = colors.black , fg = colors.green },
}

tokyoburn.visual = {
  a = { bg = colors.pastel_red, fg = colors.black },
  b = { bg = colors.black, fg = colors.pastel_red },
}

tokyoburn.replace = {
  a = { bg = colors.pastel_orange, fg = colors.black },
  b = { bg = colors.black, fg = colors.pastel_orange },
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

