# Changelog

All notable changes to Typesetter are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-11-08

### Performance

- Changing font size, spacing, margins, colour or the visible-character limits at
  runtime no longer forces a full settings sync: 100 labels resizing every frame went
  from 19.6 to 3.3 ms (Godot's `Label`: 4.3 ms). Size changes never touch the atlas;
  `tests/bench/font_size_bench.gd` measures both.

## [0.1.0] - 2026-11-08

First release: signed-distance-field text for Godot 4.7 with TextMesh Pro's feature
set, under renamed identifiers (see `docs/api-map.md`).

### Added

- `TypesetterFontAsset`: static and dynamic atlases in TextMesh Pro's render modes
  (SDF, SDFAA, SDF8/16/32, bitmap and hinted variants) plus MSDF and MTSDF; fallback
  chains; sprite assets; kerning from GPOS and the legacy `kern` table.
- `TypesetterLabel` (TextMeshProUGUI) and `TypesetterText3D` (TextMeshPro): every
  documented rich-text tag, style sheets, colour gradients, all overflow modes,
  auto-size, pages, linked text, `max_visible_*`, preferred and rendered values,
  `text_info` with per-character mesh data, and `set_text` formatting.
- Distance-field shaders for 2D and 3D: face, outline, underlay (normal and inner),
  glow, bevel and lighting, with Mobile, Bitmap and MSDF variants and
  anti-aliasing that holds at any scale.
- `TypesetterInputField` and `TypesetterDropdown`.
- `TypesetterTextLayout` and `TypesetterTextStyle`: measure, lay out and draw text into
  any CanvasItem without a node, with fractional sizes (for godot-uxml).
- Editor tooling: the Font Asset Creator, font asset inspector, menu items and a 3D
  text gizmo.
- Prebuilt native libraries for Windows x86_64, Linux x86_64, macOS arm64 and the web
  (single-threaded wasm; export with Extensions Support on and Thread Support off).
- Validation against Unity TextMesh Pro's measured output: layout matches to 0.02
  units in 198 of 206 cases, atlases within 0.05 to 0.90 of 255, and rendered pixels
  within a median of 0.075 of 255 over 227 cases. Known gaps are listed in
  `docs/parity.md`.

### Performance

- Text changes cost about what Godot's `Label` does (within 20%) and a quarter of
  what `Label3D` does; meshes are rewritten in place when only the text changes.

[Unreleased]: https://github.com/splatterfacegames/godot-typesetter/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/splatterfacegames/godot-typesetter/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/splatterfacegames/godot-typesetter/releases/tag/v0.1.0
