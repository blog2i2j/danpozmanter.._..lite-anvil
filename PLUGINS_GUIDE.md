# Lite-Anvil Plugin Guide

A practical reference for writing Lua plugins for Lite-Anvil.

---

## 1. Getting Started

### Where plugins live

User plugins go in `USERDIR/plugins/`. The default `USERDIR` is:

| Platform | Path |
|----------|------|
| Linux | `~/.config/lite-anvil` |
| macOS | `~/Library/Application Support/lite-anvil` |
| Windows | `%APPDATA%\lite-anvil` |

Each plugin is either a single `.lua` file or a directory containing an `init.lua`.

```
~/.config/lite-anvil/plugins/
  my_plugin.lua          -- single-file plugin
  my_other_plugin/
    init.lua             -- directory plugin entry point
    utils.lua            -- helper modules
```

### Naming

Plugin filenames become their module name. `my_plugin.lua` is loaded as `plugins.my_plugin`. Use `snake_case` for filenames.

### The mod-version header

Every plugin **must** declare its compatible API version in a comment within the first few lines. The loader scans for this with a regex. The current mod-version is **4.0.0**.

```lua
-- mod-version:4
```

You can also specify minor and patch versions:

```lua
-- mod-version:4.0.0
```

A plugin loads if its major version matches and its minor/patch versions are less than or equal to the editor's.

### Priority

Plugins load in alphabetical order by default. To load earlier or later, add a priority comment:

```lua
-- priority:10
```

Higher values load later. The default is unset (treated as 0).

### Hello world

Create `USERDIR/plugins/hello.lua`:

```lua
-- mod-version:4
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"

command.add(nil, {
  ["hello:say-hello"] = function()
    core.log("Hello from my plugin!")
  end,
})

keymap.add {
  ["ctrl+shift+h"] = "hello:say-hello",
}
```

Restart the editor. Press `Ctrl+Shift+H` or find "Hello: Say Hello" in the command palette (`Ctrl+P`).

---

## 2. Plugin Lifecycle

### Discovery

On startup, the editor scans two directories for plugins:

1. `DATADIR/plugins/` -- bundled plugins (shipped with the editor)
2. `USERDIR/plugins/` -- user plugins (yours)

User plugins override bundled plugins with the same filename.

### Loading order

1. The editor reads each plugin file's header comments for `mod-version` and `priority`.
2. Plugins with incompatible mod-versions are refused (unless `config.skip_plugins_version` is true).
3. Remaining plugins are sorted by priority (ascending), then loaded via `require`.

### Disabling plugins

In your `USERDIR/init.lua` (or `config.lua`), disable a plugin before it loads:

```lua
local config = require "core.config"
config.plugins.my_plugin = false
```

### Checking if your plugin is enabled

At the top of your plugin, check whether the user disabled it:

```lua
-- mod-version:4
local config = require "core.config"
if config.plugins.my_plugin == false then return end
```

This is a convention -- the editor does not enforce it automatically for user plugins.

### config.plugins behavior

`config.plugins` uses a metatable. Accessing `config.plugins.foo` for the first time auto-creates an enabled entry with an empty config table. Setting `config.plugins.foo = false` disables it. Setting it to a table merges the table into the plugin's config:

```lua
config.plugins.my_plugin = { refresh_interval = 5 }
-- Later, in your plugin:
local my_conf = config.plugins.my_plugin
print(my_conf.refresh_interval) -- 5
```

---

## 3. Core API

Every module below is available via `require`. This section lists the functions and tables most useful to plugin authors.

### core

Application lifecycle, logging, threads, and project management.

```lua
local core = require "core"

core.log(fmt, ...)              -- log a message (shown in status bar + log view)
core.log_quiet(fmt, ...)        -- log without status bar popup
core.warn(fmt, ...)             -- log as warning
core.error(fmt, ...)            -- log as error
core.add_thread(fn, weak_ref, ...)  -- spawn a coroutine thread (see Recipes)
core.open_doc(filename)         -- open a document, returns the Doc object
core.set_active_view(view)      -- switch focus to a view
core.active_view                -- the currently focused View
core.root_view                  -- the root view (layout tree)
core.project_dir                -- absolute path to the open project
core.restart_request            -- set to true to restart the editor
core.quit_request               -- set to true to quit
```

File dialogs:

