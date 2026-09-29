#!/usr/bin/env python3
"""F-PE-ELASTIC12D target-blind predictor extraction for five low-stress targets."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

ALLOWED_IDENTITY_KEYS = {
    "bro_id", "determination_index", "step_index", "route",
    "stress_start_kpa", "stress_end_kpa",
}
FORBIDDEN_TARGET_TOKENS = (
    "ssk", "mv_pa", "delta_strain", "strain_start", "strain_end",
    "endpoint_secant",
)


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ancestor(parent, node, wanted):
    x = node
    while x is not None:
        if local(x.tag) == wanted:
            return x
        x = parent.get(x)
    return None


def unique_source_values(scope, name):
    values = []
    for e in scope.iter():
        if local(e.tag) != name:
            continue
        raw = (e.text or "").strip()
        if not raw:
            continue
        unit = e.attrib.get("uom")
        item = (raw, unit)
        if item not in values:
            values.append(item)
    return values


def bind_water_content(interval):
    vals = unique_source_values(interval, "waterContent")
    if not vals:
        return {"status": "MISSING", "value": None, "raw_values": [], "unit": "%"}
    if len(vals) != 1:
        return {
            "status": "AMBIGUOUS",
            "value": None,
            "raw_values": [{"raw": r, "unit": u} for r, u in vals],
            "unit": "%",
        }
    raw, unit = vals[0]
    if unit != "%":
        raise RuntimeError(f"waterContent unit {unit!r}, expected '%'")
    try:
        value = float(raw)
    except ValueError as e:
        raise RuntimeError(f"non-numeric waterContent {raw!r}") from e
    if not math.isfinite(value) or value <= 0.0:
        return {
            "status": "MISSING" if value == 0.0 else "AMBIGUOUS",
            "value": None,
            "raw_values": [{"raw": raw, "unit": unit}],
            "unit": unit,
        }
    return {
        "status": "ASSIGNED",
        "value": value,
        "raw_values": [{"raw": raw, "unit": unit}],
        "unit": unit,
    }


def project_identities(targets):
    out = []
    for row in targets:
        # Hard target-blind projection: only these keys are retained.
        missing = ALLOWED_IDENTITY_KEYS - set(row)
        if missing:
            raise RuntimeError(f"target identity missing {sorted(missing)}")
        ident = {k: row[k] for k in sorted(ALLOWED_IDENTITY_KEYS)}
        out.append(ident)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--objects", required=True)
    ap.add_argument("--candidates", required=True)
    ap.add_argument("--targets", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    objects = Path(a.objects)
    candidates = json.loads(Path(a.candidates).read_text())
    targets = json.loads(Path(a.targets).read_text())

    if candidates.get("candidate_count") != 5 or len(candidates.get("candidates", [])) != 5:
        raise SystemExit("F_PE_ELASTIC12D_FAIL candidate authority count")
    if not isinstance(targets, list) or len(targets) != 5:
        raise SystemExit("F_PE_ELASTIC12D_FAIL target count")

    identities = project_identities(targets)
    ident_by = {(r["bro_id"], int(r["determination_index"]), int(r["step_index"])): r for r in identities}
    cand_by = {
        (r["bro_id"], int(r["determination_index"]), int(r["step_index"])): r
        for r in candidates["candidates"]
    }
    if set(ident_by) != set(cand_by):
        raise RuntimeError("target/candidate identity set mismatch")

    rows = []
    for key in sorted(ident_by):
        ident = ident_by[key]
        cand = cand_by[key]
        bro_id, di, si = key
        if ident["route"] != "R3" or cand["route"] != "R3":
            raise RuntimeError(f"non-R3 candidate {bro_id}")

        p = objects / f"{bro_id}.response"
        if not p.exists():
            raise RuntimeError(f"missing frozen object {bro_id}")
        if p.stat().st_size != int(cand["object_size_bytes"]):
            raise RuntimeError(f"object size mismatch {bro_id}")
        got = sha256(p)
        if got != cand["object_sha256"]:
            raise RuntimeError(f"object SHA mismatch {bro_id}")

        root = ET.fromstring(p.read_bytes())
        parent = {c: q for q in root.iter() for c in q}
        dets = [e for e in root.iter() if local(e.tag) == "SettlementCharacteristicsDetermination"]
        if not (1 <= di <= len(dets)):
            raise RuntimeError(f"determination index missing {bro_id}/{di}")
        det = dets[di - 1]
        interval = ancestor(parent, det, "investigatedInterval")
        if interval is None:
            raise RuntimeError(f"no investigatedInterval {bro_id}/{di}")

        water = bind_water_content(interval)
        s0 = float(ident["stress_start_kpa"])
        s1 = float(ident["stress_end_kpa"])
        sm = 0.5 * (s0 + s1)
        if not (math.isfinite(sm) and sm > 0.0):
            raise RuntimeError(f"invalid stress midpoint {bro_id}")

        rows.append({
            "bro_id": bro_id,
            "determination_index": di,
            "step_index": si,
            "route": "R3",
            "object_sha256": got,
            "object_size_bytes": p.stat().st_size,
            "stress_start_kpa": s0,
            "stress_end_kpa": s1,
            "stress_midpoint_kpa": sm,
            "water_content_pct": water["value"],
            "water_content_status": water["status"],
            "water_content_unit": water["unit"],
            "water_content_raw_values": water["raw_values"],
        })

    # No target-magnitude field is permitted in predictor output.
    keys = {k.lower() for r in rows for k in r}
    leaked = sorted(k for k in keys if any(tok in k for tok in FORBIDDEN_TARGET_TOKENS))
    if leaked:
        raise RuntimeError(f"target magnitude leakage {leaked}")

    assigned = sum(r["water_content_status"] == "ASSIGNED" for r in rows)
    if assigned != 5:
        raise SystemExit(f"F_PE_ELASTIC12D_FAIL water predictor assigned {assigned}/5")

    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "predictors.json").write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n")
    (out / "identity_projection.json").write_text(json.dumps(identities, indent=2, sort_keys=True) + "\n")

    print("F_PE_ELASTIC12D_PREDICTOR_ROWS=5")
    print("F_PE_ELASTIC12D_WATER_ASSIGNED=5/5")
    print("F_PE_ELASTIC12D_NO_TARGET_LEAKAGE=PASS")
    print("F_PE_ELASTIC12D_PREDICTOR_EXTRACTION=PASS")


if __name__ == "__main__":
    main()
