#!/usr/bin/env python3
"""Convert decompiled UA sky folders into self-contained project sky bundles."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Iterable

try:
    from PIL import Image
except Exception:  # pragma: no cover - exercised in runtime environments without Pillow
    Image = None


class ConversionError(RuntimeError):
    """Raised when a sky bundle cannot be converted safely."""


def canonical_sky_id(raw_name: str) -> str:
    cleaned = raw_name.strip().replace("\\", "/")
    cleaned = cleaned.split("/")[-1]
    cleaned = re.sub(r"\.bas(?:e)?$", "", cleaned, flags=re.IGNORECASE)
    return cleaned.lower()


def _safe_texture_stem(name: str) -> str:
    stem = name.strip().replace("\\", "/").split("/")[-1]
    stem = re.sub(r"\.bmp$", "", stem, flags=re.IGNORECASE)
    return re.sub(r"[^a-z0-9]+", "_", stem.lower()).strip("_")


def _walk_key(node: Any, key: str) -> Iterable[Any]:
    if isinstance(node, dict):
        if key in node:
            yield node[key]
        for value in node.values():
            yield from _walk_key(value, key)
    elif isinstance(node, list):
        for item in node:
            yield from _walk_key(item, key)


def _find_first_name(node: Any, key: str) -> str:
    if isinstance(node, dict):
        if key in node and isinstance(node[key], dict):
            return str(node[key].get("name", ""))
        for value in node.values():
            found = _find_first_name(value, key)
            if found:
                return found
    elif isinstance(node, list):
        for item in node:
            found = _find_first_name(item, key)
            if found:
                return found
    return ""


def _find_first_points(node: Any, key: str) -> list[Any]:
    if isinstance(node, dict):
        if key in node and isinstance(node[key], dict):
            return list(node[key].get("points", []))
        for value in node.values():
            found = _find_first_points(value, key)
            if found:
                return found
    elif isinstance(node, list):
        for item in node:
            found = _find_first_points(item, key)
            if found:
                return found
    return []


def _find_first_poly_id(node: Any) -> int:
    if isinstance(node, dict):
        if "STRC" in node and isinstance(node["STRC"], dict):
            return int(node["STRC"].get("poly", -1))
        for value in node.values():
            found = _find_first_poly_id(value)
            if found >= 0:
                return found
    elif isinstance(node, list):
        for item in node:
            found = _find_first_poly_id(item)
            if found >= 0:
                return found
    return -1


def _find_first_skeleton_ref(node: Any) -> str:
    if isinstance(node, dict):
        if "SKLC" in node:
            return _find_first_name(node["SKLC"], "NAME")
        for value in node.values():
            found = _find_first_skeleton_ref(value)
            if found:
                return found
    elif isinstance(node, list):
        for item in node:
            found = _find_first_skeleton_ref(item)
            if found:
                return found
    return ""


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _resolve_child_case_insensitive(parent: Path, name: str) -> Path | None:
    target = name.lower()
    for child in parent.iterdir():
        if child.name.lower() == target:
            return child
    return None


def _resolve_sky_dir(source_root: Path, raw_name: str) -> Path:
    wanted = canonical_sky_id(raw_name)
    for child in source_root.iterdir():
        if child.is_dir() and canonical_sky_id(child.name) == wanted:
            return child
    raise ConversionError(f"Sky folder not found for '{raw_name}' under {source_root}")


def _resolve_texture_file(sky_dir: Path, texture_name: str) -> Path:
    candidates = {
        texture_name,
        f"{texture_name}.bmp",
        texture_name.replace(".ILBM", ".ilbm"),
        f"{texture_name}.bmp".replace(".ILBM", ".ilbm"),
    }
    lowered = {candidate.lower() for candidate in candidates}
    for child in sky_dir.iterdir():
        if child.is_file() and child.name.lower() in lowered:
            return child
    raise ConversionError(f"Missing referenced texture '{texture_name}' in {sky_dir}")


def _transform_points(raw_points: list[dict[str, Any]]) -> list[tuple[float, float, float]]:
    points: list[tuple[float, float, float]] = []
    for point in raw_points:
        points.append((
            float(point.get("x", 0.0)),
            -float(point.get("y", 0.0)),
            -float(point.get("z", 0.0)),
        ))
    return points


def _polygon_vertices(points: list[tuple[float, float, float]], polys: list[list[int]], poly_id: int) -> list[tuple[float, float, float]]:
    if poly_id < 0 or poly_id >= len(polys):
        raise ConversionError(f"Invalid polygon id {poly_id}")
    polygon: list[tuple[float, float, float]] = []
    for point_idx in polys[poly_id]:
        if point_idx < 0 or point_idx >= len(points):
            raise ConversionError(f"Invalid point index {point_idx} in polygon {poly_id}")
        polygon.append(points[point_idx])
    return polygon


def _uv_point_to_pair(item: Any) -> tuple[float, float] | None:
    if isinstance(item, dict):
        return float(item.get("x", 0.0)), float(item.get("y", 0.0))
    if isinstance(item, (list, tuple)) and len(item) >= 2:
        return float(item[0]), float(item[1])
    return None


def _coerce_uvs(raw_uvs: list[Any], polygon: list[tuple[float, float, float]], texture_size: tuple[int, int] | None) -> list[tuple[float, float]]:
    uvs: list[tuple[float, float]] = []
    width = max((texture_size or (256, 256))[0] - 1, 1)
    height = max((texture_size or (256, 256))[1] - 1, 1)
    for item in raw_uvs:
        pair = _uv_point_to_pair(item)
        if pair is not None:
            uvs.append((pair[0] / width, pair[1] / height))
    if len(uvs) == len(polygon):
        return uvs
    min_x = min(vertex[0] for vertex in polygon)
    max_x = max(vertex[0] for vertex in polygon)
    min_z = min(vertex[2] for vertex in polygon)
    max_z = max(vertex[2] for vertex in polygon)
    dx = max(max_x - min_x, 1.0)
    dz = max(max_z - min_z, 1.0)
    return [((vertex[0] - min_x) / dx, (vertex[2] - min_z) / dz) for vertex in polygon]


def _classify_family(canonical_id: str, skeleton_ref: str) -> str:
    if canonical_id == "nosky":
        return "nosky"
    skeleton_id = canonical_sky_id(Path(skeleton_ref).stem)
    if skeleton_id == "complete":
        return "complete"
    if skeleton_id == "horizon":
        return "horizon"
    return "custom"


def _copy_texture_to_png(src_path: Path, dst_path: Path) -> tuple[int, int]:
    if Image is None:
        raise ConversionError("Pillow is required for sky texture conversion (pip install pillow)")
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(src_path) as image:
        converted = image.convert("RGBA") if image.mode not in ("RGB", "RGBA") else image.copy()
        converted.save(dst_path, format="PNG")
        return converted.size


def _extract_area_surfaces(bas_data: Any) -> list[dict[str, Any]]:
    surfaces: list[dict[str, Any]] = []
    for area in _walk_key(bas_data, "AREA"):
        poly_id = _find_first_poly_id(area)
        texture_name = _find_first_name(area, "NAM2")
        raw_uvs = _find_first_points(area, "OTL2")
        if poly_id < 0:
            continue
        surfaces.append({
            "poly_id": poly_id,
            "texture_name": texture_name,
            "raw_uvs": raw_uvs,
        })
    return surfaces


def _write_obj_and_mtl(bundle_dir: Path, canonical_id: str, points: list[tuple[float, float, float]], surfaces: list[dict[str, Any]], texture_entries: dict[str, dict[str, Any]]) -> tuple[str, str]:
    mesh_dir = bundle_dir / "mesh"
    mesh_dir.mkdir(parents=True, exist_ok=True)
    obj_path = mesh_dir / "sky.obj"
    mtl_path = mesh_dir / "sky.mtl"

    material_names = {}
    for texture_name in texture_entries:
        material_names[texture_name] = f"mat_{_safe_texture_stem(texture_name)}"

    with mtl_path.open("w", encoding="utf-8") as handle:
        for texture_name, texture_info in texture_entries.items():
            handle.write(f"newmtl {material_names[texture_name]}\n")
            handle.write("Ka 1.000 1.000 1.000\n")
            handle.write("Kd 1.000 1.000 1.000\n")
            handle.write("Ks 0.000 0.000 0.000\n")
            handle.write("d 1.000\n")
            handle.write("illum 1\n")
            handle.write(f"map_Kd ../textures/{texture_info['bundle_file']}\n\n")

    vt_counter = 1
    with obj_path.open("w", encoding="utf-8") as handle:
        handle.write(f"mtllib {mtl_path.name}\n")
        handle.write(f"o sky_{canonical_id}\n")
        for x, y, z in points:
            handle.write(f"v {x:.6f} {y:.6f} {z:.6f}\n")
        for surface in surfaces:
            material_name = material_names[surface["texture_name"]]
            handle.write(f"usemtl {material_name}\n")
            local_vt_indices: list[int] = []
            for u, v in surface["uvs"]:
                handle.write(f"vt {u:.6f} {v:.6f}\n")
                local_vt_indices.append(vt_counter)
                vt_counter += 1
            face_tokens = [f"{point_idx + 1}/{vt_idx}" for point_idx, vt_idx in zip(surface["point_indices"], local_vt_indices)]
            handle.write(f"f {' '.join(face_tokens)}\n")

    return str(obj_path.relative_to(bundle_dir)).replace("\\", "/"), str(mtl_path.relative_to(bundle_dir)).replace("\\", "/")


def _write_scene(bundle_dir: Path, canonical_id: str, has_geometry: bool) -> str:
    scene_path = bundle_dir / "sky.tscn"
    res_path = f"res://resources/ua/sky/{canonical_id}/mesh/sky.obj"
    if has_geometry:
        content = (
            "[gd_scene load_steps=2 format=3]\n\n"
            f"[ext_resource type=\"Mesh\" path=\"{res_path}\" id=\"1_mesh\"]\n\n"
            "[node name=\"SkyRoot\" type=\"Node3D\"]\n\n"
            "[node name=\"SkyMesh\" type=\"MeshInstance3D\" parent=\".\"]\n"
            "mesh = ExtResource(\"1_mesh\")\n"
            "cast_shadow = 0\n"
        )
    else:
        content = "[gd_scene format=3]\n\n[node name=\"SkyRoot\" type=\"Node3D\"]\n"
    scene_path.write_text(content, encoding="utf-8")
    return "sky.tscn"


def _bounds_from_points(points: list[tuple[float, float, float]]) -> dict[str, list[float]]:
    if not points:
        return {"min": [0.0, 0.0, 0.0], "max": [0.0, 0.0, 0.0]}
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    zs = [point[2] for point in points]
    return {
        "min": [min(xs), min(ys), min(zs)],
        "max": [max(xs), max(ys), max(zs)],
    }


def convert_sky(raw_name: str, source_root: Path, output_root: Path) -> dict[str, Any]:
    sky_dir = _resolve_sky_dir(source_root, raw_name)
    bas_path = _resolve_child_case_insensitive(sky_dir, f"{sky_dir.name}.bas.json")
    if bas_path is None:
        bas_candidates = sorted(sky_dir.glob("*.bas.json"))
        if not bas_candidates:
            raise ConversionError(f"No BAS JSON found in {sky_dir}")
        bas_path = bas_candidates[0]
    bas_data = _load_json(bas_path)
    canonical_id = canonical_sky_id(bas_path.stem.replace(".bas", ""))
    skeleton_ref = _find_first_skeleton_ref(bas_data)
    if not skeleton_ref:
        raise ConversionError(f"No skeleton reference found in {bas_path}")
    skeleton_json_name = f"{Path(skeleton_ref).stem}.skl.json"
    skeleton_path = _resolve_child_case_insensitive(sky_dir, skeleton_json_name)
    if skeleton_path is None:
        raise ConversionError(f"Missing skeleton JSON '{skeleton_json_name}' in {sky_dir}")
    skeleton_data = _load_json(skeleton_path)
    raw_points = next((item.get("points", []) for item in _walk_key(skeleton_data, "POO2") if isinstance(item, dict)), [])
    raw_polys = next((item.get("edges", []) for item in _walk_key(skeleton_data, "POL2") if isinstance(item, dict)), [])
    points = _transform_points(raw_points)
    polys = [list(map(int, poly)) for poly in raw_polys]
    family = _classify_family(canonical_id, skeleton_ref)

    bundle_dir = output_root / canonical_id
    bundle_dir.mkdir(parents=True, exist_ok=True)

    texture_entries: dict[str, dict[str, Any]] = {}
    extracted_surfaces = _extract_area_surfaces(bas_data)
    compiled_surfaces: list[dict[str, Any]] = []

    for surface in extracted_surfaces:
        texture_name = str(surface.get("texture_name", ""))
        if not texture_name:
            raise ConversionError(f"AREA polygon {surface['poly_id']} in {canonical_id} has no texture binding")
        if texture_name not in texture_entries:
            src_texture = _resolve_texture_file(sky_dir, texture_name)
            bundle_file = f"{_safe_texture_stem(texture_name)}.png"
            size = _copy_texture_to_png(src_texture, bundle_dir / "textures" / bundle_file)
            texture_entries[texture_name] = {
                "source_name": texture_name,
                "source_file": src_texture.name,
                "bundle_file": bundle_file,
                "size": size,
            }
        point_indices = polys[surface["poly_id"]]
        polygon = _polygon_vertices(points, polys, surface["poly_id"])
        uvs = _coerce_uvs(surface.get("raw_uvs", []), polygon, texture_entries[texture_name]["size"])
        compiled_surfaces.append({
            "poly_id": surface["poly_id"],
            "texture_name": texture_name,
            "point_indices": point_indices,
            "uvs": uvs,
            "vertex_count": len(point_indices),
        })

    used_point_indices = sorted({point_idx for surface in compiled_surfaces for point_idx in surface.get("point_indices", [])})
    used_points = [points[idx] for idx in used_point_indices] if used_point_indices else []
    geometry_path = bundle_dir / "geometry.json"
    geometry_path.write_text(json.dumps({
        "points": [{"x": x, "y": y, "z": z} for x, y, z in points],
        "polygons": polys,
        "surfaces": compiled_surfaces,
    }, indent=2) + "\n", encoding="utf-8")

    mesh_paths: list[str] = []
    material_paths: list[str] = []
    if compiled_surfaces:
        obj_rel, mtl_rel = _write_obj_and_mtl(bundle_dir, canonical_id, points, compiled_surfaces, texture_entries)
        mesh_paths.append(obj_rel)
        material_paths.append(mtl_rel)
    scene_rel = _write_scene(bundle_dir, canonical_id, has_geometry=bool(compiled_surfaces))

    aliases = sorted({raw_name, sky_dir.name, bas_path.stem.replace(".bas", ""), canonical_id}, key=str.lower)
    manifest = {
        "canonical_id": canonical_id,
        "family": family,
        "aliases": aliases,
        "scene_path": f"res://resources/ua/sky/{canonical_id}/{scene_rel}",
        "mesh_paths": [f"res://resources/ua/sky/{canonical_id}/{path}" for path in mesh_paths],
        "material_paths": [f"res://resources/ua/sky/{canonical_id}/{path}" for path in material_paths],
        "geometry_path": f"res://resources/ua/sky/{canonical_id}/geometry.json",
        "textures": [
            {
                "source_name": entry["source_name"],
                "source_file": entry["source_file"],
                "bundle_path": f"res://resources/ua/sky/{canonical_id}/textures/{entry['bundle_file']}",
                "width": entry["size"][0],
                "height": entry["size"][1],
            }
            for entry in sorted(texture_entries.values(), key=lambda item: item["bundle_file"])
        ],
        "source_files": {
            "bas": bas_path.name,
            "skeleton": skeleton_path.name,
        },
        "bounds": _bounds_from_points(used_points),
        "flags": {
            "has_geometry": bool(compiled_surfaces),
            "double_sided": True,
            "uses_alpha": False,
            "unshaded": True,
        },
        "surface_count": len(compiled_surfaces),
        "polygon_count": len(polys),
        "vertex_count": len(points),
        "notes": [
            "Converted from development/debug sky references; runtime should load only project-owned bundle files.",
            "Geometry preserves UA-authored local X, flips source-down Y upward, and mirrors Z into the editor preview space.",
        ],
    }
    manifest_path = bundle_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def write_registry(output_root: Path, manifests: list[dict[str, Any]]) -> dict[str, Any]:
    registry_path = output_root / "registry.json"
    existing_entries: dict[str, Any] = {}
    if registry_path.exists():
        existing_data = _load_json(registry_path)
        existing_entries = dict(existing_data.get("entries", {}))
    for manifest in manifests:
        existing_entries[manifest["canonical_id"]] = {
            "family": manifest["family"],
            "aliases": manifest["aliases"],
            "manifest_path": f"res://resources/ua/sky/{manifest['canonical_id']}/manifest.json",
            "scene_path": manifest["scene_path"],
            "source_files": manifest["source_files"],
        }
    registry = {
        "version": 1,
        "entries": dict(sorted(existing_entries.items(), key=lambda item: item[0])),
    }
    registry_path.parent.mkdir(parents=True, exist_ok=True)
    registry_path.write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
    return registry


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert UA sky reference folders into self-contained project bundles")
    parser.add_argument(
        "--source-root",
        default="resources/ua/sky_import",
        help="Parent directory of per-sky asset folders (BAS/SKL); populate this or pass another path",
    )
    parser.add_argument("--output-root", default="resources/ua/sky", help="Project-owned converted sky bundle root")
    parser.add_argument("--skies", nargs="+", required=True, help="Sky names or canonical ids to convert")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_root = Path(args.source_root).resolve()
    output_root = Path(args.output_root).resolve()
    manifests = [convert_sky(name, source_root, output_root) for name in args.skies]
    registry = write_registry(output_root, manifests)
    print(f"[OK] Converted {len(manifests)} skies into {output_root}")
    print(f"[OK] Registry entries: {', '.join(registry['entries'].keys())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())