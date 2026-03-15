-- mod-version:4
local core = require "core"
local config = require "core.config"
local command = require "core.command"
local Doc = require "core.doc"
local common = require "core.common"

config.plugins.autorestart = common.merge({
  
}, config.plugins.autorestart)

local save = Doc.save
Doc.save = function(self, ...)
  local res = save(self, ...)
  local ok, err = pcall(function()
    local project = core.root_project and core.root_project()
    local project_file = project and (project.path .. PATHSEP .. ".lite_project")
    if self.abs_filename == USERDIR .. PATHSEP .. "init.lua"
    or self.abs_filename == USERDIR .. PATHSEP .. "config.lua"
    or (project_file and self.abs_filename == project_file) then
      command.perform("core:restart")
    end
  end)
  if not ok then
    core.error("Post-save autorestart hook failed for %s: %s", self:get_name(), err)
  end
  return res
end