```lua
core.open_file_dialog(core.window, function(status, path)
  if status == "ok" then
    core.log("Picked: %s", path)
  end
end)
core.open_directory_dialog(core.window, callback)
core.save_file_dialog(core.window, callback)
```

### core.command

Command registry with predicate-based dispatch.

```lua
local command = require "core.command"

-- Add commands. First arg is the predicate (who can run this).
-- nil = always available
-- "core.docview" = available when a DocView is active
-- "core.docview!" = strict: only DocView, not subclasses
-- function = custom predicate returning (true, ...) or false
command.add(nil, {
  ["my-plugin:do-thing"] = function() ... end,
})

command.add("core.docview", {
  ["my-plugin:format"] = function(dv) ... end,
})

command.perform("core:open-log")    -- run a command programmatically
command.is_valid("doc:save")        -- check if a command can run now
command.get_all_valid()             -- list of currently runnable command names
```

When the predicate is a class name string, the active view is passed as the first argument to the command function.

### core.keymap

Keybinding management.

```lua
local keymap = require "core.keymap"

-- Add bindings (appends; existing bindings for the same key are kept)
keymap.add {
  ["ctrl+shift+f5"]  = "my-plugin:reload",
  ["alt+m"]          = "my-plugin:do-thing",
}

-- Overwrite existing bindings for the key
keymap.add({
  ["ctrl+s"] = "my-plugin:custom-save",
}, true)

-- Direct replacement (no duplicate removal)
keymap.add_direct {
  ["ctrl+shift+k"] = "my-plugin:kill-line",
}
```

On macOS, `ctrl+` bindings automatically get a `cmd+` alias unless one already exists.

Stroke format: modifiers joined with `+`, then the key. Modifiers: `ctrl`, `alt`, `shift`, `cmd` (macOS only), `altgr`.

### core.config

Editor settings. All values listed in the source with their defaults:

| Key | Default | Description |
|-----|---------|-------------|
| `fps` | 60 | Target frames per second |
| `max_log_items` | 800 | Maximum log entries |
| `message_timeout` | 5 | Status message display seconds |
| `mouse_wheel_scroll` | 50 * SCALE | Scroll pixels per wheel tick |
| `scroll_past_end` | true | Allow scrolling past last line |
| `file_size_limit` | 10 | File size limit (MB) for syntax highlighting |
| `indent_size` | 2 | Spaces per indent level |
| `tab_type` | "soft" | "soft" (spaces) or "hard" (tabs) |
| `line_height` | 1.2 | Line height multiplier |
| `line_limit` | 80 | Guideline column |
| `highlight_current_line` | true | Highlight the cursor line |
| `max_undos` | 10000 | Maximum undo steps |
| `max_tabs` | 8 | Maximum visible tabs |
| `theme` | "dark_default" | Active color theme |
| `blink_period` | 0.8 | Cursor blink period (seconds) |
| `draw_whitespace` | false | Show whitespace characters |
| `tab_close_button` | true | Show close button on tabs |
| `transitions` | true | Enable UI animations |
| `animation_rate` | 1.0 | Animation speed multiplier |
| `line_endings` | "lf" / "crlf" | Platform default |

Nested tables: `config.large_file`, `config.lsp`, `config.terminal`, `config.ui`, `config.fonts`, `config.gitignore`.

### core.style

Colors, fonts, and theme registration. Access after themes are loaded.

```lua
local style = require "core.style"
style.font           -- the UI font object
style.code_font      -- the code font object
style.padding        -- { x = 14, y = 7 }
style.background     -- background color {r, g, b, a}
style.text           -- default text color
```

### core.common

Utility functions for paths, colors, fuzzy matching, and serialization.

```lua
local common = require "core.common"

common.normalize_path(path)
common.dirname(path)
common.basename(path)
common.home_encode(path)
common.fuzzy_match(haystack, needle)
common.serialize(value)         -- serialize a Lua value to string
common.merge(base, override)    -- deep-merge two tables
common.clamp(val, lo, hi)
common.color(hex_string)        -- "#rrggbb" -> {r, g, b, a}
```

### core.doc

The document model: buffer content, selections, undo/redo.

