from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

RESEARCH_HEAD = "04807fdcf45453a59b7f6c99fe97f1286c172833"
AUTHORITY_PATH = Path("integration/f-ross/F-ROSS13_36_MATERIAL_N241_FINGERPRINT_AUTHORITY.json")
TABLE_N = 241
TABLE_WORDS = TABLE_N * TABLE_N
MAGIC = "ROSSFAST_D3R_TABLE_V1"


def load_generator(research_root: Path):
    exp = research_root / "experiments" / "ross"
    sys.path.insert(0, str(exp))
    import run_ross01_gate_j1a_real_table_face_derivative as j1a
    return j1a


def load_authority() -> dict:
    authority = json.loads(AUTHORITY_PATH.read_text())
    if authority.get("research_head") != RESEARCH_HEAD:
        raise RuntimeError(("research authority mismatch", authority.get("research_head")))
    if authority.get("material_count") != 36 or not authority.get("all_holdout_materials_passed"):
        raise RuntimeError("36-material holdout authority is not complete and passing")
    return authority


def main() -> int:
    authority = load_authority()
    fingerprints = authority["fingerprints"]

    p = argparse.ArgumentParser()
    p.add_argument("--research-root", type=Path, required=True)
    p.add_argument("--material", required=True, choices=tuple(sorted(fingerprints)))
    p.add_argument("--asset-out", type=Path, required=True)
    p.add_argument("--metadata-out", type=Path, required=True)
    a = p.parse_args()

    j1a = load_generator(a.research_root)
    catalog = json.loads(
        (a.research_root / "integration" / "f-ross" / "F-ROSS01_GATE_C1_MATERIAL_CATALOG.json").read_text()
    )
    by_name = {row["sfu"]: row for row in catalog["rows"]}
    row = by_name[a.material]
    j1a.c1r.base.c1.configure_core(row)
    table, elapsed, failures = j1a.c1r.base.generate_table(j1a.N)
    if failures:
        raise RuntimeError(("table generation failures", a.material, failures[:8]))
    if table.shape != (TABLE_N, TABLE_N) or table.dtype != np.float32:
        raise RuntimeError(("unexpected table representation", table.shape, table.dtype))

    c_sha = hashlib.sha256(table.tobytes(order="C")).hexdigest()
    expected = fingerprints[a.material]
    if c_sha != expected:
        raise RuntimeError(("qualified table identity mismatch", a.material, expected, c_sha))

    words = table.flatten(order="F").view(np.uint32)
    a.asset_out.parent.mkdir(parents=True, exist_ok=True)
    with a.asset_out.open("w", encoding="ascii", newline="\n") as f:
        f.write(f"{MAGIC} {a.material} {TABLE_N} {TABLE_WORDS}\n")
        for word in words:
            f.write(f"{int(word):08X}\n")

    asset_bytes = a.asset_out.read_bytes()
    metadata = {
        "schema_version": 1,
        "work_unit": "F-ROSS13",
        "kind": "QUALIFIED_ROSSFAST_D3R_TABLE_ASSET_SHARD",
        "material": a.material,
        "research_head": RESEARCH_HEAD,
        "historical_holdout_run": authority["source_run"],
        "research_table_c_order_sha256": c_sha,
        "asset_format": "ASCII_HEADER_PLUS_IEEE_BINARY32_HEX_WORDS_FORTRAN_ORDER",
        "asset_magic": MAGIC,
        "table_n": TABLE_N,
        "word_count": TABLE_WORDS,
        "asset_sha256": hashlib.sha256(asset_bytes).hexdigest(),
        "asset_size_bytes": len(asset_bytes),
        "preprocessing_seconds_descriptive": elapsed,
    }
    a.metadata_out.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(metadata, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
