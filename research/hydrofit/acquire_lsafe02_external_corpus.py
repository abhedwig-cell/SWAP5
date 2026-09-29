#!/usr/bin/env python3
"""P-LSAFE02 independent BRO acquisition with complete capped-cell handling."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from bro_bhrp_fetch import DEFAULT_BASE, fetch


def local(tag):
    return tag.rsplit("}", 1)[-1]


def texts(root, name):
    return [
        (e.text or "").strip()
        for e in root.iter()
        if local(e.tag) == name and (e.text or "").strip()
    ]


def is_capped(status, body):
    txt = body.decode("utf-8", "replace")
    return status // 100 != 2 and "2000" in txt


def search_cell(lat, lon, radius_km):
    body = json.dumps(
        {
            "area": {
                "enclosingCircle": {
                    "center": {"lat": lat, "lon": lon},
                    "radius": radius_km,
                }
            },
            "characteristicModelled": "JA",
        }
    ).encode()
    status, _, payload = fetch(
        DEFAULT_BASE + "/characteristics/searches",
        method="POST",
        body=body,
    )
    if status // 100 != 2:
        return status, payload, set()
    root = ET.fromstring(payload)
    ids = set()
    for e in root.iter():
        txt = (e.text or "").strip()
        if local(e.tag) == "broId" or txt.startswith("BHR"):
            ids.add(txt)
    return status, payload, ids


def child_centers(lat, lon, radius_km):
    # Nine half-radius circles on a 3x3 lattice. Offsets are based on the
    # parent's r/2 distance in N-S and E-W directions.
    half = radius_km / 2.0
    dlat = half / 111.32
    coslat = max(math.cos(math.radians(lat)), 0.2)
    dlon = half / (111.32 * coslat)
    for iy in (-1, 0, 1):
        for ix in (-1, 0, 1):
            yield lat + iy * dlat, lon + ix * dlon, half


def discover_all():
    initial_lats = [round(50.8 + .2 * i, 1) for i in range(14)]
    initial_lons = [round(3.5 + .3 * i, 1) for i in range(13)]
    queue = [(lat, lon, 10.0, 0) for lat in initial_lats for lon in initial_lons]
    seen_queries = set()
    ids = set()
    unresolved = []
    errors = []
    n_queries = 0
    n_subdivided = 0

    while queue:
        lat, lon, radius, level = queue.pop(0)
        key = (round(lat, 7), round(lon, 7), round(radius, 7))
        if key in seen_queries:
            continue
        seen_queries.add(key)
        n_queries += 1

        try:
            status, payload, here = search_cell(lat, lon, radius)
        except Exception as exc:
            errors.append(
                {
                    "stage": "search",
                    "lat": lat,
                    "lon": lon,
                    "radius_km": radius,
                    "error": repr(exc),
                }
            )
            continue

        if status // 100 == 2:
            ids.update(here)
            print(
                f"BRO_LSAFE02_CELL|LAT={lat:.7f}|LON={lon:.7f}|R={radius:g}|"
                f"LEVEL={level}|IDS={len(here)}"
            )
            continue

        if is_capped(status, payload):
            if radius > 1.25 + 1e-12:
                n_subdivided += 1
                queue.extend(
                    (clat, clon, crad, level + 1)
                    for clat, clon, crad in child_centers(lat, lon, radius)
                )
                print(
                    f"BRO_LSAFE02_SUBDIVIDE|LAT={lat:.7f}|LON={lon:.7f}|"
                    f"R={radius:g}|LEVEL={level}"
                )
            else:
                unresolved.append(
                    {
                        "lat": lat,
                        "lon": lon,
                        "radius_km": radius,
                        "status": status,
                        "body": payload.decode("utf-8", "replace")[:500],
                    }
                )
            continue

        errors.append(
            {
                "stage": "search",
                "lat": lat,
                "lon": lon,
                "radius_km": radius,
                "status": status,
                "body": payload.decode("utf-8", "replace")[:500],
            }
        )

    return sorted(ids), unresolved, errors, n_queries, n_subdivided


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--training-corpus", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    training = json.loads(Path(args.training_corpus).read_text())
    training_bro = sorted({r["bro_id"] for r in training["intervals"]})

    ids, unresolved, errors, n_queries, n_subdivided = discover_all()
    independent_ids = [bid for bid in ids if bid not in set(training_bro)]

    records = []
    fetch_failures = []
    eligible_objects = 0
    excluded_training_objects = len(set(ids) & set(training_bro))

    for index, bid in enumerate(independent_ids, 1):
        try:
            status, _, payload = fetch(DEFAULT_BASE + "/objects/" + bid)
        except Exception as exc:
            fetch_failures.append({"bro_id": bid, "error": repr(exc)})
            continue
        if status // 100 != 2:
            fetch_failures.append({"bro_id": bid, "status": status})
            continue

        root = ET.fromstring(payload)
        purposes = texts(root, "surveyPurpose")
        methods = texts(root, "modellingMethod")
        procedures = texts(root, "modellingProcedure")
        if "bodemfysischOnderzoek" not in purposes:
            continue
        if "mualemVanGenuchten" not in methods:
            continue

        object_records = 0
        for ordinal, iv in enumerate(
            e for e in root.iter() if local(e.tag) == "InvestigatedInterval"
        ):
            begin = next(iter(texts(iv, "beginDepth")), None)
            end = next(iter(texts(iv, "endDepth")), None)
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
            shp = [float(x) for x in shape.split(",")]
            if len(shp) < 4:
                continue

            h = hashlib.sha256(hyd.encode()).hexdigest()
            records.append(
                {
                    "bro_id": bid,
                    "begin_depth": begin,
                    "end_depth": end,
                    "hyd_sha256": h,
                    "interval_ordinal": ordinal,
                    "lambda": shp[3],
                    "observations": len(hyd.split()),
                    "procedure": procedures[0] if procedures else None,
                    "method": "mualemVanGenuchten",
                }
            )
            object_records += 1

        if object_records:
            eligible_objects += 1

        if index % 50 == 0:
            print(
                f"BRO_LSAFE02_INSPECT_PROGRESS|N={index}|TOTAL={len(independent_ids)}|"
                f"ELIGIBLE_RECORDS={len(records)}"
            )
        time.sleep(.01)

    identities = [(r["bro_id"], r["hyd_sha256"]) for r in records]
    dup_identity = len(identities) - len(set(identities))
    if dup_identity:
        raise SystemExit(f"duplicate independent hydraulic identities: {dup_identity}")

    old_hashes = {r["hyd_sha256"] for r in training["intervals"]}
    overlap_hashes = sorted({r["hyd_sha256"] for r in records} & old_hashes)
    if overlap_hashes:
        raise SystemExit(
            f"training hydraulic hashes survived BRO-object exclusion: {len(overlap_hashes)}"
        )

    result = {
        "preregistration": "F-HYDROFIT02_L_SAFE_EXTERNAL_PREREGISTRATION.md",
        "training_bro_ids": training_bro,
        "discovered_bro_ids": ids,
        "independent_bro_ids": independent_ids,
        "excluded_training_objects": excluded_training_objects,
        "search_queries": n_queries,
        "subdivided_cells": n_subdivided,
        "unresolved_capped_cells": unresolved,
        "search_errors": errors,
        "fetch_failures": fetch_failures,
        "eligible_objects": eligible_objects,
        "intervals": records,
    }
    Path(args.out).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

    print(
        f"BRO_LSAFE02_DISCOVERY|UNIQUE_IDS={len(ids)}|INDEPENDENT_IDS={len(independent_ids)}|"
        f"EXCLUDED_TRAINING_OBJECTS={excluded_training_objects}|QUERIES={n_queries}|"
        f"SUBDIVIDED={n_subdivided}|UNRESOLVED_CAPPED={len(unresolved)}|"
        f"SEARCH_ERRORS={len(errors)}|FETCH_FAILURES={len(fetch_failures)}"
    )
    print(
        f"BRO_LSAFE02_CORPUS|ELIGIBLE_OBJECTS={eligible_objects}|"
        f"ELIGIBLE_RECORDS={len(records)}|UNIQUE_HASHES={len(set(r['hyd_sha256'] for r in records))}"
    )


if __name__ == "__main__":
    main()