```lua
local Doc = require "core.doc"

-- Doc instances are normally obtained from core.open_doc() or from a DocView.
local doc = core.open_doc("/path/to/file.txt")

doc:get_text(line1, col1, line2, col2)
doc:insert(line, col, text)
doc:remove(line1, col1, line2, col2)
doc:get_selection()             -- line1, col1, line2, col2
doc:set_selection(l1, c1, l2, c2)
doc:get_filename()
doc:save(filename)
doc:undo()
doc:redo()
doc.lines                       -- array of line strings
```

### core.docview

The code editor view. Extends `core.view`.

```lua
local DocView = require "core.docview"
-- Available as core.active_view when editing a file.
-- dv.doc is the Doc object for the view.
```

### core.object

OOP base class. All views and the Doc class descend from Object.

```lua
local Object = require "core.object"

local MyClass = Object:extend()

function MyClass:new(name)
  self.name = name
end

function MyClass:greet()
  return "Hello, " .. self.name
end

local obj = MyClass("World")
print(obj:greet())          -- "Hello, World"
print(obj:is(MyClass))      -- true
print(obj:extends(Object))  -- true
```

Key methods:
- `Object:extend()` -- create a subclass
- `instance:is(Class)` -- strict type check (exact class)
- `instance:extends(Class)` -- walks the metatable chain
- `Class:is_class_of(instance)` -- inverse of `:is()`
- `Class:is_extended_by(instance)` -- inverse of `:extends()`

### core.view

Base UI view class. Subclass this to create custom panels.

```lua
local View = require "core.view"
```

Key fields on every View instance: `position`, `size`, `scroll`, `cursor`, `scrollable`.

Override these methods in subclasses:
- `new()` -- constructor
- `update()` -- called each frame
- `draw()` -- render the view
- `get_name()` -- tab/panel title
- `get_scrollable_size()` -- total content height
- `on_mouse_pressed(button, x, y, clicks)`
- `on_mouse_released(button, x, y)`
- `on_mouse_moved(x, y, dx, dy)`
- `on_mouse_wheel(y)`
- `on_text_input(text)`
- `on_context_menu(x, y)` -- return a table with `items` for the context menu

### core.plugin_api

Stable facade for plugin authors. Avoids reaching into core internals.

```lua
local api = require "core.plugin_api"
```

**api.session** -- session persistence hooks:
```lua
api.session.on_save("my_plugin", function()
  return { counter = 42 }
end)

api.session.on_load("my_plugin", function(data)
  if data then my_state.counter = data.counter end
end)
```

**api.threads** -- background coroutine threads:
```lua
api.threads.spawn(nil, function()
  -- runs as a coroutine
  coroutine.yield(2) -- sleep 2 seconds
  core.log("Done!")
end)
```

**api.views** -- view management:
```lua
api.views.active()                  -- current active view
api.views.set_active(view)          -- focus a view
api.views.open_doc(path_or_doc)     -- open a document in a new tab
api.views.children()                -- all leaf views
api.views.get_node_for_view(view)   -- layout node containing view
api.views.update_layout()           -- force layout recalculation
api.views.root_size()               -- root node dimensions
api.views.defer_draw(fn, ...)       -- defer a draw call to end of frame
api.views.get_active_node_default() -- default node for new views
api.views.get_primary_node()        -- primary editing node
api.views.add_view(view, placement) -- add a view to the layout
api.views.close_all_docviews(keep_active)
```

**api.prompt** -- command palette interaction:
```lua
api.prompt.enter("Search: ", { ... })
api.prompt.update_suggestions()
```

**api.status** -- status bar:
```lua
api.status.add_item(item)           -- add a status bar item
api.status.show_message(icon, color, text)
api.status.show_tooltip(text)
api.status.remove_tooltip()
api.status.constants.RIGHT()        -- alignment constant
api.status.constants.separator2()   -- separator constant
```

### core.storage

Persistent key-value storage. Data survives editor restarts. Stored as serialized Lua in `USERDIR/storage/`.

```lua
local storage = require "core.storage"

storage.save("my_plugin", "settings", { volume = 80 })
local settings = storage.load("my_plugin", "settings")  -- table or nil
local keys = storage.keys("my_plugin")                   -- list of keys
storage.clear("my_plugin", "settings")                   -- delete one key
storage.clear("my_plugin")                               -- delete all keys
```

### core.contextmenu

Right-click context menu. Extends View.

The context menu is populated by a view's `on_context_menu(x, y)` method. Return a table with an `items` array:

