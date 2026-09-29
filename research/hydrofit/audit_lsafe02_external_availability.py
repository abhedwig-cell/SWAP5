#!/usr/bin/env python3
"""P-LSAFE02A diagnostic audit of the frozen independent BRO object set."""
from __future__ import annotations

import argparse
import collections
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    frozen = json.loads(Path(a.ids).read_text())
    ids = list(frozen["independent_bro_ids"])

    rows = []
    fetch_failures = []
    procedures = collections.Counter()
    methods = collections.Counter()

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
        obj_methods = sorted(set(texts(root, "modellingMethod")))
        obj_procs = sorted(set(texts(root, "modellingProcedure")))
        procedures.update(obj_procs)
        methods.update(obj_methods)

        has_bodem = "bodemfysischOnderzoek" in purposes
        has_mvg = "mualemVanGenuchten" in obj_methods

        hyd_intervals = 0
        shape_intervals = 0
        colocated = 0

        for iv in (e for e in root.iter() if local(e.tag) == "InvestigatedInterval"):
            ets = []
            for da in (e for e in iv.iter() if local(e.tag) == "DataArray"):
                et = next(
                    (
                        e.attrib.get("name")
                        for e in da.iter()
                        if local(e.tag) == "elementType"
                    ),
                    None,
                )
                if et:
                    ets.append(et)
            has_hyd = "WaterContentAndConductivityAtSpecificSoilWaterPotential" in ets
            has_shape = "ShapeHydraulicConductivityCurve" in ets
            hyd_intervals += int(has_hyd)
            shape_intervals += int(has_shape)
            colocated += int(has_hyd and has_shape)

        if not has_bodem:
            disposition = "NO_BODEMFYSISCH_SURVEY_PURPOSE"
        elif not has_mvg:
            disposition = "NO_MVG_MODELLING_METHOD"
        elif hyd_intervals == 0:
            disposition = "NO_HYDRAULIC_OBSERVATION_ARRAY"
        elif shape_intervals == 0:
            disposition = "NO_CONDUCTIVITY_SHAPE_ARRAY"
        elif colocated == 0:
            disposition = "NO_COLOCATED_HYD_AND_SHAPE"
        else:
            disposition = "WOULD_BE_ELIGIBLE"

        row = {
            "bro_id": bid,
            "survey_purposes": purposes,
            "modelling_methods": obj_methods,
            "modelling_procedures": obj_procs,
            "has_bodemfysisch_survey_purpose": has_bodem,
            "has_mvg_modelling_method": has_mvg,
            "hydraulic_intervals": hyd_intervals,
            "shape_intervals": shape_intervals,
            "colocated_intervals": colocated,
            "disposition": disposition,
        }
        rows.append(row)
        print(
            f"BRO_LSAFE02A|BRO={bid}|BODEM={int(has_bodem)}|MVG={int(has_mvg)}|"
            f"HYD_INTERVALS={hyd_intervals}|SHAPE_INTERVALS={shape_intervals}|"
            f"COLOCATED={colocated}|DISPOSITION={disposition}"
        )

    counts = collections.Counter(r["disposition"] for r in rows)
    survey_count = sum(r["has_bodemfysisch_survey_purpose"] for r in rows)
    mvg_count = sum(r["has_mvg_modelling_method"] for r in rows)
    hyd_count = sum(r["hydraulic_intervals"] > 0 for r in rows)
    shape_count = sum(r["shape_intervals"] > 0 for r in rows)
    coloc_count = sum(r["colocated_intervals"] > 0 for r in rows)

    out = {
        "authority_object_set": frozen,
        "fetch_failures": fetch_failures,
        "rows": rows,
        "disposition_counts": dict(sorted(counts.items())),
        "objects_with_bodemfysisch_purpose": survey_count,
        "objects_with_mvg_method": mvg_count,
        "objects_with_hydraulic_array": hyd_count,
        "objects_with_shape_array": shape_count,
        "objects_with_colocated_hyd_and_shape": coloc_count,
        "modelling_methods": dict(sorted(methods.items())),
        "modelling_procedures": dict(sorted(procedures.items())),
    }
    Path(a.out).write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")

    print(
        f"BRO_LSAFE02A_SUMMARY|FROZEN={len(ids)}|AUDITED={len(rows)}|"
        f"FETCH_FAILURES={len(fetch_failures)}|BODEM={survey_count}|MVG={mvg_count}|"
        f"HYD={hyd_count}|SHAPE={shape_count}|COLOCATED={coloc_count}|"
        f"DISPOSITIONS={json.dumps(dict(sorted(counts.items())),sort_keys=True)}"
    )
    print("BRO_LSAFE02A_METHODS=" + json.dumps(dict(sorted(methods.items())), sort_keys=True))
    print("BRO_LSAFE02A_PROCEDURES=" + json.dumps(dict(sorted(procedures.items())), sort_keys=True))

    if fetch_failures:
        raise SystemExit("availability audit incomplete due to fetch failures")
    if len(rows) != len(ids):
        raise SystemExit("availability audit did not dispose every frozen object")
    if counts.get("WOULD_BE_ELIGIBLE", 0):
        raise SystemExit("P-LSAFE02 acquisition contradiction: WOULD_BE_ELIGIBLE object found")


if __name__ == "__main__":
    main()
