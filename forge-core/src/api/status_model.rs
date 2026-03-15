use mlua::prelude::*;

#[derive(Clone, Copy)]
struct PanelFit {
    left_width: f64,
    right_width: f64,
    left_offset: f64,
    right_offset: f64,
}

fn fit_panels(
    total_width: f64,
    raw_left: f64,
    raw_right: f64,
    padding: f64,
    current_left_offset: f64,
    current_right_offset: f64,
) -> PanelFit {
    let mut left_width = raw_left;
    let mut right_width = raw_right;
    let mut left_offset = current_left_offset;
    let mut right_offset = current_right_offset;

    if raw_left + raw_right + (padding * 4.0) > total_width {
        if raw_left + (padding * 2.0) < total_width / 2.0 {
            right_width = total_width - raw_left - (padding * 3.0);
            if right_width > raw_right {
                left_width = raw_left + (right_width - raw_right);
                right_width = raw_right;
            }
        } else if raw_right + (padding * 2.0) < total_width / 2.0 {
            left_width = total_width - raw_right - (padding * 3.0);
        } else {
            left_width = total_width / 2.0 - (padding + padding / 2.0);
            right_width = total_width / 2.0 - (padding + padding / 2.0);
        }

        if right_width >= raw_right {
            right_offset = 0.0;
        } else if right_width > right_offset + raw_right {
            right_offset = right_width - raw_right;
        }
        if left_width >= raw_left {
            left_offset = 0.0;
        } else if left_width > left_offset + raw_left {
            left_offset = left_width - raw_left;
        }
    } else {
        left_offset = 0.0;
        right_offset = 0.0;
    }

    PanelFit {
        left_width,
        right_width,
        left_offset,
        right_offset,
    }
}

pub fn make_module(lua: &Lua) -> LuaResult<LuaTable> {
    let module = lua.create_table()?;
    module.set(
        "fit_panels",
        lua.create_function(
            |lua,
             (total_width, raw_left, raw_right, padding, left_offset, right_offset): (
                f64,
                f64,
                f64,
                f64,
                f64,
                f64,
            )| {
                let fit = fit_panels(
                    total_width,
                    raw_left,
                    raw_right,
                    padding,
                    left_offset,
                    right_offset,
                );
                let out = lua.create_table()?;
                out.set("left_width", fit.left_width)?;
                out.set("right_width", fit.right_width)?;
                out.set("left_offset", fit.left_offset)?;
                out.set("right_offset", fit.right_offset)?;
                Ok(out)
            },
        )?,
    )?;
    Ok(module)
}

#[cfg(test)]
mod tests {
    use super::fit_panels;

    #[test]
    fn clamps_panels_when_overflowing() {
        let fit = fit_panels(300.0, 200.0, 200.0, 10.0, 0.0, 0.0);
        assert!(fit.left_width + fit.right_width < 400.0);
    }
}
