-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "Ruby",
  files = { "%.rb$", "%.rake$", "Gemfile$", "Rakefile$", "%.gemspec$" },
  headers = "^#!.*ruby",
  comment = "#",
  patterns = {
    { pattern = "#.*",                            type = "comment"  },
    { pattern = { '"""', '"""', '\\' },          type = "string"   },
    { pattern = { '"', '"', '\\' },              type = "string"   },
    { pattern = { "'", "'" },                    type = "string"   },
    { pattern = ":[%a_][%w_]*[!?=]?",            type = "keyword2" },
    { pattern = "@@?[%a_][%w_]*",                type = "keyword2" },
    { pattern = "%$[%a_][%w_]*",                 type = "keyword2" },
    { pattern = "0x[%da-fA-F_]+",                type = "number"   },
    { pattern = "%d[%d_]*%.?[%d_]*",             type = "number"   },
    { pattern = "[%+%-=/%*%%<>!~|&%^%?%.:]+",    type = "operator" },
    { pattern = "[%a_][%w_]*[!?=]?%f[(]",        type = "function" },
    { pattern = "[%a_][%w_]*[!?=]?",             type = "symbol"   },
  },
  symbols = {
    ["class"] = "keyword", ["module"] = "keyword", ["def"] = "keyword",
    ["end"] = "keyword", ["if"] = "keyword", ["elsif"] = "keyword",
    ["else"] = "keyword", ["unless"] = "keyword", ["case"] = "keyword",
    ["when"] = "keyword", ["while"] = "keyword", ["until"] = "keyword",
    ["for"] = "keyword", ["in"] = "keyword", ["do"] = "keyword",
    ["begin"] = "keyword", ["rescue"] = "keyword", ["ensure"] = "keyword",
    ["retry"] = "keyword", ["redo"] = "keyword", ["break"] = "keyword",
    ["next"] = "keyword", ["return"] = "keyword", ["yield"] = "keyword",
    ["super"] = "keyword", ["self"] = "keyword", ["alias"] = "keyword",
    ["undef"] = "keyword", ["then"] = "keyword", ["and"] = "keyword",
    ["or"] = "keyword", ["not"] = "keyword", ["true"] = "literal",
    ["false"] = "literal", ["nil"] = "literal", ["puts"] = "function",
    ["print"] = "function", ["require"] = "function", ["require_relative"] = "function",
    ["attr_reader"] = "function", ["attr_writer"] = "function", ["attr_accessor"] = "function",
  },
}