```lua
function MyView:on_context_menu(x, y)
  local results = { items = {} }
  table.insert(results.items, { text = "Do Thing", command = "my-plugin:do-thing" })
  table.insert(results.items, ContextMenu.DIVIDER)
  table.insert(results.items, { text = "Other", command = "my-plugin:other" })
  return results
end
```

### core.syntax

Syntax grammar registration.

```lua
local syntax = require "core.syntax"

syntax.add {
  name = "MyLang",
  files = { "%.mylang$" },
  comment = "//",
  block_comment = { "/*", "*/" },
  patterns = { ... },
  symbols = { ... },
}
```

### core.regex

PCRE2 regex helpers.

```lua
local regex = require "core.regex"
local re = regex.compile("\\w+")
local s, e = regex.find(re, "hello world")
```

### core.process

Child process spawning with coroutine-aware I/O.

### core.dirwatch

File system change watcher.

### Native modules

These are lower-level and accessed via `require`:

- `system` -- file system, clipboard, window, events
- `renderer` -- drawing primitives, font loading
- `regex` -- raw PCRE2 (prefer `core.regex` wrapper)
- `process` -- raw child process (prefer `core.process` wrapper)
- `dirmonitor` -- raw FS monitoring (prefer `core.dirwatch` wrapper)
- `utf8extra` -- UTF-8 string utilities

---

## 4. Recipes

### 4.1 Add a command with a keybinding

```lua
-- mod-version:4
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"

command.add("core.docview", {
  ["my-plugin:duplicate-line"] = function(dv)
    local doc = dv.doc
    local l1, c1, l2, c2 = doc:get_selection()
    local text = doc:get_text(l1, 1, l1 + 1, 1)
    doc:insert(l1, 1, text)
  end,
})

keymap.add {
  ["ctrl+shift+d"] = "my-plugin:duplicate-line",
}
```

### 4.2 Status bar item

```lua
-- mod-version:4
local core = require "core"
local api = require "core.plugin_api"
local style = require "core.style"

api.status.add_item({
  name = "my-plugin:word-count",
  alignment = api.status.constants.RIGHT(),
  get_item = function()
    local av = api.views.active()
    if av and av.doc then
      local text = table.concat(av.doc.lines, "")
      local _, count = text:gsub("%S+", "")
      return {
        style.text, "Words: " .. count,
      }
    end
    return { style.dim, "Words: --" }
  end,
})
```

### 4.3 React to document changes (override Doc methods)

Lite-Anvil does not use an event emitter for document changes. Instead, override the relevant method on the Doc class:

```lua
-- mod-version:4
local Doc = require "core.doc"
local core = require "core"

local original_save = Doc.save
function Doc:save(...)
  original_save(self, ...)
  core.log("Saved: %s", self:get_filename() or "untitled")
end
```

You can do the same with `Doc.insert`, `Doc.remove`, etc.

### 4.4 Custom view

```lua
-- mod-version:4
local core = require "core"
local View = require "core.view"
local style = require "core.style"
local command = require "core.command"
local keymap = require "core.keymap"
local api = require "core.plugin_api"

local MyView = View:extend()

function MyView:new()
  MyView.super.new(self)
  self.scrollable = true
  self.items = { "Alpha", "Bravo", "Charlie", "Delta" }
end

function MyView:get_name()
  return "My Custom View"
end

function MyView:get_scrollable_size()
  local lh = style.code_font:get_height() + style.padding.y
  return lh * #self.items + style.padding.y
end

function MyView:draw()
  self:draw_background(style.background)
  local x = self.position.x + style.padding.x
  local y = self.position.y + style.padding.y - self.scroll.y
  local font = style.code_font
  local lh = font:get_height() + style.padding.y
  for i, item in ipairs(self.items) do
    renderer.draw_text(font, item, x, y, style.text)
    y = y + lh
  end
  self:draw_scrollbar()
end

command.add(nil, {
  ["my-plugin:open-view"] = function()
    local node = api.views.get_active_node_default()
    node:add_view(MyView())
  end,
})

keymap.add {
  ["ctrl+alt+m"] = "my-plugin:open-view",
}
```

### 4.5 Background thread

```lua
-- mod-version:4
local core = require "core"
local api = require "core.plugin_api"

api.threads.spawn(nil, function()
  while true do
    -- Do periodic work here.
    local result = some_check()
    if result then
      core.log("Check passed")
    end
    coroutine.yield(5) -- sleep 5 seconds before next check
  end
end)
```

