# Typesetter

**Signed-distance-field text for Godot 4.7, with a TextMesh Pro-style API.**

[Repository](https://github.com/jethac/godot-typesetter) · [MIT License](LICENSE) · [Site](https://godot-typesetter.jethachan.net/)

Typesetter is a Godot-native text renderer modelled on TextMesh Pro's feature
set. Its public API is meant to map one-to-one onto TextMesh Pro's under renamed
identifiers (`TextMeshProUGUI` → `TypesetterLabel`, `TextMeshPro` →
`TypesetterText3D`, `TMP_FontAsset` → `TypesetterFontAsset`, members in
snake_case).

**Godot 4.7+ · Rust (gdext) core + GDScript API · MIT licensed**

## Status

Usable, with validation results in [docs/parity.md](docs/parity.md):

- **Font assets:** `TypesetterFontAsset` with static and dynamic atlases, fallback
  chains and sprite assets, in TextMesh Pro's render modes (SDF, SDFAA, SDF8/16/32,
  bitmap, hinted) plus MSDF and MTSDF.
- **Text nodes:** `TypesetterLabel` and `TypesetterText3D`, with rich text, style
  sheets, gradients, every overflow mode, auto-size, pages and `text_info` for
  per-character animation.
- **Shaders:** face, outline, underlay, glow and bevel, plus Mobile and Bitmap
  variants, with anti-aliasing that holds at any scale in 2D and 3D.
- **Input:** `TypesetterInputField` and `TypesetterDropdown`.
- **Editor:** the Font Asset Creator, font asset inspector, menu items and a 3D text
  gizmo.
- **Code that owns its own drawing:** `TypesetterTextLayout` measures, lays out and
  draws text without a node. See [its section below](#drawing-without-a-node).

Measured against Unity TextMesh Pro:

- layout matches to 0.02 units in 198 of 206 cases;
- atlases differ by 0.05 to 0.90 of 255, depending on render mode;
- rendered pixels differ by a median of 0.075 of 255 over 227 cases.

Glow and bevel are fitted approximations. Text changes cost about what Godot's
`Label` does (within 20%), and a quarter of what `Label3D` does in 3D. [docs/parity.md](docs/parity.md) lists every known gap.

## Building

```console
python native/build.py      # builds the Rust core into addons/typesetter/bin
```

CI also uploads the library for Windows, Linux and macOS as build artifacts.

For the web, `python native/build.py --web` builds a single-threaded library. It needs
nightly Rust with `rust-src` and the `wasm32-unknown-emscripten` target, Emscripten
4.0.20 (the version Godot 4.7.2's web templates are built with), and `GODOT4_BIN` pointing at a
Godot 4.7 binary. Export with **Extensions Support** on and **Thread Support** off. The
demo on the [site](https://godot-typesetter.splatterfacegames.com/) is built this way by
`.github/workflows/deploy.yml`.

## API

Classes and members follow TextMesh Pro's under new names, in snake_case.
[docs/api-map.md](docs/api-map.md) has the full mapping.

```gdscript
var label := TypesetterLabel.new()
label.font = load("res://fonts/inter.tres")
label.font_size = 24.0
label.set_text("Score: {0:2}", score)
label.force_mesh_update()
var size := label.get_preferred_values()
```

## Drawing without a node

`TypesetterTextLayout` is for code that runs its own layout, such as a flex engine:

```gdscript
var style := TypesetterTextStyle.new()
style.font = font_asset
style.font_size = 16.0

var layout := TypesetterTextLayout.new()
layout.set_style(style)
layout.set_text("Hello <b>world</b>")

var size := layout.measure(Vector2(max_width, INF))  # fractional, never rounded
layout.layout(Rect2(0, 0, width, height))
layout.draw(get_canvas_item(), Transform2D(), Color.WHITE)
```

Sizes and positions are never rounded to whole pixels. `measure` returns the available
width for wrapped text, as CSS `fit-content` does. If you change a style resource
after setting it, call `invalidate()`.

## Validation

`tools/unity-dump` is a Unity 6000.3 batchmode project that drives TextMesh Pro
through its public API and records what it produces: `textInfo`, preferred and rendered
values, atlases, materials and PNG renders. Its output is committed under `bench/unity`,
so comparisons run without Unity. [docs/parity.md](docs/parity.md) has the commands and
results.

## Benchmarks

`godot --path . -s res://tests/bench/benchmarks.gd` measures atlas generation, layout
per 1,000 characters and per-frame cost against `Label`. On an Intel Xeon W-2135, layout
takes 0.3 to 0.5 ms per 1,000 characters, a full text change 0.7 ms (Label: 0.54 ms) and
an ASCII SDFAA atlas 8 ms.

## Releases

Releases are on [GitHub](https://github.com/splatterfacegames/godot-typesetter/releases),
each with the addon ready to unzip (`addons/typesetter`, native libraries included) and
notes from [CHANGELOG.md](CHANGELOG.md). To make one: move the `[Unreleased]` notes
under a new version heading, set the same version in `addons/typesetter/plugin.cfg`
and `native/Cargo.toml`, and push a `vX.Y.Z` tag. `.github/workflows/release.yml`
checks the versions agree (`python tools/release_notes.py X.Y.Z`), builds every
library and publishes the release.

## Inspiration and provenance

Typesetter was inspired by **TextMesh Pro**, but it is a **clean-room
implementation** created by **Claude Opus 5.5 (Anthropic)**. No TextMesh Pro,
com.unity.ugui, com.unity.textcore or UI Toolkit source code was read, and no
Unity assemblies were decompiled. The implementation was written from:

- Unity's public manual and scripting-API documentation;
- published papers and open-source projects that are not Unity's;
- black-box measurements of Unity's output.

No Unity shaders, fonts, sprites or other assets are included.

Typesetter is not affiliated with, endorsed by, or sponsored by Unity
Technologies. TextMesh Pro and Unity are trademarks of their respective owner.
References to TextMesh Pro describe inspiration and API correspondence only.

## License

Typesetter is available under the [MIT License](LICENSE). Third-party software
and fonts included in the repository remain subject to their own licenses:

- [GUT](addons/gut/LICENSE.md) (MIT);
- [Inter](tests/fonts/Inter-OFL.txt) (SIL Open Font License 1.1);
- [Noto Sans JP](tests/fonts/NotoSansJP-OFL.txt) (SIL Open Font License 1.1), test subset.
