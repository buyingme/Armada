# Ship Maneuver obstacle contour evidence packet v3

Status: **FINAL OWNER-REVIEW CANDIDATE — CONTOUR GATE REMAINS STOPPED**

Evidence version: `obstacle-alpha-mask-contour-evidence-v3`

Canonical dataset SHA-256:
`edd2c9597e75a4a092b7c3cc9fe8b899d421b02720a8731b1eb5e6578f505eb0`

This packet supersedes the unapproved v2 candidate. Source files, coordinate
semantics, image-centre pivot, winding, contact policy, and the accepted
720-native-source-px/305-mm physical calibration are unchanged from v2.

## Extraction rule

For each PNG, decode all pixels with `alpha > 0`, partition them by
8-neighbour pixel connectivity, and retain only the largest connected
component as the physical token region. Component size descending determines
the main region; lexicographic minimum pixel coordinate is the deterministic
tie-breaker. No size threshold, hand-authored contour, manual dimension, or
geometry approximation is used.

Each retained pixel occupies its complete unit source-pixel cell. Exposed cell
edges are traced with the established deterministic right-turn rule and only
collinear intermediate vertices are removed. All other disconnected alpha
components are excluded before bounding boxes, dimensions, contours, physical
conversion, and canonical-world conversion are calculated.

The selected main component is identical under 4-neighbour and 8-neighbour
connectivity for all six source PNGs; the explicit 8-neighbour rule therefore
does not change which physical region is selected.

## Artifact exclusion evidence

| Obstacle | All alpha>0 pixels | Retained main-region pixels | Excluded pixels | Source components |
| --- | ---: | ---: | ---: | ---: |
| `asteroid_1` | 9,363 | 9,353 | 10 | 2 |
| `asteroid_2` | 12,798 | 12,796 | 2 | 2 |
| `asteroid_3` | 9,416 | 9,403 | 13 | 4 |
| `debris_1` | 17,181 | 17,146 | 35 | 6 |
| `debris_2` | 18,440 | 18,430 | 10 | 3 |
| `station` | 28,969 | 28,903 | 66 | 9 |

Every non-main disconnected component was excluded. The corrected overlays
retain the original PNG for visual comparison, draw a red boundary only around
the retained main region, and draw its bounding box in cyan. Detached alpha
artifacts remain visible in the underlying image where present but have no red
canonical-contour boundary and are absent from the dataset geometry.

## Final artifacts

- Dataset: `obstacle-alpha-contours-v3.json`
- Manifest: `evidence-manifest-v3.json`
- Combined overlay: `obstacle-alpha-contours-contact-sheet-v3.png`
- Individual overlays: `asteroid_1-alpha-contour-overlay-v3.png`,
  `asteroid_2-alpha-contour-overlay-v3.png`,
  `asteroid_3-alpha-contour-overlay-v3.png`,
  `debris_1-alpha-contour-overlay-v3.png`,
  `debris_2-alpha-contour-overlay-v3.png`, and
  `station-alpha-contour-overlay-v3.png`
- Reproducible generator: `generate_contour_evidence.py`

The manifest binds all six source PNGs and metadata, `scale_config.json`, the
generator, dataset, contact sheet, and individual overlays.

## Exact final Owner approval statement

> I approve `obstacle-alpha-mask-contour-evidence-v3`, dataset SHA-256
> `edd2c9597e75a4a092b7c3cc9fe8b899d421b02720a8731b1eb5e6578f505eb0`,
> as the canonical obstacle contour dataset for WP3b and WP4. I approve its
> largest-8-connected-component extraction of the main alpha-greater-than-zero
> physical token region, exclusion of every disconnected alpha artifact, six
> cited source PNGs and metadata, accepted 720-native-source-px/305-mm physical
> calibration, conversion through the existing `GameScale` ruler calibration,
> image-centre pivot, top-left source origin, +x-right/+y-down axes,
> clockwise-positive placement rotation, ring winding, deterministic
> pixel-cell contour method, and boundary-only-contact-is-not-overlap policy.
> The current numerical equality between a native source-pixel span and
> canonical world-unit span remains calibration-derived and does not create a
> source-pixel-to-game-pixel or rendering-pixel identity convention. The STOP
> FOR OWNER CONTOUR APPROVAL gate is passed for this exact version and hash.

Until the Owner records that statement, the gate remains
**STOP FOR OWNER CONTOUR APPROVAL** and no contour-gated implementation resumes.
