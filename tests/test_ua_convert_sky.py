from __future__ import annotations

import json
import shutil
from pathlib import Path

import pytest

from scripts.ua_convert_sky import ConversionError, convert_sky, write_registry


REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = REPO_ROOT / "resources" / "ua" / "sky_import"
RUNTIME_ROOT = REPO_ROOT / "resources" / "ua" / "sky"


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_convert_complete_sky_writes_bundle_and_manifest(tmp_path: Path) -> None:
    manifest = convert_sky("1998_01", SOURCE_ROOT, tmp_path)

    bundle_dir = tmp_path / "1998_01"
    assert manifest["family"] == "complete"
    assert manifest["flags"]["has_geometry"] is True
    assert manifest["surface_count"] == 74
    assert len(manifest["textures"]) == 2
    assert (bundle_dir / "mesh" / "sky.obj").exists()
    assert (bundle_dir / "mesh" / "sky.mtl").exists()
    assert (bundle_dir / "sky.tscn").exists()

    geometry = _load_json(bundle_dir / "geometry.json")
    assert len(geometry["polygons"]) == 74
    assert geometry["surfaces"][0]["vertex_count"] == 3


def test_convert_representative_family_batch_writes_registry(tmp_path: Path) -> None:
    manifests = [
        convert_sky("am_1", SOURCE_ROOT, tmp_path),
        convert_sky("asky2", SOURCE_ROOT, tmp_path),
        convert_sky("nosky", SOURCE_ROOT, tmp_path),
    ]
    registry = write_registry(tmp_path, manifests)

    assert registry["entries"]["am_1"]["family"] == "horizon"
    assert registry["entries"]["asky2"]["family"] == "custom"
    assert registry["entries"]["nosky"]["family"] == "nosky"

    asky2_geometry = _load_json(tmp_path / "asky2" / "geometry.json")
    assert {surface["vertex_count"]
            for surface in asky2_geometry["surfaces"]} == {4}

    nosky_manifest = _load_json(tmp_path / "nosky" / "manifest.json")
    assert nosky_manifest["flags"]["has_geometry"] is False
    assert nosky_manifest["mesh_paths"] == []
    assert nosky_manifest["textures"] == []


def test_convert_additional_known_skies_across_remaining_families(tmp_path: Path) -> None:
    manifests = [
        convert_sky("1998_02", SOURCE_ROOT, tmp_path),
        convert_sky("am_2", SOURCE_ROOT, tmp_path),
        convert_sky("sterne", SOURCE_ROOT, tmp_path),
    ]

    assert [manifest["family"]
            for manifest in manifests] == ["complete", "horizon", "custom"]
    assert manifests[0]["surface_count"] > 0
    assert manifests[1]["surface_count"] > 0
    assert manifests[2]["surface_count"] > 0
    assert len(manifests[2]["textures"]) == 1


def test_repo_registry_covers_all_known_source_sky_dirs() -> None:
    registry = _load_json(RUNTIME_ROOT / "registry.json")
    source_ids = {path.name.lower()
                  for path in SOURCE_ROOT.iterdir() if path.is_dir()}
    runtime_ids = set(registry["entries"].keys())

    assert runtime_ids == source_ids
    for sky_id in ("1998_02", "am_2", "sterne", "nosky"):
        manifest_path = RUNTIME_ROOT / sky_id / "manifest.json"
        assert manifest_path.exists(), f"Missing runtime manifest for {sky_id}"


def test_convert_sky_fails_when_referenced_texture_is_missing(tmp_path: Path) -> None:
    broken_root = tmp_path / "broken_source"
    shutil.copytree(SOURCE_ROOT / "1998_01", broken_root / "1998_01")
    (broken_root / "1998_01" / "NEWSKY1.ILBM.bmp").unlink()

    with pytest.raises(ConversionError, match="Missing referenced texture"):
        convert_sky("1998_01", broken_root, tmp_path / "out")
