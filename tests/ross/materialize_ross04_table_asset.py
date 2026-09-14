from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

EXPECTED_C_ORDER_SHA256 = {
    "B01": "5d0a78c6b5e240589210c5e6efa28be890ffa53179e7952a29e23f5c4335ffb4",
    "B12": "a40e2bdbb6708a16dd3675d1a7f67d443de13505418a15ffa1478752dd2ceb2a",
    "O01": "e2b2a6ff34855b3104c0a9683edfe6585ac16c47c4a12c5239c03a132af202d0",
    "O05": "d9fb067f5861abdec568ab4382825d79ac6c1e3fc0499d7d6e6a78df94a87a79",
    "O14": "f56deba9b912103e465a96e264f9ba984780720e6bd2ef7fa5a8f46e5f4236d6",
    "O18": "2e76bcd89820099a222983cc3b788f274c9f5f12155dcb7c3698c00a7eec71b5",
}

RESEARCH_HEAD = "04807fdcf45453a59b7f6c99fe97f1286c172833"
TABLE_N = 241
TABLE_WORDS = TABLE_N * TABLE_N
MAGIC = "ROSSFAST_D3R_TABLE_V1"


def load_generator(research_root: Path):
    exp = research_root / "experiments" / "ross"
    sys.path.insert(0, str(exp))
    import run_ross01_gate_j1a_real_table_face_derivative as j1a
    return j1a


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--research-root", type=Path, required=True)
    p.add_argument("--material", required=True, choices=tuple(EXPECTED_C_ORDER_SHA256))
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
    if c_sha != EXPECTED_C_ORDER_SHA256[a.material]:
        raise RuntimeError(("qualified table identity mismatch", a.material, c_sha))

    # Serialize IEEE binary32 words in Fortran array traversal order. Hex words
    # avoid any dependency on host byte order while preserving every float bit.
    words = table.flatten(order="F").view(np.uint32)
    a.asset_out.parent.mkdir(parents=True, exist_ok=True)
    with a.asset_out.open("w", encoding="ascii", newline="\n") as f:
        f.write(f"{MAGIC} {a.material} {TABLE_N} {TABLE_WORDS}\n")
        for word in words:
            f.write(f"{int(word):08X}\n")

    asset_bytes = a.asset_out.read_bytes()
    metadata = {
        "schema_version": 1,
        "work_unit": "F-ROSS04",
        "kind": "QUALIFIED_ROSSFAST_D3R_TABLE_ASSET_SHARD",
        "material": a.material,
        "research_head": RESEARCH_HEAD,
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
