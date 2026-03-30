use mlua::prelude::*;

/// Registers `system.show_fatal_error` for pre-UI fatal errors.
///
/// All user-facing dialogs use the in-app `core.nag_view` which renders
/// inside the editor window. `show_fatal_error` uses SDL's simple message
/// box as a last resort when the UI system may not be functional.
#[cfg(feature = "sdl")]
pub fn register_dialog_fns(lua: &Lua, system_table: &LuaTable) -> LuaResult<()> {
    system_table.set(
        "show_fatal_error",
        lua.create_function(|_lua, (title, msg): (String, String)| {
            use sdl3_sys::everything::*;
            use std::ffi::CString;
            let t = CString::new(title).unwrap_or_default();
            let m = CString::new(msg).unwrap_or_default();
            // SAFETY: valid C strings, null window is acceptable for fatal.
            unsafe {
                SDL_ShowSimpleMessageBox(
                    SDL_MESSAGEBOX_ERROR,
                    t.as_ptr(),
                    m.as_ptr(),
                    std::ptr::null_mut(),
                );
            }
            Ok(())
        })?,
    )?;

    Ok(())
}

/// Headless stub for non-SDL builds.
#[cfg(not(feature = "sdl"))]
pub fn register_dialog_fns(lua: &Lua, system_table: &LuaTable) -> LuaResult<()> {
    system_table.set(
        "show_fatal_error",
        lua.create_function(|_lua, (title, msg): (String, String)| -> LuaResult<()> {
            eprintln!("Fatal error: {title}: {msg}");
            Ok(())
        })?,
    )?;

    Ok(())
}
