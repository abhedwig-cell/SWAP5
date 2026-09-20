#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib


def load_core(path: pathlib.Path):
    spec = importlib.util.spec_from_file_location("c6c_core", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load core qualifier: {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--core", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--c6b", required=True, type=pathlib.Path)
    ap.add_argument("--shard-index", required=True, type=int)
    ap.add_argument("--shard-count", required=True, type=int)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    a = ap.parse_args()

    if a.shard_count <= 0 or not (0 <= a.shard_index < a.shard_count):
        raise SystemExit("invalid shard geometry")

    core = load_core(a.core)
    p = json.loads(a.prereg.read_text())
    b = json.loads(a.c6b.read_text())
    assert p["phase"] == "PREREGISTERED_BEFORE_BEMR_NUMERICAL_RESPONSE"
    assert b["adjudication"]["MATHEMATICAL_QUALIFICATION_AUTHORIZED"] is True
    assert p["scientific_firewall"]["hydrological_response_used"] is False

    cases = core.build_cases(p)
    rows = []
    for idx, case in enumerate(cases):
        if idx % a.shard_count != a.shard_index:
            continue
        row = core.qualify_case(case, p)
        row["case_index"] = idx
        rows.append(row)

    out = {
        "schema": "swap5.lare.bc2.c6c.shard.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-C6C",
        "shard_index": a.shard_index,
        "shard_count": a.shard_count,
        "total_case_count": len(cases),
        "case_count": len(rows),
        "rows": rows,
        "scientific_firewall": {
            "hydrological_response_used": False,
            "model_run_executed": False,
            "response_based_profile_fit": False,
            "c5z_post_result_retuning": False,
        },
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "shard_index": a.shard_index,
        "shard_count": a.shard_count,
        "case_count": len(rows),
        "first_case_index": rows[0]["case_index"] if rows else None,
        "last_case_index": rows[-1]["case_index"] if rows else None,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
