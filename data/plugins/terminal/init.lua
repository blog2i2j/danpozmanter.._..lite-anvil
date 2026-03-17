-- mod-version:4
local common = require "core.common"
local config = require "core.config"
local keymap = require "core.keymap"
local command = require "core.command"
local core = require "core"

config.plugins.terminal = common.merge({
  config_spec = {
    name = "Terminal",
    {
      label = "Scrollback",
      description = "Maximum number of terminal history lines to keep.",
      path = "scrollback",
      type = "number",
      default = 5000,
      min = 500,
      max = 50000,
    },
    {
      label = "Color Scheme",
      description = "Built-in terminal color scheme.",
      path = "color_scheme",
      type = "selection",
      default = "eterm",
      values = {
        {"eterm", "eterm"},
        {"Builtin Dark", "Builtin Dark"},
        {"Dracula", "Dracula"},
        {"Github", "Github"},
        {"nord", "nord"},
        {"Rosé Pine", "Rosé Pine"},
      },
    },
    {
      label = "Close On Exit",
      description = "Close terminal tabs automatically when the shell exits.",
      path = "close_on_exit",
      type = "toggle",
      default = true,
    },
    {
      label = "Open Position",
      description = "Where new terminal views open by default.",
      path = "open_position",
      type = "selection",
      default = "bottom",
      values = {
        {"Bottom Pane", "bottom"},
        {"New Tab", "tab"},
        {"Left Pane", "left"},
        {"Right Pane", "right"},
        {"Top Pane", "top"},
      },
    },
    {
      label = "Reuse Mode",
      description = "How new terminal requests reuse existing terminal views.",
      path = "reuse_mode",
      type = "selection",
      default = "pane",
      values = {
        {"Same Pane", "pane"},
        {"Last Terminal", "view"},
        {"Same Project", "project"},
        {"Never Reuse", "never"},
      },
    },
  },
  shell = os.getenv("SHELL") or "sh",
  shell_args = {},
  scrollback = 5000,
  color_scheme = "eterm",
  close_on_exit = true,
  open_position = config.terminal.placement or "bottom",
  reuse_mode = config.terminal.reuse_mode or "pane",
}, config.plugins.terminal)

local TerminalView = require ".view"

local function default_cwd()
  local view = core.active_view
  if view and view.doc and view.doc.abs_filename then
    return common.dirname(view.doc.abs_filename)
  end
  local project = core.root_project and core.root_project()
  return project and project.path or os.getenv("HOME") or "."
end

command.add(nil, {
  ["terminal:new"] = function()
    TerminalView.open(default_cwd())
  end,
  ["terminal:new-tab"] = function()
    TerminalView.open(default_cwd(), nil, nil, "tab")
  end,
  ["terminal:new-bottom"] = function()
    TerminalView.open(default_cwd(), nil, nil, "bottom")
  end,
  ["terminal:new-left"] = function()
    TerminalView.open(default_cwd(), nil, nil, "left")
  end,
  ["terminal:new-right"] = function()
    TerminalView.open(default_cwd(), nil, nil, "right")
  end,
  ["terminal:new-top"] = function()
    TerminalView.open(default_cwd(), nil, nil, "top")
  end,
  ["terminal:new-in-project"] = function()
    local project = core.root_project and core.root_project()
    TerminalView.open(project and project.path or default_cwd(), nil, "Terminal: project")
  end,
  ["terminal:new-next-to-file"] = function()
    local view = core.active_view
    local cwd = default_cwd()
    if view and view.doc and view.doc.abs_filename then
      cwd = common.dirname(view.doc.abs_filename)
    end
    TerminalView.open(cwd)
  end,
  ["terminal:close"] = function()
    local view = core.active_view
    if view and view:__tostring() == "TerminalView" then
      local node = core.root_view.root_node:get_node_for_view(view)
      if node then
        node:close_view(core.root_view.root_node, view)
      end
    end
  end,
})

keymap.add {
  ["ctrl+shift+t"] = "terminal:new",
}

return TerminalView
