use std::path::PathBuf;

fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let manifest_dir = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap());
    let nogl_lib = manifest_dir.parent().unwrap().join("lib").join("sdl3-nogl");

    if nogl_lib.exists() {
        // Link against the no-GL SDL3 build bundled in lib/sdl3-nogl/.
        println!("cargo::rustc-link-search=native={}", nogl_lib.display());
    }

    if target_os == "macos" {
        // On macOS, SDL3 sets its install name to @rpath/libSDL3.0.dylib.
        // Set RPATH so the binary finds it in Frameworks/ (for .app bundles)
        // or next to the binary (for standalone use).
        println!("cargo::rustc-link-arg=-Wl,-rpath,@executable_path/../Frameworks");
        println!("cargo::rustc-link-arg=-Wl,-rpath,@executable_path");
    } else if nogl_lib.exists() {
        // Linux: set RPATH for the bundled no-GL SDL3.
        println!(
            "cargo::rustc-link-arg=-Wl,-rpath,$ORIGIN/../lib/sdl3-nogl:$ORIGIN/lib/sdl3-nogl:{}",
            nogl_lib.display()
        );
    }
}
