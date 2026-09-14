from __future__ import annotations

import argparse
import json
from pathlib import Path

MATERIALS = ("B01", "B12", "O01", "O05", "O14", "O18")
RESEARCH_HEAD = "04807fdcf45453a59b7f6c99fe97f1286c172833"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--shards", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    records = {}
    for material in MATERIALS:
        matches = list(a.shards.rglob(f"ross04-{material}.json"))
        if len(matches) != 1:
            raise RuntimeError(("expected one shard", material, [str(x) for x in matches]))
        record = json.loads(matches[0].read_text())
        if record.get("material") != material:
            raise RuntimeError(("material mismatch", material, record.get("material")))
        if record.get("research_head") != RESEARCH_HEAD:
            raise RuntimeError(("research head mismatch", material, record.get("research_head")))
        records[material] = record

    manifest = {
        "schema_version": 1,
        "work_unit": "F-ROSS04",
        "kind": "QUALIFIED_ROSSFAST_D3R_TABLE_ASSET_REGISTRY",
        "research_head": RESEARCH_HEAD,
        "materials": list(MATERIALS),
        "asset_root": "assets/rossfast/d3r",
        "runtime_generation": False,
        "entries": {
            material: {
                "path": f"assets/rossfast/d3r/{material}_log_mobility_f32.hex",
                "research_table_c_order_sha256": records[material]["research_table_c_order_sha256"],
                "asset_sha256": records[material]["asset_sha256"],
                "asset_size_bytes": records[material]["asset_size_bytes"],
                "table_n": records[material]["table_n"],
                "word_count": records[material]["word_count"],
                "format": records[material]["asset_format"],
            }
            for material in MATERIALS
        },
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"materials": list(MATERIALS), "pass": True}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