The first argument to `spawn` is a `weak_ref` key. Pass `nil` for anonymous threads, or a unique value if you need to track it.

### 4.6 File dialog

```lua
-- mod-version:4
local core = require "core"
local command = require "core.command"

command.add(nil, {
  ["my-plugin:import-file"] = function()
    core.open_file_dialog(core.window, function(status, path)
      if status == "ok" and path then
        core.log("User picked: %s", path)
        -- process the file at `path`
      end
    end)
  end,
})
```

### 4.7 Persistent storage

```lua
-- mod-version:4
local core = require "core"
local storage = require "core.storage"
local command = require "core.command"

local counter = storage.load("my_plugin", "counter") or 0

command.add(nil, {
  ["my-plugin:increment"] = function()
    counter = counter + 1
    storage.save("my_plugin", "counter", counter)
    core.log("Counter: %d", counter)
  end,
  ["my-plugin:reset"] = function()
    counter = 0
    storage.clear("my_plugin", "counter")
    core.log("Counter reset")
  end,
})
```

### 4.8 Override / wrap an existing command

```lua
-- mod-version:4
local core = require "core"
local command = require "core.command"

-- The new command replaces the old one because it uses the same name.
command.add("core.docview", {
  ["doc:save"] = function(dv)
    -- Pre-save hook: strip trailing whitespace.
    local doc = dv.doc
    for i = 1, #doc.lines do
      local line = doc.lines[i]
      local trimmed = line:gsub("%s+$", "")
      if trimmed ~= line then
        doc:remove(i, #trimmed + 1, i, #line + 1)
      end
    end
    -- Call the original save.
    doc:save()
  end,
})
```

### 4.9 Context menu entry

Override `on_context_menu` in DocView to add items:

```lua
-- mod-version:4
local DocView = require "core.docview"
local command = require "core.command"
local ContextMenu = require "core.contextmenu"

local original_on_context_menu = DocView.on_context_menu

function DocView:on_context_menu(x, y)
  local results = original_on_context_menu(self, x, y)
  if results and results.items then
    table.insert(results.items, ContextMenu.DIVIDER)
    table.insert(results.items, {
      text = "My Custom Action",
      command = "my-plugin:custom-action",
    })
  end
  return results
end

command.add("core.docview", {
  ["my-plugin:custom-action"] = function(dv)
    core.log("Custom action on %s", dv.doc:get_filename() or "untitled")
  end,
})
```

### 4.10 New syntax grammar

```lua
-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "TOML",
  files = { "%.toml$" },
  comment = "#",
  patterns = {
    { pattern = { '#', '\n' },        type = "comment" },
    { pattern = { '"""', '"""' },     type = "string" },
    { pattern = { '"', '"', '\\' },   type = "string" },
    { pattern = { "'", "'" },         type = "string" },
    { pattern = "-?%d+%.%d+",         type = "number" },
    { pattern = "-?%d+",              type = "number" },
    { pattern = "true",               type = "literal" },
    { pattern = "false",              type = "literal" },
    { pattern = "%[%[?[%w%-%._]+%]%]?", type = "keyword" },
    { pattern = "[%w%-%._]+%s*=",     type = "keyword2" },
  },
  symbols = {},
}
```

---

## 5. Tips and Pitfalls

### coroutine.yield boundary

Background threads created with `core.add_thread` or `api.threads.spawn` run as Lua coroutines. The argument to `coroutine.yield(seconds)` is the number of seconds to sleep before the thread resumes.

**You cannot yield across a Rust/C call boundary.** If your thread calls a native function that internally calls back into Lua, yielding inside that callback will crash. Keep yields at the top level of your thread function, not inside callbacks passed to native APIs.

```lua
-- CORRECT
api.threads.spawn(nil, function()
  while true do
    local data = do_work()       -- native call finishes, then...
    coroutine.yield(1)           -- yield at top level
  end
end)

-- WRONG: yielding inside a callback that crosses the Rust boundary
api.threads.spawn(nil, function()
  some_native_api(function()
    coroutine.yield(1)           -- will error
  end)
end)
```

### config.plugins check

Always guard your plugin with a config check at the top so users can disable it:

```lua
-- mod-version:4
local config = require "core.config"
if config.plugins.my_plugin == false then return end
```

### Thread arguments

