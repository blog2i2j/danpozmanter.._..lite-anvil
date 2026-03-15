use mlua::prelude::*;

fn visible_tabs(view_count: usize, tab_offset: usize, max_tabs: usize) -> usize {
    if view_count == 0 {
        return 0;
    }
    view_count
        .saturating_sub(tab_offset.saturating_sub(1))
        .min(max_tabs.max(1))
}

fn target_tab_width(
    size_x: f64,
    view_count: usize,
    tab_offset: usize,
    max_tabs: usize,
    tab_width: f64,
) -> f64 {
    let visible = visible_tabs(view_count, tab_offset, max_tabs).max(1) as f64;
    let mut width = size_x.max(1.0);
    if view_count > visible as usize {
        width -= 0.0;
    }
    let min_width = width / (max_tabs.max(1) as f64);
    let max_width = width / visible;
    tab_width.clamp(min_width, max_width)
}

pub fn make_module(lua: &Lua) -> LuaResult<LuaTable> {
    let module = lua.create_table()?;
    module.set(
        "visible_tabs",
        lua.create_function(
            |_, (view_count, tab_offset, max_tabs): (usize, usize, usize)| {
                Ok(visible_tabs(view_count, tab_offset, max_tabs) as i64)
            },
        )?,
    )?;
    module.set(
        "target_tab_width",
        lua.create_function(
            |_,
             (size_x, view_count, tab_offset, max_tabs, tab_width): (
                f64,
                usize,
                usize,
                usize,
                f64,
            )| {
                Ok(target_tab_width(
                    size_x, view_count, tab_offset, max_tabs, tab_width,
                ))
            },
        )?,
    )?;
    Ok(module)
}

#[cfg(test)]
mod tests {
    use super::{target_tab_width, visible_tabs};

    #[test]
    fn computes_visible_tabs() {
        assert_eq!(visible_tabs(10, 3, 8), 8);
        assert_eq!(visible_tabs(2, 1, 8), 2);
    }

    #[test]
    fn computes_target_width() {
        let width = target_tab_width(800.0, 4, 1, 8, 170.0);
        assert!(width > 0.0);
    }
}
