use mlua::prelude::*;

/// Minimal shim for `core.tokenizer`.
///
/// The native tokenizer handles all tokenization. `each_token` is needed
/// by `core.doc.highlighter` to iterate token arrays, and
/// `extract_subsyntaxes` is needed by comment-toggle commands.
pub fn register_preload(lua: &Lua) -> LuaResult<()> {
    let preload: LuaTable = lua.globals().get::<LuaTable>("package")?.get("preload")?;
    preload.set(
        "core.tokenizer",
        lua.create_function(|lua, ()| {
            let tokenizer = lua.create_table()?;

            // each_token(t) -> iterator that yields (i, token_type, text) pairs
            tokenizer.set(
                "each_token",
                lua.create_function(|lua, t: LuaTable| {
                    let iter = lua.create_function(|_lua, (t, i): (LuaTable, i64)| {
                        let i = i + 2;
                        let token_type: LuaValue = t.raw_get(i)?;
                        if token_type == LuaValue::Nil {
                            return Ok(LuaMultiValue::new());
                        }
                        let text: LuaValue = t.raw_get(i + 1)?;
                        Ok(LuaMultiValue::from_vec(vec![
                            LuaValue::Integer(i),
                            token_type,
                            text,
                        ]))
                    })?;
                    Ok((iter, t, -1i64))
                })?,
            )?;

            // extract_subsyntaxes(base_syntax, state) -> {syntax, ...}
            //
            // Walks the highlighter state bytes to find which syntaxes are
            // active. Each non-zero byte indexes into the current syntax's
            // `patterns` table; if that pattern has a `.syntax` field, the
            // tokenizer descended into a subsyntax.
            tokenizer.set(
                "extract_subsyntaxes",
                lua.create_function(|lua, (base_syntax, state): (LuaTable, LuaValue)| {
                    let state_bytes: Vec<u8> = match &state {
                        LuaValue::String(s) => s.as_bytes().to_vec(),
                        _ => Vec::new(),
                    };

                    let result = lua.create_table()?;
                    let mut current_syntax = base_syntax;

                    // Always include the base syntax.
                    result.push(current_syntax.clone())?;

                    for &b in &state_bytes {
                        if b == 0 {
                            break;
                        }
                        let patterns: LuaValue = current_syntax.get("patterns")?;
                        let LuaValue::Table(ref pats) = patterns else {
                            break;
                        };
                        let pat: LuaValue = pats.get(b as i64)?;
                        let LuaValue::Table(ref pat_tbl) = pat else {
                            break;
                        };
                        let syn_val: LuaValue = pat_tbl.get("syntax")?;
                        match syn_val {
                            LuaValue::Table(sub) => {
                                current_syntax = sub;
                                result.push(current_syntax.clone())?;
                            }
                            LuaValue::String(name) => {
                                let require: LuaFunction = lua.globals().get("require")?;
                                let syntax_mod: LuaTable = require.call("core.syntax")?;
                                let get: LuaFunction = syntax_mod.get("get")?;
                                let resolved: LuaValue = get.call(name.to_str()?.to_string())?;
                                if let LuaValue::Table(sub) = resolved {
                                    current_syntax = sub;
                                    result.push(current_syntax.clone())?;
                                } else {
                                    break;
                                }
                            }
                            _ => break,
                        }
                    }

                    Ok(result)
                })?,
            )?;

            Ok(LuaValue::Table(tokenizer))
        })?,
    )
}
