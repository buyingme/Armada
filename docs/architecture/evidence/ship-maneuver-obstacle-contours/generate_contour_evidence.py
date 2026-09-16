#!/usr/bin/env python3
"""Generate deterministic alpha-mask contour evidence for core obstacles.

This is documentation evidence tooling. It reads source PNG/JSON/scale data and
writes only the evidence dataset and review overlays beside this script.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
SOURCE_DIR = ROOT / "Resources/Game_Components/obstacles"
SCALE_PATH = ROOT / "Resources/Game_Components/scale/scale_config.json"
OUTPUT_DIR = Path(__file__).resolve().parent
DATASET_PATH = OUTPUT_DIR / "obstacle-alpha-contours-v3.json"
MANIFEST_PATH = OUTPUT_DIR / "evidence-manifest-v3.json"
CONTACT_SHEET_PATH = OUTPUT_DIR / "obstacle-alpha-contours-contact-sheet-v3.png"
KEYS = ("asteroid_1", "asteroid_2", "asteroid_3", "debris_1", "debris_2", "station")
VERSION = "obstacle-alpha-mask-contour-evidence-v3"


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_json_bytes(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def boundary_edges(mask: set[tuple[int, int]]) -> list[tuple[tuple[int, int], tuple[int, int]]]:
    edges: list[tuple[tuple[int, int], tuple[int, int]]] = []
    for x, y in sorted(mask, key=lambda p: (p[1], p[0])):
        if (x, y - 1) not in mask:
            edges.append(((x, y), (x + 1, y)))
        if (x + 1, y) not in mask:
            edges.append(((x + 1, y), (x + 1, y + 1)))
        if (x, y + 1) not in mask:
            edges.append(((x + 1, y + 1), (x, y + 1)))
        if (x - 1, y) not in mask:
            edges.append(((x, y + 1), (x, y)))
    return edges


def main_connected_component(mask: set[tuple[int, int]]) -> tuple[set[tuple[int, int]], int]:
    """Return the largest 8-connected alpha component and component count."""
    unseen = set(mask)
    components: list[set[tuple[int, int]]] = []
    neighbours = (
        (-1, -1), (0, -1), (1, -1),
        (-1, 0),           (1, 0),
        (-1, 1),  (0, 1),  (1, 1),
    )
    while unseen:
        seed = min(unseen)
        unseen.remove(seed)
        component = {seed}
        pending = [seed]
        while pending:
            x, y = pending.pop()
            for dx, dy in neighbours:
                adjacent = (x + dx, y + dy)
                if adjacent in unseen:
                    unseen.remove(adjacent)
                    component.add(adjacent)
                    pending.append(adjacent)
        components.append(component)
    # Size determines the physical main region. Lexicographic minimum is only
    # a deterministic tie-breaker and does not impose a size threshold.
    components.sort(key=lambda component: (-len(component), min(component)))
    return components[0], len(components)


def direction(edge: tuple[tuple[int, int], tuple[int, int]]) -> int:
    (x1, y1), (x2, y2) = edge
    return {(1, 0): 0, (0, 1): 1, (-1, 0): 2, (0, -1): 3}[(x2 - x1, y2 - y1)]


def trace_rings(edges: list[tuple[tuple[int, int], tuple[int, int]]]) -> list[list[tuple[int, int]]]:
    outgoing: dict[tuple[int, int], list[tuple[tuple[int, int], tuple[int, int]]]] = {}
    for edge in edges:
        outgoing.setdefault(edge[0], []).append(edge)
    unused = set(edges)
    rings: list[list[tuple[int, int]]] = []
    while unused:
        first = min(unused)
        ring = [first[0]]
        edge = first
        while True:
            unused.remove(edge)
            ring.append(edge[1])
            if edge[1] == first[0]:
                break
            candidates = [item for item in outgoing.get(edge[1], []) if item in unused]
            if not candidates:
                raise RuntimeError(f"Open contour at {edge[1]}")
            incoming = direction(edge)
            # In y-down coordinates, keep occupied cells on the right. At a
            # diagonal corner, prefer a right turn so point-touching regions
            # remain separate instead of inventing a connecting edge.
            priority = {1: 0, 0: 1, 3: 2, 2: 3}
            edge = min(candidates, key=lambda item: (priority[(direction(item) - incoming) % 4], item))
        rings.append(simplify_collinear(ring))
    return sorted(rings, key=lambda ring: (-abs(signed_area2(ring)), ring))


def simplify_collinear(ring: list[tuple[int, int]]) -> list[tuple[int, int]]:
    points = ring[:-1]
    changed = True
    while changed and len(points) > 4:
        changed = False
        kept: list[tuple[int, int]] = []
        for index, point in enumerate(points):
            before = points[index - 1]
            after = points[(index + 1) % len(points)]
            if (before[0] == point[0] == after[0]) or (before[1] == point[1] == after[1]):
                changed = True
                continue
            kept.append(point)
        points = kept
    return points + [points[0]]


def signed_area2(ring: list[tuple[int, int]]) -> int:
    return sum(
        ring[index][0] * ring[index + 1][1] - ring[index + 1][0] * ring[index][1]
        for index in range(len(ring) - 1)
    )


def converted_vertices(ring: list[tuple[int, int]], factor: float) -> list[list[float]]:
    return [[round(x * factor, 12), round(y * factor, 12)] for x, y in ring]


def overlay(source: Image.Image, rings: list[list[tuple[int, int]]], box: tuple[int, int, int, int], key: str) -> Image.Image:
    scale = 4
    width, height = source.size
    canvas = Image.new("RGBA", (width * scale, height * scale), (32, 34, 40, 255))
    draw = ImageDraw.Draw(canvas)
    tile = 8 * scale
    for y in range(0, canvas.height, tile):
        for x in range(0, canvas.width, tile):
            shade = 54 if (x // tile + y // tile) % 2 == 0 else 72
            draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(shade, shade, shade, 255))
    rendered = source.resize(canvas.size, Image.Resampling.NEAREST)
    canvas.alpha_composite(rendered)
    draw = ImageDraw.Draw(canvas)
    for ring in rings:
        draw.line([(x * scale, y * scale) for x, y in ring], fill=(255, 48, 48, 255), width=2)
    x0, y0, x1, y1 = box
    draw.rectangle((x0 * scale, y0 * scale, x1 * scale, y1 * scale), outline=(0, 255, 255, 255), width=2)
    cx, cy = width * scale / 2.0, height * scale / 2.0
    draw.line((cx - 12, cy, cx + 12, cy), fill=(255, 0, 255, 255), width=2)
    draw.line((cx, cy - 12, cx, cy + 12), fill=(255, 0, 255, 255), width=2)
    draw.rectangle((0, 0, canvas.width, 18), fill=(0, 0, 0, 210))
    draw.text((4, 3), f"{key}: red main alpha component; cyan retained bbox; magenta pivot", fill="white", font=ImageFont.load_default())
    return canvas.convert("RGB")


def main() -> None:
    scale_config = json.loads(SCALE_PATH.read_text())
    ruler_px = float(scale_config["ruler_total_length_px"])
    ruler_mm = float(scale_config["physical_dimensions_mm"]["ruler_length"])
    mm_per_source_px = ruler_mm / ruler_px
    world_units_per_mm = ruler_px / ruler_mm
    world_units_per_source_px = mm_per_source_px * world_units_per_mm
    records = []
    overlay_paths = []
    source_manifest = {}
    for key in KEYS:
        metadata_path = SOURCE_DIR / f"{key}.json"
        metadata = json.loads(metadata_path.read_text())
        image_path = SOURCE_DIR / metadata["token_image"]
        image = Image.open(image_path).convert("RGBA")
        alpha = image.getchannel("A")
        all_alpha_pixels = {
            (x, y) for y in range(image.height) for x in range(image.width)
            if alpha.getpixel((x, y)) > 0
        }
        if not all_alpha_pixels:
            raise RuntimeError(f"Empty alpha footprint: {image_path}")
        mask, component_count = main_connected_component(all_alpha_pixels)
        x_values = [point[0] for point in mask]
        y_values = [point[1] for point in mask]
        box = (min(x_values), min(y_values), max(x_values) + 1, max(y_values) + 1)
        edges = boundary_edges(mask)
        rings = trace_rings(edges)
        if sum(len(ring) - 1 for ring in rings) > len(edges):
            raise RuntimeError(f"Invalid simplified contour: {key}")
        overlay_path = OUTPUT_DIR / f"{key}-alpha-contour-overlay-v3.png"
        overlay(image, rings, box, key).save(overlay_path, optimize=False)
        overlay_paths.append(overlay_path)
        source_manifest[str(image_path.relative_to(ROOT))] = sha256_bytes(image_path.read_bytes())
        source_manifest[str(metadata_path.relative_to(ROOT))] = sha256_bytes(metadata_path.read_bytes())
        width, height = image.size
        x0, y0, x1, y1 = box
        records.append({
            "data_key": key,
            "source_png": str(image_path.relative_to(ROOT)),
            "source_metadata": str(metadata_path.relative_to(ROOT)),
            "source_png_sha256": source_manifest[str(image_path.relative_to(ROOT))],
            "image_size_source_px": {"width": width, "height": height},
            "image_centre_pivot_source_px": {"x": width / 2.0, "y": height / 2.0},
            "alpha_bbox_half_open_source_px": {"x_min": x0, "y_min": y0, "x_max": x1, "y_max": y1},
            "alpha_footprint_size_source_px": {"width": x1 - x0, "height": y1 - y0},
            "alpha_footprint_size_physical_mm": {
                "width": round((x1 - x0) * mm_per_source_px, 12),
                "height": round((y1 - y0) * mm_per_source_px, 12),
            },
            "alpha_footprint_size_canonical_world_units": {
                "width": round((x1 - x0) * world_units_per_source_px, 12),
                "height": round((y1 - y0) * world_units_per_source_px, 12),
            },
            "alpha_footprint_extents_from_pivot_source_px": {
                "left": x0 - width / 2.0,
                "top": y0 - height / 2.0,
                "right": x1 - width / 2.0,
                "bottom": y1 - height / 2.0,
            },
            "nontransparent_pixel_count": len(mask),
            "all_nontransparent_pixel_count": len(all_alpha_pixels),
            "disconnected_component_count": component_count,
            "excluded_disconnected_pixel_count": len(all_alpha_pixels) - len(mask),
            "boundary_edge_count_before_collinear_reduction": len(edges),
            "rings": [
                {
                    "winding_y_down": "clockwise_outer" if signed_area2(ring) > 0 else "counterclockwise_hole",
                    "signed_area2_source_px": signed_area2(ring),
                    "vertices_source_pixel_edges": [[x, y] for x, y in ring],
                    "vertices_physical_mm": converted_vertices(ring, mm_per_source_px),
                    "vertices_canonical_world_units": converted_vertices(
                        ring, world_units_per_source_px),
                }
                for ring in rings
            ],
            "overlay": str(overlay_path.relative_to(ROOT)),
        })
    source_manifest[str(SCALE_PATH.relative_to(ROOT))] = sha256_bytes(SCALE_PATH.read_bytes())
    source_manifest[str(Path(__file__).resolve().relative_to(ROOT))] = sha256_bytes(
        Path(__file__).read_bytes())
    dataset = {
        "dataset_version": VERSION,
        "status": "OWNER_REVIEW_CANDIDATE_NOT_APPROVED",
        "alpha_rule": "within the largest 8-connected alpha > 0 component, each pixel occupies its full unit source-pixel cell; all other disconnected alpha components and all alpha == 0 pixels are excluded",
        "component_rule": "largest 8-connected non-transparent component; component size descending with lexicographic minimum coordinate as deterministic tie-breaker; no size threshold",
        "source_coordinate_system": "origin top-left; +x right; +y down; unit coordinates are PNG pixel edges",
        "pivot": "image rectangle centre; metadata does not declare a pivot; this preserves the repository placement convention",
        "rotation": "placement rotation_deg about pivot; +degrees follow Godot 2D y-down clockwise visual convention",
        "contact_policy": "positive-area intersection is overlap; boundary-only contact is not overlap",
        "lossless_contour_method": "directed exposed edges of retained main-component unit pixel cells; right-turn tie rule; collinear vertices removed only",
        "source_image_physical_calibration": {
            "owner_decision": "720 native obstacle source-image px = 305 mm",
            "native_source_px": ruler_px,
            "physical_mm": ruler_mm,
            "mm_per_native_source_px": mm_per_source_px,
        },
        "canonical_game_scale": {
            "authority": str(SCALE_PATH.relative_to(ROOT)),
            "ruler_working_resolution_units": ruler_px,
            "ruler_physical_mm": ruler_mm,
            "canonical_world_units_per_mm": world_units_per_mm,
        },
        "conversion_chain": "native source px * (305 physical mm / 720 native source px) * (720 canonical world units / 305 physical mm)",
        "canonical_world_units_per_native_source_px_at_current_scale": world_units_per_source_px,
        "conversion_note": "The current numeric factor is 1.0 because the independently stated source-image calibration and current canonical ruler calibration cancel; this is not a source-pixel-to-render/game-pixel identity convention.",
        "obstacles": records,
    }
    dataset_bytes = canonical_json_bytes(dataset)
    DATASET_PATH.write_bytes(dataset_bytes)
    source_manifest[str(DATASET_PATH.relative_to(ROOT))] = sha256_bytes(dataset_bytes)

    thumbs = [Image.open(path).convert("RGB") for path in overlay_paths]
    cell_w = max(image.width for image in thumbs)
    cell_h = max(image.height for image in thumbs)
    sheet = Image.new("RGB", (cell_w * 2, cell_h * 3), (20, 22, 28))
    for index, image in enumerate(thumbs):
        sheet.paste(image, ((index % 2) * cell_w, (index // 2) * cell_h))
    sheet.save(CONTACT_SHEET_PATH, optimize=False)
    source_manifest[str(CONTACT_SHEET_PATH.relative_to(ROOT))] = sha256_bytes(CONTACT_SHEET_PATH.read_bytes())
    for path in overlay_paths:
        source_manifest[str(path.relative_to(ROOT))] = sha256_bytes(path.read_bytes())
    manifest = {
        "evidence_version": VERSION,
        "dataset_sha256": sha256_bytes(dataset_bytes),
        "files_sha256": dict(sorted(source_manifest.items())),
    }
    MANIFEST_PATH.write_bytes(canonical_json_bytes(manifest))


if __name__ == "__main__":
    main()
