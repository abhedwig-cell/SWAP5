#!/usr/bin/env python3
"""F-PE-ELASTIC12C deterministic low-stress R3 mechanical target extraction."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path

GAMMA_W = 9806.65
THRESHOLD_KPA = 25.0
RECORD_NAME = "StressAtSpecificSettlement.xml"


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def text(e) -> str:
    return (e.text or "").strip()


def finite_float(value):
    try:
        x = float(value)
    except (TypeError, ValueError):
        return None
    return x if math.isfinite(x) else None


def descendants(e, name):
    return [x for x in e.iter() if local(x.tag) == name]


def step_type_tokens(step):
    out = []
    for e in descendants(step, "stepType"):
        if text(e):
            out.append(text(e))
        for k, v in e.attrib.items():
            if local(k).lower() == "href":
                out.append(v.rsplit("/", 1)[-1])
    return out


def is_unload(step):
    return any("ontlast" in x.lower() or "unload" in x.lower() for x in step_type_tokens(step))


def parse_stress_series(step):
    blocks = []
    for block in descendants(step, "stressChangeDuringSettlement"):
        hrefs = []
        for e in block.iter():
            for k, v in e.attrib.items():
                if local(k).lower() == "href":
                    hrefs.append(v)
        if not any(x.endswith(RECORD_NAME) for x in hrefs):
            continue
        enc = next((e for e in block.iter() if local(e.tag) == "TextEncoding"), None)
        values = next((text(e) for e in block.iter() if local(e.tag) == "values" and text(e)), None)
        if enc is None or values is None:
            continue
        if (
            enc.attrib.get("decimalSeparator", ".") != "."
            or enc.attrib.get("tokenSeparator", ",") != ","
            or enc.attrib.get("blockSeparator", " ") != " "
        ):
            raise RuntimeError(f"unsupported SWE encoding: {enc.attrib}")
        rows = []
        for rec in values.split(" "):
            rec = rec.strip()
            if not rec:
                continue
            parts = rec.split(",")
            if len(parts) != 5:
                raise RuntimeError(f"{RECORD_NAME}: expected 5 columns, got {len(parts)}")
            rows.append([finite_float(x) for x in parts])
        blocks.append({"rows": rows, "hrefs": hrefs})
    if len(blocks) != 1:
        raise RuntimeError(f"expected exactly one {RECORD_NAME} block, got {len(blocks)}")
    return blocks[0]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ols_diagnostic(rows):
    # x = effective stress Pa; y = vertical strain fraction.
    xs = [r[3] * 1000.0 for r in rows]
    ys = [r[1] / 100.0 for r in rows]
    n = len(xs)
    mx = sum(xs) / n
    my = sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx <= 0.0:
        return {"ols_slope_pa_inv": None, "ols_r2": None}
    slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx
    intercept = my - slope * mx
    sst = sum((y - my) ** 2 for y in ys)
    ssr = sum((y - (intercept + slope * x)) ** 2 for x, y in zip(xs, ys))
    r2 = None if sst <= 0.0 else 1.0 - ssr / sst
    return {"ols_slope_pa_inv": slope, "ols_r2": r2}


def extract_candidate(source: Path, cand):
    bro_id = cand["bro_id"]
    path = source / "objects" / f"{bro_id}.response"
    if not path.exists():
        raise RuntimeError(f"missing frozen object bytes {bro_id}")
    if path.stat().st_size != int(cand["object_size_bytes"]):
        raise RuntimeError(f"object size mismatch {bro_id}")
    got = sha256(path)
    if got != cand["object_sha256"]:
        raise RuntimeError(f"object SHA mismatch {bro_id}: {got}")

    root = ET.fromstring(path.read_bytes())
    dets = [e for e in root.iter() if local(e.tag) == "SettlementCharacteristicsDetermination"]
    di = int(cand["determination_index"])
    if di < 1 or di > len(dets):
        raise RuntimeError(f"determination index missing {bro_id}/{di}")
    det = dets[di - 1]
    steps = [e for e in det.iter() if local(e.tag) == "determinationStep"]
    si = int(cand["step_index"])
    if si < 1 or si > len(steps):
        raise RuntimeError(f"step index missing {bro_id}/{di}/{si}")
    step = steps[si - 1]
    if not is_unload(step):
        raise RuntimeError(f"frozen step is no longer explicit unload {bro_id}/{di}/{si}")

    block = parse_stress_series(step)
    valid = [r for r in block["rows"] if r[1] is not None and r[3] is not None]
    selected = [r for r in valid if r[3] > 0.0 and r[3] <= THRESHOLD_KPA]
    distinct = sorted({r[3] for r in selected if r[3] > 0.0})

    if len(block["rows"]) != int(cand["series_row_count"]):
        raise RuntimeError(f"series row-count identity mismatch {bro_id}")
    if len(valid) != int(cand["valid_row_count"]):
        raise RuntimeError(f"valid row-count identity mismatch {bro_id}")
    if len(selected) != int(cand["local_row_count"]):
        raise RuntimeError(f"local row-count identity mismatch {bro_id}")
    if len(selected) < 3 or len(distinct) < 2:
        raise RuntimeError(f"low-stress structural gate failed {bro_id}")

    mn = min(r[3] for r in selected)
    mx = max(r[3] for r in selected)
    if abs(mn - float(cand["min_effective_stress_kpa"])) > 1.0e-12:
        raise RuntimeError(f"minimum stress identity mismatch {bro_id}")
    if abs(mx - float(cand["max_effective_stress_kpa"])) > 1.0e-12:
        raise RuntimeError(f"maximum stress identity mismatch {bro_id}")

    first = selected[0]
    last = selected[-1]
    sigma0, sigma1 = first[3], last[3]
    eps0, eps1 = first[1], last[1]
    delta_sigma_pa = (sigma1 - sigma0) * 1000.0
    delta_eps = (eps1 - eps0) / 100.0

    if not (math.isfinite(delta_sigma_pa) and delta_sigma_pa != 0.0):
        raise RuntimeError(f"zero/nonfinite low-stress stress secant {bro_id}")
    if not (math.isfinite(delta_eps) and delta_eps != 0.0):
        raise RuntimeError(f"zero/nonfinite low-stress strain secant {bro_id}")

    signed_slope = delta_eps / delta_sigma_pa
    mv = abs(signed_slope)
    ssk_m = GAMMA_W * mv
    ssk_cm = ssk_m / 100.0
    if not (math.isfinite(mv) and mv > 0.0 and math.isfinite(ssk_cm) and ssk_cm > 0.0):
        raise RuntimeError(f"invalid low-stress target {bro_id}")

    out = {
        "bro_id": bro_id,
        "object_sha256": got,
        "object_size_bytes": path.stat().st_size,
        "route": "R3",
        "determination_index": di,
        "step_index": si,
        "step_type_tokens": step_type_tokens(step),
        "threshold_kpa": THRESHOLD_KPA,
        "series_row_count": len(block["rows"]),
        "valid_row_count": len(valid),
        "selected_row_count": len(selected),
        "distinct_positive_stress_count": len(distinct),
        "selected_min_stress_kpa": mn,
        "selected_max_stress_kpa": mx,
        "stress_start_kpa": sigma0,
        "stress_end_kpa": sigma1,
        "strain_start_pct": eps0,
        "strain_end_pct": eps1,
        "abs_stress_span_kpa": abs(sigma1 - sigma0),
        "abs_strain_span_pct": abs(eps1 - eps0),
        "delta_stress_pa_signed": delta_sigma_pa,
        "delta_strain_fraction_signed": delta_eps,
        "endpoint_secant_signed_pa_inv": signed_slope,
        "mv_pa_inv": mv,
        "ssk_m_inv": ssk_m,
        "ssk_cm_inv": ssk_cm,
    }
    out.update(ols_diagnostic(selected))
    return out


def write_csv(path, rows):
    keys = sorted({k for r in rows for k in r})
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for row in rows:
            cooked = {
                k: json.dumps(v, separators=(",", ":"), sort_keys=True)
                if isinstance(v, (list, dict))
                else v
                for k, v in row.items()
            }
            w.writerow(cooked)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--candidates", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    auth = json.loads(Path(a.candidates).read_text())
    if auth.get("candidate_count") != 5 or len(auth.get("candidates", [])) != 5:
        raise SystemExit("F_PE_ELASTIC12C_FAIL frozen candidate count mismatch")
    if auth.get("source_artifact_id") != 11018544503:
        raise SystemExit("F_PE_ELASTIC12C_FAIL source artifact mismatch")

    outdir = Path(a.out)
    outdir.mkdir(parents=True, exist_ok=True)

    targets = []
    failures = []
    for cand in auth["candidates"]:
        try:
            targets.append(extract_candidate(Path(a.source), cand))
        except Exception as e:
            failures.append({
                "bro_id": cand["bro_id"],
                "reason": type(e).__name__,
                "detail": str(e),
            })

    targets.sort(key=lambda x: x["bro_id"])
    failures.sort(key=lambda x: x["bro_id"])

    vals = sorted(x["ssk_cm_inv"] for x in targets)
    median = None
    if vals:
        n = len(vals)
        median = vals[n // 2] if n % 2 else 0.5 * (vals[n // 2 - 1] + vals[n // 2])

    if len(targets) == 5:
        classification = "LOW_STRESS_TARGET_SET_QUALIFIED"
    elif len(targets) >= 3:
        classification = "LOW_STRESS_TARGET_SET_PARTIAL"
    else:
        classification = "LOW_STRESS_TARGET_EXTRACTION_BLOCKED"

    summary = {
        "work_unit": "F-PE-ELASTIC12C",
        "source_workflow_run": auth["source_workflow_run"],
        "source_artifact_id": auth["source_artifact_id"],
        "source_artifact_sha256": auth["source_artifact_sha256"],
        "frozen_candidate_count": 5,
        "valid_target_count": len(targets),
        "failure_count": len(failures),
        "classification": classification,
        "ssk_cm_inv_min": min(vals) if vals else None,
        "ssk_cm_inv_median": median,
        "ssk_cm_inv_max": max(vals) if vals else None,
    }

    (outdir / "targets.json").write_text(json.dumps(targets, indent=2, sort_keys=True) + "\n")
    (outdir / "failures.json").write_text(json.dumps(failures, indent=2, sort_keys=True) + "\n")
    (outdir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    if targets:
        write_csv(outdir / "targets.csv", targets)

    print(f"F_PE_ELASTIC12C_VALID_TARGETS={len(targets)}/5")
    print(f"F_PE_ELASTIC12C_FAILURES={len(failures)}")
    print("F_PE_ELASTIC12C_SSK_CM_INV_RANGE=" + json.dumps({
        "min": summary["ssk_cm_inv_min"],
        "median": summary["ssk_cm_inv_median"],
        "max": summary["ssk_cm_inv_max"],
    }, separators=(",", ":")))
    print(f"F_PE_ELASTIC12C_CLASSIFICATION={classification}")

    if classification == "LOW_STRESS_TARGET_EXTRACTION_BLOCKED":
        raise SystemExit("F_PE_ELASTIC12C_FAIL fewer than 3 valid targets")
    if failures:
        print("F_PE_ELASTIC12C_PARTIAL=YES")
    print("F_PE_ELASTIC12C=PASS")


if __name__ == "__main__":
    main()
