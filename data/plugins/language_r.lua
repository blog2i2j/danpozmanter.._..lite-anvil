-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "R",
  files = { "%.r$", "%.R$", "%.Rmd$", "%.Rprofile$" },
  comment = "#",
  patterns = {
    { pattern = "#.*",                            type = "comment"  },
    { pattern = { '"', '"', '\\' },               type = "string"   },
    { pattern = { "'", "'" },                     type = "string"   },
    { pattern = "0x[%da-fA-F]+",                  type = "number"   },
    { pattern = "%d[%d_]*%.?[%d_]*[eE]?[%+%-]?[%d_]*i?", type = "number" },
    { pattern = "[%+%-=/%*%%<>!~|&%^%?$.:]+",     type = "operator" },
    { pattern = "[%a_%.][%w_%.]*%f[(]",           type = "function" },
    { pattern = "[%a_%.][%w_%.]*",                type = "symbol"   },
  },
  symbols = {
    ["function"] = "keyword", ["if"] = "keyword", ["else"] = "keyword",
    ["for"] = "keyword", ["in"] = "keyword", ["while"] = "keyword",
    ["repeat"] = "keyword", ["break"] = "keyword", ["next"] = "keyword",
    ["return"] = "keyword", ["library"] = "function", ["require"] = "function",
    ["source"] = "function", ["TRUE"] = "literal", ["FALSE"] = "literal",
    ["NULL"] = "literal", ["NA"] = "literal", ["NaN"] = "literal",
    ["Inf"] = "literal", ["T"] = "literal", ["F"] = "literal",
    ["data.frame"] = "keyword2", ["list"] = "keyword2", ["matrix"] = "keyword2",
    ["factor"] = "keyword2", ["numeric"] = "keyword2", ["integer"] = "keyword2",
    ["logical"] = "keyword2", ["character"] = "keyword2",
  },
}
