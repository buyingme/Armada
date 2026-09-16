# Ship Maneuver obstacle contour evidence packet v2

Status: **SUPERSEDED UNAPPROVED REVIEW CANDIDATE — SEE v3**

Evidence version: `obstacle-alpha-mask-contour-evidence-v2`

Canonical dataset SHA-256:
`33e6b6ab10ef38e101ef2de585c56d7bad69bd9bb4a705e47d66ff1ee6dd5df6`

This packet was superseded by `contour-evidence-packet-v3.md` after Owner review
excluded disconnected alpha artifacts from the physical token region. It is
retained only as review history and cannot pass the contour gate. It applied the
Owner decisions that every source-PNG pixel with alpha greater than zero
belongs to the physical obstacle footprint and that 720 native obstacle
source-image pixels represent 305 mm. It is evidence for the Section 18 gate;
it neither approves the dataset nor activates contour-gated work.

## 1. Sources and provenance

| Obstacle | Authoritative PNG | Metadata | PNG SHA-256 |
| --- | --- | --- | --- |
| `asteroid_1` | `Resources/Game_Components/obstacles/asteroid_1_token.png` | `Resources/Game_Components/obstacles/asteroid_1.json` | `b65874ebd4256f999901572e3e7e10a7ccede74b8ee2e9e072742354423c9695` |
| `asteroid_2` | `Resources/Game_Components/obstacles/asteroid_2_token.png` | `Resources/Game_Components/obstacles/asteroid_2.json` | `e8fde346457bb1a0da982dc7da537dcdcc69b69d8db0a65a2f6733d002f13a57` |
| `asteroid_3` | `Resources/Game_Components/obstacles/asteroid_3_token.png` | `Resources/Game_Components/obstacles/asteroid_3.json` | `a82a6a42ff502349f3810ed9b81f84e8a941ead53e4d6176ed9af404e3d45c24` |
| `debris_1` | `Resources/Game_Components/obstacles/debris_1_token.png` | `Resources/Game_Components/obstacles/debris_1.json` | `a2a44ed5ad933b3e1e2589199d0d6ecb5635fc741422814a2e467cdafc7dde3c` |
| `debris_2` | `Resources/Game_Components/obstacles/debris_2_token.png` | `Resources/Game_Components/obstacles/debris_2.json` | `33c9df7f85f953419ac77c658e9311b6e081ab7f80068e977eddd9091f0065e4` |
| `station` | `Resources/Game_Components/obstacles/station_token.png` | `Resources/Game_Components/obstacles/station.json` | `5cefad6d148529530015fc87a2ebfe03f78422d5557f40bd34b3fc4a1ccfad05` |

Scale authority:
`Resources/Game_Components/scale/scale_config.json`, SHA-256
`26ce69c992e139fb1d491d06c8239abfb8f95bf1ea9af9d39f56a1c40c9dc297`.
The obstacle metadata's `oriented_box`, `SPRITE_BOUNDS_FACTOR`, and
`squadron_base_diameter_px` values are approximate presentation data and are
not used for canonical geometry or scale.

## 2. Scale conversion and canonical units

The three domains remain distinct:

1. Owner source calibration:
   `1 native source px = 305/720 mm = 0.423611111111… mm`.
2. Existing `GameScale` calibration from `scale_config.json`:
   `1 mm = 720/305 canonical world units = 2.360655737705… units`.
3. Therefore canonical geometry is derived through physical length:
   `source px × (305 mm / 720 source px) × (720 world units / 305 mm)`.

At the current accepted configuration the composed factor is numerically
`1.0 canonical world unit/native source px`. This cancellation is not a 1:1
source-pixel-to-game-pixel or rendering convention. The dataset records both
calibrations and the conversion chain so a changed working ruler resolution is
derived through millimetres rather than silently treated as pixel identity.

Canonical contour vertices are serialized in all three useful forms: exact
integer source-pixel edges, physical millimetres, and current canonical world
units. Gameplay installation must consume the canonical world-unit data or
derive it from the recorded physical values through `GameScale`; rendering
scale remains presentation-only.

## 3. Coordinate, pivot, orientation, and contact semantics