`core.add_thread(fn, weak_ref, ...)` passes extra arguments to `fn` on its first resume. Use this to pass initial state:

```lua
core.add_thread(function(path)
  -- `path` is available here on first resume
  local content = read_file(path)
end, nil, "/some/path")
```

### Object:extend and super

When overriding methods in a subclass, call the parent via `self.super`:

```lua
local MyView = View:extend()

function MyView:new()
  MyView.super.new(self)   -- always call super:new()
  self.my_field = 42
end

function MyView:update()
  MyView.super.update(self)
  -- custom update logic
end
```

The `super` field is set automatically by `:extend()` and points to the parent class table.

### Large file mode

Files exceeding `config.large_file.soft_limit_mb` (default 20 MB) trigger large file mode. By default this means:

- `read_only = true` -- the document is read-only
- `plain_text = true` -- syntax highlighting is disabled
- `disable_lsp = true` -- no LSP features
- `disable_autocomplete = true` -- no autocomplete

Files exceeding `config.large_file.hard_limit_mb` (default 128 MB) are refused entirely.

If your plugin processes document content, check for large file mode to avoid performance problems:

```lua
local config = require "core.config"

local function should_process(doc)
  if not doc or not doc:get_filename() then return true end
  local info = system.get_file_info(doc:get_filename())
  if info and info.size then
    local mb = info.size / (1024 * 1024)
    if mb > config.large_file.soft_limit_mb then
      return false
    end
  end
  return true
end
```

### Global variables

These globals are available everywhere without `require`:

| Global | Type | Description |
|--------|------|-------------|
| `ARGS` | table | Command line arguments |
| `PLATFORM` | string | "Linux", "Mac OS X", or "Windows" |
| `ARCH` | string | e.g. "x86_64-linux" |
| `SCALE` | number | Current UI scale factor |
| `VERSION` | string | Editor version |
| `MOD_VERSION_STRING` | string | "4.0.0" |
| `EXEFILE` | string | Path to the editor binary |
| `EXEDIR` | string | Directory containing the binary |
| `DATADIR` | string | Bundled data directory |
| `USERDIR` | string | User config directory |
| `HOME` | string | User home directory |
| `PATHSEP` | string | "/" or "\\" |
| `RESTARTED` | boolean | True if this is a restart, not a fresh launch |

---

## Config Reference

All options live under the `config` table (`require "core.config"`). Set them
in `USERDIR/config.lua`. Plugins read them at runtime.

### Editor

| Key | Default | Type | Description |
|-----|---------|------|-------------|
| `fps` | `60` | int | Target frames per second |
| `max_log_items` | `800` | int | Max entries in the log buffer |
| `message_timeout` | `5` | int | Seconds before status messages fade |
| `mouse_wheel_scroll` | `50 * SCALE` | float | Scroll distance per wheel tick |
| `animate_drag_scroll` | `false` | bool | Animate scroll during drag |
| `scroll_past_end` | `true` | bool | Allow scrolling past the last line |
| `force_scrollbar_status` | `false` | bool | Always show scrollbars |
| `highlight_current_line` | `true` | bool | Highlight the line with the cursor |
| `line_height` | `1.2` | float | Line height multiplier |
| `indent_size` | `2` | int | Spaces per indent level |
| `tab_type` | `"soft"` | string | `"soft"` (spaces) or `"hard"` (tabs) |
| `line_endings` | `"lf"` | string | `"lf"` or `"crlf"` (Windows default: `"crlf"`) |
| `line_limit` | `80` | int | Column for the long-line indicator |
| `long_line_indicator` | `false` | bool | Show vertical ruler at `line_limit` |
| `max_undos` | `10000` | int | Maximum undo history entries |
| `undo_merge_timeout` | `0.3` | float | Seconds before a new undo group starts |
| `max_tabs` | `8` | int | Max visible tabs before scrolling |
| `always_show_tabs` | `true` | bool | Show tab bar even with one file |
| `tab_close_button` | `true` | bool | Show close button on tabs |
| `max_clicks` | `3` | int | Click count for multi-click selection |
| `blink_period` | `0.8` | float | Cursor blink period in seconds |
| `disable_blink` | `false` | bool | Disable cursor blinking |
| `transitions` | `true` | bool | Enable animations globally |
| `animation_rate` | `1.0` | float | Animation speed multiplier |
| `borderless` | `false` | bool | Use borderless window with custom title bar |
| `draw_whitespace` | `false` | bool | Render whitespace characters |
| `keep_newline_whitespace` | `false` | bool | Preserve trailing whitespace on newlines |
| `symbol_pattern` | `"[%a_][%w_]*"` | string | Lua pattern for symbol detection |
| `non_word_chars` | (punctuation) | string | Characters that break word boundaries |
| `theme` | `"dark_default"` | string | Active color theme name |

