local core = require "core"
local command = require "core.command"
local common = require "core.common"

command.add("core.nagview", {
  ["dialog:select-initial"] = function(v, ch)
    if v ~= core.nag_view or type(ch) ~= "string" or #ch ~= 1 then return end
    local matched = nil
    local lower = ch:lower()
    for i, option in ipairs(v.options or {}) do
      local initial = tostring(option.text or ""):sub(1, 1):lower()
      if initial == lower then
        if matched then
          matched = nil
          break
        end
        matched = i
      end
    end
    if matched then
      v:change_hovered(matched)
      command.perform "dialog:select"
      return true
    end
  end,
  ["dialog:previous-entry"] = function(v)
    local hover = v.hovered_item or 1
    v:change_hovered(hover == 1 and #v.options or hover - 1)
  end,
  ["dialog:next-entry"] = function(v)
    local hover = v.hovered_item or 1
    v:change_hovered(hover == #v.options and 1 or hover + 1)
  end,
  ["dialog:select-yes"] = function(v)
    if v ~= core.nag_view then return end
    v:change_hovered(common.find_index(v.options, "default_yes"))
    command.perform "dialog:select"
  end,
  ["dialog:select-no"] = function(v)
    if v ~= core.nag_view then return end
    v:change_hovered(common.find_index(v.options, "default_no"))
    command.perform "dialog:select"
  end,
  ["dialog:select"] = function(v)
    if v.hovered_item then
      v.on_selected(v.options[v.hovered_item])
      v:next()
    end
  end
})
