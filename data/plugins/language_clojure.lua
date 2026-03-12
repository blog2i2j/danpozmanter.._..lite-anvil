-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "Clojure",
  files = { "%.clj$", "%.cljs$", "%.cljc$", "%.edn$", "%.bb$" },
  comment = ";",
  patterns = {
    { pattern = ";.*",                            type = "comment"  },
    { pattern = { '"', '"', '\\' },               type = "string"   },
    { pattern = ":[%a_*!?%+%-][%w_*!?%+%-/%.]*",  type = "keyword2" },
    { pattern = "#[%{%(%[%^_]?[%a_*!?%+%-]*",     type = "keyword"  },
    { pattern = "%d[%d_]*%.?[%d_]*",              type = "number"   },
    { pattern = "[%+%-=/%*%%<>!~|&%^%?%.:]+",     type = "operator" },
    { pattern = "%b()",                           type = "normal"   },
    { pattern = "[%a_*!?%+%-][%w_*!?%+%-/%.]*",   type = "symbol"   },
  },
  symbols = {
    ["def"] = "keyword", ["defn"] = "keyword", ["defmacro"] = "keyword",
    ["defmulti"] = "keyword", ["defmethod"] = "keyword", ["let"] = "keyword",
    ["loop"] = "keyword", ["recur"] = "keyword", ["fn"] = "keyword",
    ["if"] = "keyword", ["when"] = "keyword", ["cond"] = "keyword",
    ["case"] = "keyword", ["do"] = "keyword", ["doseq"] = "keyword",
    ["for"] = "keyword", ["->"] = "keyword", ["->>"] = "keyword",
    ["some->"] = "keyword", ["some->>"] = "keyword", ["ns"] = "keyword",
    ["require"] = "keyword", ["import"] = "keyword", ["use"] = "keyword",
    ["try"] = "keyword", ["catch"] = "keyword", ["finally"] = "keyword",
    ["throw"] = "keyword", ["true"] = "literal", ["false"] = "literal",
    ["nil"] = "literal", ["map"] = "function", ["reduce"] = "function",
    ["filter"] = "function", ["assoc"] = "function", ["dissoc"] = "function",
    ["conj"] = "function", ["first"] = "function", ["rest"] = "function",
  },
}