- Source origin is the PNG top-left pixel edge; `+x` is right and `+y` is down.
- The local pivot is the image-rectangle centre `(width/2, height/2)`,
  preserving the repository placement convention. Placement rotates about
  that pivot by `rotation_deg`; positive rotation is visually clockwise in
  Godot's y-down 2D coordinates.
- Outer rings are clockwise in y-down coordinates; holes are
  counter-clockwise.
- Overlap requires positive shared area. Boundary-only contact is not overlap.
- Derivation uses integer pixel-cell edges and no floating tolerance. Runtime
  intersection must use the workbook's deterministic numeric policy without
  changing the accepted footprint.

## 4. Deterministic contour method

Each decoded PNG pixel with `alpha > 0` occupies its complete unit cell;
`alpha == 0` does not. The generator emits exposed cell edges, traces rings
with occupied cells on the right, applies a fixed right-turn rule at diagonal
contacts, and removes only collinear intermediate vertices. This preserves
holes and detached non-transparent islands exactly. It performs no rectangle
substitution, oriented-box approximation, hand tracing, smoothing, alpha
threshold adjustment, or runtime mask extraction.

## 5. Alpha-footprint dimensions

These are the axis-aligned local alpha bounding-box dimensions before placement
rotation. Millimetres use the Owner's `305/720` calibration.

| Obstacle | Alpha bbox (source px) | Physical width × height (mm) | Current canonical width × height (world units) |
| --- | ---: | ---: | ---: |
| `asteroid_1` | 162 × 78 | 68.625000 × 33.041667 | 162 × 78 |
| `asteroid_2` | 129 × 144 | 54.645833 × 61.000000 | 129 × 144 |
| `asteroid_3` | 130 × 105 | 55.069444 × 44.479167 | 130 × 105 |
| `debris_1` | 176 × 183 | 74.555556 × 77.520833 | 176 × 183 |
| `debris_2` | 169 × 166 | 71.590278 × 70.319444 | 169 × 166 |
| `station` | 210 × 201 | 88.958333 × 85.145833 | 210 × 201 |

The full dataset also records PNG dimensions, half-open alpha bounding boxes,
pivot-relative extents, non-transparent pixel counts, rings, winding, and all
vertices in source, physical, and canonical units.

## 6. Final review artifacts

- Dataset: `obstacle-alpha-contours-v2.json`
- Hash manifest: `evidence-manifest-v2.json`
- Combined overlay: `obstacle-alpha-contours-contact-sheet-v2.png`
- Individual overlays: `asteroid_1-alpha-contour-overlay-v2.png`,
  `asteroid_2-alpha-contour-overlay-v2.png`,
  `asteroid_3-alpha-contour-overlay-v2.png`,
  `debris_1-alpha-contour-overlay-v2.png`,
  `debris_2-alpha-contour-overlay-v2.png`, and
  `station-alpha-contour-overlay-v2.png`
- Reproducible generator: `generate_contour_evidence.py`

The manifest binds all source PNGs and metadata, `scale_config.json`, the
generator, dataset, contact sheet, and individual overlays. The dataset hash is
the SHA-256 of canonical UTF-8 JSON bytes with sorted keys, compact separators,
and a terminal newline.

## 7. Exact final Owner approval statement

> I approve `obstacle-alpha-mask-contour-evidence-v2`, dataset SHA-256
> `33e6b6ab10ef38e101ef2de585c56d7bad69bd9bb4a705e47d66ff1ee6dd5df6`,
> as the canonical obstacle contour dataset for WP3b and WP4. I approve its six
> cited source PNGs and metadata, alpha-greater-than-zero footprints,
> 720-native-source-px/305-mm physical calibration, conversion through the
> existing `GameScale` ruler calibration into canonical world units,
> image-centre pivot, top-left source origin, +x-right/+y-down axes,
> clockwise-positive placement rotation, ring winding, physical dimensions,
> deterministic pixel-cell contour method, and boundary-only-contact-is-not-
> overlap policy. The current numerical equality between a native source-pixel
> span and canonical world-unit span is calibration-derived and does not create
> a source-pixel-to-game-pixel or rendering-pixel identity convention. The STOP
> FOR OWNER CONTOUR APPROVAL gate is passed for this exact version and hash.

Until the Owner records that statement, the gate remains
**STOP FOR OWNER CONTOUR APPROVAL** and no contour-gated implementation resumes.