### Fonts (`config.fonts`)

| Key | Default | Description |
|-----|---------|-------------|
| `fonts.ui.path` | `DATADIR/fonts/Lilex-Regular.ttf` | UI font |
| `fonts.ui.size` | `15` | UI font size |
| `fonts.code.path` | `DATADIR/fonts/Lilex-Medium.ttf` | Code font |
| `fonts.code.size` | `15` | Code font size |
| `fonts.icon.path` | `DATADIR/fonts/icons.ttf` | Icon font |
| `fonts.syntax` | `{}` | Per-token-type font overrides (e.g. `syntax.comment = {path=..., size=15, options={italic=true}}`) |

Font options: `antialiasing` (`"none"`, `"grayscale"`, `"subpixel"`), `hinting` (`"none"`, `"slight"`, `"full"`), `bold`, `italic`, `underline`, `strikethrough` (all bool).

### UI Metrics (`config.ui`)

| Key | Default | Description |
|-----|---------|-------------|
| `ui.divider_size` | `1` | Pane divider width in pixels |
| `ui.scrollbar_size` | `4` | Contracted scrollbar width |
| `ui.expanded_scrollbar_size` | `12` | Expanded scrollbar width on hover |
| `ui.caret_width` | `2` | Cursor width in pixels |
| `ui.tab_width` | `170` | Tab bar tab width |
| `ui.padding_x` | `14` | Horizontal padding |
| `ui.padding_y` | `7` | Vertical padding |

### Large File Handling (`config.large_file`)

| Key | Default | Description |
|-----|---------|-------------|
| `large_file.soft_limit_mb` | `20` | Files above this open in large-file mode |
| `large_file.hard_limit_mb` | `128` | Files above this open in degraded mode |
| `large_file.read_only` | `true` | Large files are read-only |
| `large_file.plain_text` | `true` | Disable syntax highlighting for large files |

### LSP (`config.lsp`)

| Key | Default | Description |
|-----|---------|-------------|
| `lsp.load_on_startup` | `true` | Start LSP servers on launch |
| `lsp.semantic_highlighting` | `true` | Use LSP semantic tokens |
| `lsp.inline_diagnostics` | `true` | Show inline error squiggles |
| `lsp.format_on_save` | `true` | Auto-format on save |

### Git (`config.plugins.git`)

| Key | Default | Description |
|-----|---------|-------------|
| `plugins.git.refresh_interval` | `5` | Seconds between git status refreshes |
| `plugins.git.show_branch_in_statusbar` | `true` | Show branch name in status bar |
| `plugins.git.treeview_highlighting` | `true` | Color files by git status in tree |

### Terminal (`config.terminal`)

| Key | Default | Description |
|-----|---------|-------------|
| `terminal.placement` | `"bottom"` | Where terminal opens (`"bottom"`, `"right"`) |
| `terminal.reuse_mode` | `"pane"` | Reuse existing terminal pane |

### Gitignore (`config.gitignore`)

| Key | Default | Description |
|-----|---------|-------------|
| `gitignore.enabled` | `true` | Respect .gitignore for file filtering |
| `gitignore.additional_patterns` | `{}` | Extra patterns to ignore |

### Minimap (`config.plugins.minimap`)

| Key | Default | Description |
|-----|---------|-------------|
| `plugins.minimap.enabled` | `false` | Show the code overview minimap sidebar |
| `plugins.minimap.width` | `120` | Width of the minimap in pixels |
| `plugins.minimap.line_height` | `4` | Height of each line in the minimap in pixels |

To enable by default, add to your `config.lua`:

```lua
config.plugins.minimap = { enabled = true }
```

Toggle at runtime with the `minimap:toggle` command.

### Animations (`config.disabled_transitions`)

Set any to `true` to disable that specific animation:

`scroll`, `commandview`, `contextmenu`, `logview`, `nagbar`, `tabs`,
`tab_drag`, `statusbar` — all default to `false`.
