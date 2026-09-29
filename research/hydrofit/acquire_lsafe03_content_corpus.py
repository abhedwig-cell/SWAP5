#!/usr/bin/env python3
"""P-LSAFE03 content-defined acquisition on frozen independent BRO objects."""
from __future__ import annotations

import argparse
import hashlib
import json
import xml.etree.ElementTree as ET
from pathlib import Path

from bro_bhrp_fetch import DEFAULT_BASE, fetch


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def texts(root, name: str):
    return [
        (e.text or "").strip()
        for e in root.iter()
        if local(e.tag) == name and (e.text or "").strip()
    ]


def first(node, name: str):
    return next(
        (
            (e.text or "").strip()
            for e in node.iter()
            if local(e.tag) == name and (e.text or "").strip()
        ),
        None,
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    frozen = json.loads(Path(a.ids).read_text())
    ids = list(frozen["independent_bro_ids"])

    rows = []
    fetch_failures = []
    rejected_intervals = []
    contributing_objects = set()

    for bid in ids:
        try:
            status, _, payload = fetch(DEFAULT_BASE + "/objects/" + bid)
        except Exception as exc:
            fetch_failures.append({"bro_id": bid, "error": repr(exc)})
            continue
        if status // 100 != 2:
            fetch_failures.append({"bro_id": bid, "status": status})
            continue

        root = ET.fromstring(payload)
        purposes = sorted(set(texts(root, "surveyPurpose")))
        methods = sorted(set(texts(root, "modellingMethod")))
        procedures = sorted(set(texts(root, "modellingProcedure")))

        if "mualemVanGenuchten" not in methods:
            raise SystemExit(f"frozen object lost MvG method: {bid}")
        if "WENRHydrofysicav1" not in procedures:
            raise SystemExit(f"frozen object lost WENRHydrofysicav1 procedure: {bid}")

        for ordinal, iv in enumerate(
            e for e in root.iter() if local(e.tag) == "InvestigatedInterval"
        ):
            begin = first(iv, "beginDepth")
            end = first(iv, "endDepth")
            required = {
                "residualVolumetricWaterContent": first(
                    iv, "residualVolumetricWaterContent"
                ),
                "volumetricWaterContentAtSaturation": first(
                    iv, "volumetricWaterContentAtSaturation"
                ),
                "modelledSaturatedHydraulicConductivity": first(
                    iv, "modelledSaturatedHydraulicConductivity"
                ),
            }

            hyd = None
            shape = None
            for da in (e for e in iv.iter() if local(e.tag) == "DataArray"):
                et = next(
                    (
                        e.attrib.get("name")
                        for e in da.iter()
                        if local(e.tag) == "elementType"
                    ),
                    None,
                )
                vals = next(
                    (
                        (e.text or "").strip()
                        for e in da.iter()
                        if local(e.tag) == "values"
                    ),
                    "",
                )
                if et == "WaterContentAndConductivityAtSpecificSoilWaterPotential":
                    hyd = vals
                elif et == "ShapeHydraulicConductivityCurve":
                    shape = vals

            if not hyd or not shape:
                continue

            missing = [k for k, v in required.items() if v is None]
            if missing:
                rejected_intervals.append(
                    {
                        "bro_id": bid,
                        "begin_depth": begin,
                        "end_depth": end,
                        "interval_ordinal": ordinal,
                        "reason": "MISSING_SOURCE_FIELDS",
                        "missing": missing,
                    }
                )
                continue

            shp = [float(x) for x in shape.split(",")]
            if len(shp) < 4:
                rejected_intervals.append(
                    {
                        "bro_id": bid,
                        "begin_depth": begin,
                        "end_depth": end,
                        "interval_ordinal": ordinal,
                        "reason": "INVALID_SHAPE_ARRAY",
                    }
                )
                continue

            rows.append(
                {
                    "bro_id": bid,
                    "begin_depth": begin,
                    "end_depth": end,
                    "hyd_sha256": hashlib.sha256(hyd.encode()).hexdigest(),
                    "interval_ordinal": ordinal,
                    "lambda": shp[3],
                    "observations": len(hyd.split()),
                    "procedure": "WENRHydrofysicav1",
                    "method": "mualemVanGenuchten",
                    "survey_purposes": purposes,
                }
            )
            contributing_objects.add(bid)

    identities = [(r["bro_id"], r["hyd_sha256"]) for r in rows]
    if len(identities) != len(set(identities)):
        raise SystemExit("duplicate hydraulic identity in P-LSAFE03 corpus")

    out = {
        "preregistration": "F-HYDROFIT02_L_SAFE_CONTENT_EXTERNAL_PREREGISTRATION.md",
        "source_object_set": frozen,
        "fetch_failures": fetch_failures,
        "rejected_intervals": rejected_intervals,
        "eligible_objects": len(contributing_objects),
        "intervals": rows,
    }
    Path(a.out).write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")

    print(
        f"BRO_LSAFE03_CORPUS|FROZEN_OBJECTS={len(ids)}|ELIGIBLE_OBJECTS={len(contributing_objects)}|"
        f"ELIGIBLE_RECORDS={len(rows)}|REJECTED_INTERVALS={len(rejected_intervals)}|"
        f"FETCH_FAILURES={len(fetch_failures)}|UNIQUE_HASHES={len(set(r['hyd_sha256'] for r in rows))}"
    )

    if fetch_failures:
        raise SystemExit("P-LSAFE03 acquisition incomplete due to fetch failure")


if __name__ == "__main__":
    main()
