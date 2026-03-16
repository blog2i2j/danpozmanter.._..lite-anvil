-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "INI",
  files = { "%.ini$", "%.cfg$", "%.editorconfig$" },
  comment = ";",
  patterns = {
    { pattern = "[;#].*",                           type = "comment"  },
    { pattern = "^%s*%[.-%]",                       type = "keyword"  },
    { pattern = { '"', '"', '\\' },                 type = "string"   },
    { pattern = { "'", "'" },                       type = "string"   },
    { pattern = "[%+%-]?%d+%.?%d*",                type = "number"   },
    { pattern = "%$[%a_][%w_]*",                    type = "keyword2" },
    { pattern = "%${[^}]+}",                        type = "keyword2" },
    { pattern = "^%s*()[%w_%-%.]+()%s*()=",         type = { "normal", "function", "normal", "operator" } },
    { pattern = "=",                                type = "operator" },
    { pattern = "[%a_][%w_%-%.]*",                  type = "symbol"   },
  },
  symbols = {
    ["true"] = "literal",
    ["false"] = "literal",
    ["on"] = "literal",
    ["off"] = "literal",
    ["yes"] = "literal",
    ["no"] = "literal",
  },
}
