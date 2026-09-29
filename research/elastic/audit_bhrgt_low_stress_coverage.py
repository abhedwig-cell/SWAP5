#!/usr/bin/env python3
"""F-PE-ELASTIC12B frozen low-stress BHR-GT coverage audit.

This workunit inventories whether the preregistered 86-object BHR-GT population
contains explicit unload/reload evidence local to <=25 kPa (primary) or <=50 kPa
(diagnostic). It does not calculate any mechanical slope, Ssk or ELAS value.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BASE = "https://publiek.broservices.nl/sr/bhrgt/v2"
USER_AGENT = "SWAP5-F-PE-ELASTIC12B/0.1 research reproducibility"
EXPECTED_COUNT = 86
THRESHOLDS = (25.0, 50.0)


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


def scalar(step, name):
    for e in descendants(step, name):
        x = finite_float(text(e))
        if x is not None:
            return x
    return None


def parse_series(step, element_name, record_name, ncol):
    blocks = []
    for block in descendants(step, element_name):
        hrefs = []
        for e in block.iter():
            for k, v in e.attrib.items():
                if local(k).lower() == "href":
                    hrefs.append(v)
        if not any(x.endswith(record_name) for x in hrefs):
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
            raise RuntimeError(f"unsupported SWE encoding for {record_name}: {enc.attrib}")
        rows = []
        for rec in values.split(" "):
            rec = rec.strip()
            if not rec:
                continue
            parts = rec.split(",")
            if len(parts) != ncol:
                raise RuntimeError(f"{record_name}: expected {ncol} columns, got {len(parts)}")
            rows.append([finite_float(x) for x in parts])
        blocks.append({"rows": rows, "hrefs": hrefs})
    if len(blocks) > 1:
        raise RuntimeError(f"multiple {element_name} blocks within one determination step")
    return blocks[0] if blocks else None


def fetch(url: str, attempts: int = 3, timeout: float = 30.0):
    last = None
    for i in range(attempts):
        req = Request(
            url,
            headers={
                "User-Agent": USER_AGENT,
                "Accept": "application/xml, */*;q=0.1",
            },
            method="GET",
        )
        try:
            with urlopen(req, timeout=timeout) as r:
                return int(r.status), r.headers.get("Content-Type", ""), r.read()
        except HTTPError as e:
            return int(e.code), e.headers.get("Content-Type", ""), e.read()
        except URLError as e:
            last = e
            if i + 1 < attempts:
                time.sleep(0.5 * (i + 1))
    raise RuntimeError(f"network failure for {url}: {last}")


def manifest(url, status, ctype, data):
    return {
        "retrieved_utc": datetime.now(timezone.utc).isoformat(),
        "url": url,
        "http_status": status,
        "content_type": ctype,
        "size_bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def finite_r2_endpoint(step):
    stress = scalar(step, "verticalStress")
    block = parse_series(step, "heightChangeDuringSettlement", "HeightAtSpecificState.xml", 2)
    valid = [] if block is None else [r for r in block["rows"] if r[1] is not None]
    return {
        "stress": stress,
        "strain": valid[-1][1] if valid else None,
        "series_rows": len(block["rows"]) if block else 0,
        "valid_strain_rows": len(valid),
    }


def r3_rows(step):
    block = parse_series(step, "stressChangeDuringSettlement", "StressAtSpecificSettlement.xml", 5)
    if block is None:
        return None, []
    # [elapsedTime, verticalStrain, excessPoreWaterPressure,
    #  verticalEffectiveStress, horizontalEffectiveStress]
    valid = [r for r in block["rows"] if r[1] is not None and r[3] is not None]
    return block, valid


def candidate_record(bro_id, di, si, route, threshold, evidence):
    return {
        "bro_id": bro_id,
        "determination_index": di,
        "step_index": si,
        "route": route,
        "threshold_kpa": threshold,
        **evidence,
    }


def inspect_object(bro_id: str, root: ET.Element):
    dets = [e for e in root.iter() if local(e.tag) == "SettlementCharacteristicsDetermination"]
    stats = {
        "bro_id": bro_id,
        "settlement_determination_count": len(dets),
        "r2_determination_count": 0,
        "r3_determination_count": 0,
        "unload_step_count": 0,
        "loading_only_low_stress_observations_25": 0,
        "loading_only_low_stress_observations_50": 0,
        "min_unload_stress_kpa": None,
        "ls25_touch": False,
        "ls25_local": False,
        "ls50_transition": False,
    }
    candidates = []
    touch_records = []

    for di, det in enumerate(dets, 1):
        steps = [e for e in det.iter() if local(e.tag) == "determinationStep"]
        stress_blocks = [parse_series(s, "stressChangeDuringSettlement", "StressAtSpecificSettlement.xml", 5) for s in steps]
        route = "R3" if any(x is not None for x in stress_blocks) else "R2"
        stats["r3_determination_count" if route == "R3" else "r2_determination_count"] += 1

        if route == "R2":
            endpoints = [finite_r2_endpoint(s) for s in steps]
            for si, (step, ep) in enumerate(zip(steps, endpoints), 1):
                unload = is_unload(step)
                if unload:
                    stats["unload_step_count"] += 1
                    stress = ep["stress"]
                    if stress is not None:
                        stats["min_unload_stress_kpa"] = (
                            stress
                            if stats["min_unload_stress_kpa"] is None
                            else min(stats["min_unload_stress_kpa"], stress)
                        )
                        for threshold in THRESHOLDS:
                            if stress <= threshold:
                                touch_records.append(candidate_record(
                                    bro_id, di, si, route, threshold,
                                    {
                                        "criterion": f"LS{int(threshold)}_TOUCH",
                                        "unload_endpoint_stress_kpa": stress,
                                        "unload_series_row_count": ep["series_rows"],
                                    },
                                ))
                                if threshold == 25.0:
                                    stats["ls25_touch"] = True
                    if si == 1:
                        continue
                    prev = endpoints[si - 2]
                    if None in (prev["stress"], prev["strain"], ep["stress"], ep["strain"]):
                        continue
                    midpoint = 0.5 * (prev["stress"] + ep["stress"])
                    for threshold in THRESHOLDS:
                        if midpoint <= threshold:
                            rec = candidate_record(
                                bro_id, di, si, route, threshold,
                                {
                                    "criterion": f"LS{int(threshold)}_LOCAL",
                                    "previous_step_index": si - 1,
                                    "stress_start_kpa": prev["stress"],
                                    "stress_end_kpa": ep["stress"],
                                    "stress_midpoint_kpa": midpoint,
                                    "previous_series_row_count": prev["series_rows"],
                                    "unload_series_row_count": ep["series_rows"],
                                },
                            )
                            candidates.append(rec)
                            if threshold == 25.0:
                                stats["ls25_local"] = True
                            else:
                                stats["ls50_transition"] = True
                else:
                    stress = ep["stress"]
                    if stress is not None:
                        if stress <= 25.0:
                            stats["loading_only_low_stress_observations_25"] += 1
                        if stress <= 50.0:
                            stats["loading_only_low_stress_observations_50"] += 1
            continue

        # R3: effective-stress series is authoritative.
        for si, (step, block) in enumerate(zip(steps, stress_blocks), 1):
            unload = is_unload(step)
            valid = [] if block is None else [r for r in block["rows"] if r[1] is not None and r[3] is not None]
            if unload:
                stats["unload_step_count"] += 1
                stresses = [r[3] for r in valid]
                if stresses:
                    mn = min(stresses)
                    stats["min_unload_stress_kpa"] = (
                        mn if stats["min_unload_stress_kpa"] is None else min(stats["min_unload_stress_kpa"], mn)
                    )
                    for threshold in THRESHOLDS:
                        subset = [r for r in valid if r[3] <= threshold]
                        if subset:
                            touch_records.append(candidate_record(
                                bro_id, di, si, route, threshold,
                                {
                                    "criterion": f"LS{int(threshold)}_TOUCH",
                                    "min_unload_effective_stress_kpa": min(r[3] for r in subset),
                                    "series_row_count": len(block["rows"]) if block else 0,
                                    "valid_row_count": len(valid),
                                    "rows_at_or_below_threshold": len(subset),
                                },
                            ))
                            if threshold == 25.0:
                                stats["ls25_touch"] = True
                        positive = {r[3] for r in subset if r[3] > 0.0}
                        if len(subset) >= 3 and len(positive) >= 2:
                            rec = candidate_record(
                                bro_id, di, si, route, threshold,
                                {
                                    "criterion": f"LS{int(threshold)}_LOCAL",
                                    "min_effective_stress_kpa": min(r[3] for r in subset),
                                    "max_effective_stress_kpa": max(r[3] for r in subset),
                                    "series_row_count": len(block["rows"]) if block else 0,
                                    "valid_row_count": len(valid),
                                    "local_row_count": len(subset),
                                    "distinct_positive_stress_count": len(positive),
                                },
                            )
                            candidates.append(rec)
                            if threshold == 25.0:
                                stats["ls25_local"] = True
                            else:
                                stats["ls50_transition"] = True
            else:
                for r in valid:
                    if r[3] <= 25.0:
                        stats["loading_only_low_stress_observations_25"] += 1
                    if r[3] <= 50.0:
                        stats["loading_only_low_stress_observations_50"] += 1

    return stats, candidates, touch_records


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--population", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    pop = json.loads(Path(a.population).read_text())
    if pop.get("unique_object_count") != EXPECTED_COUNT or len(pop.get("objects", [])) != EXPECTED_COUNT:
        raise SystemExit("F_PE_ELASTIC12B_FAIL frozen population count mismatch")
    ids = [x["bro_id"] for x in pop["objects"]]
    if len(set(ids)) != EXPECTED_COUNT:
        raise SystemExit("F_PE_ELASTIC12B_FAIL duplicate frozen BRO IDs")

    out = Path(a.out)
    rawdir = out / "objects"
    rawdir.mkdir(parents=True, exist_ok=True)

    fetch_records = []
    object_stats = []
    candidates = []
    touches = []
    failures = []

    for i, bro_id in enumerate(ids, 1):
        url = f"{BASE}/objects/{bro_id}"
        try:
            status, ctype, data = fetch(url)
            m = manifest(url, status, ctype, data)
            m["bro_id"] = bro_id
            fetch_records.append(m)
            (rawdir / f"{bro_id}.response").write_bytes(data)
            (rawdir / f"{bro_id}.manifest.json").write_text(json.dumps(m, indent=2, sort_keys=True) + "\n")
            if status != 200:
                failures.append({"bro_id": bro_id, "reason": "HTTP", "status": status})
                continue
            root = ET.fromstring(data)
            s, c, t = inspect_object(bro_id, root)
            object_stats.append(s)
            candidates.extend(c)
            touches.extend(t)
        except Exception as e:
            failures.append({"bro_id": bro_id, "reason": type(e).__name__, "detail": str(e)})
        print(f"F_PE_ELASTIC12B_FETCH_PROGRESS={i}/{EXPECTED_COUNT}|BRO_ID={bro_id}")

    object_stats.sort(key=lambda x: x["bro_id"])
    candidates.sort(key=lambda x: (x["threshold_kpa"], x["bro_id"], x["determination_index"], x["step_index"], x["route"]))
    touches.sort(key=lambda x: (x["threshold_kpa"], x["bro_id"], x["determination_index"], x["step_index"], x["route"]))

    local25_objects = sorted({x["bro_id"] for x in candidates if x["threshold_kpa"] == 25.0})
    local50_objects = sorted({x["bro_id"] for x in candidates if x["threshold_kpa"] == 50.0})
    touch25_objects = sorted({x["bro_id"] for x in touches if x["threshold_kpa"] == 25.0})
    touch50_objects = sorted({x["bro_id"] for x in touches if x["threshold_kpa"] == 50.0})

    if failures:
        classification = "INCOMPLETE"
    elif len(local25_objects) >= 3:
        classification = "LOW_STRESS_TARGET_ROUTE_CONFIRMED"
    elif len(local25_objects) >= 1:
        classification = "LOW_STRESS_TARGET_ROUTE_SPARSE"
    elif touch25_objects:
        classification = "LOW_STRESS_TOUCH_ONLY"
    else:
        classification = "LOW_STRESS_MECHANICAL_BLOCKER"

    summary = {
        "work_unit": "F-PE-ELASTIC12B",
        "population_authority": {
            "source_workflow_run": pop["source_workflow_run"],
            "source_artifact_id": pop["source_artifact_id"],
            "source_artifact_sha256": pop["source_artifact_sha256"],
            "frozen_object_count": EXPECTED_COUNT,
        },
        "fetch_success_count": EXPECTED_COUNT - len(failures),
        "fetch_failure_count": len(failures),
        "settlement_determination_count": sum(x["settlement_determination_count"] for x in object_stats),
        "r2_determination_count": sum(x["r2_determination_count"] for x in object_stats),
        "r3_determination_count": sum(x["r3_determination_count"] for x in object_stats),
        "unload_step_count": sum(x["unload_step_count"] for x in object_stats),
        "loading_only_low_stress_observations_25": sum(x["loading_only_low_stress_observations_25"] for x in object_stats),
        "loading_only_low_stress_observations_50": sum(x["loading_only_low_stress_observations_50"] for x in object_stats),
        "ls25_touch_object_count": len(touch25_objects),
        "ls25_touch_objects": touch25_objects,
        "ls25_local_object_count": len(local25_objects),
        "ls25_local_objects": local25_objects,
        "ls50_transition_object_count": len(local50_objects),
        "ls50_transition_objects": local50_objects,
        "ls50_touch_object_count": len(touch50_objects),
        "ls50_touch_objects": touch50_objects,
        "classification": classification,
    }

    (out / "fetches.json").write_text(json.dumps(fetch_records, indent=2, sort_keys=True) + "\n")
    (out / "failures.json").write_text(json.dumps(failures, indent=2, sort_keys=True) + "\n")
    (out / "objects.json").write_text(json.dumps(object_stats, indent=2, sort_keys=True) + "\n")
    (out / "touches.json").write_text(json.dumps(touches, indent=2, sort_keys=True) + "\n")
    (out / "candidates.json").write_text(json.dumps(candidates, indent=2, sort_keys=True) + "\n")
    (out / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    print(f"F_PE_ELASTIC12B_FETCH_SUCCESS={summary['fetch_success_count']}/{EXPECTED_COUNT}")
    print(f"F_PE_ELASTIC12B_DETERMINATIONS={summary['settlement_determination_count']}|R2={summary['r2_determination_count']}|R3={summary['r3_determination_count']}")
    print(f"F_PE_ELASTIC12B_UNLOAD_STEPS={summary['unload_step_count']}")
    print(f"F_PE_ELASTIC12B_LS25_TOUCH_OBJECTS={len(touch25_objects)}")
    print(f"F_PE_ELASTIC12B_LS25_LOCAL_OBJECTS={len(local25_objects)}")
    print(f"F_PE_ELASTIC12B_LS50_TRANSITION_OBJECTS={len(local50_objects)}")
    print(f"F_PE_ELASTIC12B_CLASSIFICATION={classification}")
    if failures:
        raise SystemExit("F_PE_ELASTIC12B_FAIL incomplete 86-object accounting")
    print("F_PE_ELASTIC12B=PASS")


if __name__ == "__main__":
    main()
