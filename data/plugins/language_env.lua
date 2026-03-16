-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "Env",
  files = { "%.env$", "%.env%.[%w_.-]+$" },
  comment = "#",
  patterns = {
    { pattern = "#.*",                              type = "comment"  },
    { pattern = { '"', '"', '\\' },                 type = "string"   },
    { pattern = { "'", "'" },                       type = "string"   },
    { pattern = "%${[^}]+}",                        type = "keyword2" },
    { pattern = "%$[%a_][%w_]*",                    type = "keyword2" },
    { pattern = "[%+%-]?%d+%.?%d*",                type = "number"   },
    { pattern = "^%s*()export()%s+",                type = { "normal", "keyword", "normal" } },
    { pattern = "^%s*()[%a_][%w_]*()%s*()=",        type = { "normal", "function", "normal", "operator" } },
    { pattern = "=",                                type = "operator" },
    { pattern = "[%a_][%w_]*",                      type = "symbol"   },
  },
  symbols = {
    ["true"] = "literal",
    ["false"] = "literal",
    ["on"] = "literal",
    ["off"] = "literal",
    ["yes"] = "literal",
    ["no"] = "literal",
    ["null"] = "literal",
  },
}
