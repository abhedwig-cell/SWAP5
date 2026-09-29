#!/usr/bin/env python3
"""Exact BRO hydrophysical-record binding for F-HYDROFIT02.

Semantic identity is BRO id + begin/end depth + SHA-256 of the raw
WaterContentAndConductivityAtSpecificSoilWaterPotential values string.
The XML document ordinal is provenance only. Source lambda is never a key.
"""
from __future__ import annotations

import hashlib
import math
import xml.etree.ElementTree as ET

import numpy as np

from hydrofit import Observation
from bro_bhrp_fetch import DEFAULT_BASE, fetch


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _first(node, name: str, default=None):
    return next(
        ((e.text or "").strip() for e in node.iter()
         if local(e.tag) == name and (e.text or "").strip()),
        default,
    )


def parse_hydraulic_records(payload: bytes):
    root = ET.fromstring(payload)
    bro_id = _first(root, "broId")
    out = []
    for ordinal, iv in enumerate(
        e for e in root.iter() if local(e.tag) == "InvestigatedInterval"
    ):
        begin = _first(iv, "beginDepth")
        end = _first(iv, "endDepth")
        horizon = _first(iv, "horizonCode", "")
        params = {}
        for e in iv.iter():
            name = local(e.tag)
            if name in (
                "residualVolumetricWaterContent",
                "volumetricWaterContentAtSaturation",
                "modelledSaturatedHydraulicConductivity",
            ):
                params[name] = (e.text or "").strip()

        hyd = shape = None
        for da in (e for e in iv.iter() if local(e.tag) == "DataArray"):
            et = next(
                (e.attrib.get("name") for e in da.iter()
                 if local(e.tag) == "elementType"),
                None,
            )
            values = next(
                ((e.text or "").strip() for e in da.iter()
                 if local(e.tag) == "values"),
                "",
            )
            if et == "WaterContentAndConductivityAtSpecificSoilWaterPotential":
                hyd = values
            elif et == "ShapeHydraulicConductivityCurve":
                shape = values

        if not hyd or not shape or len(params) != 3:
            continue

        raw = [list(map(float, q.split(","))) for q in hyd.split()]
        hs = [q[0] for q in raw]
        thetas = [q[1] for q in raw]
        ks = [q[2] for q in raw if q[2] > 0]
        obs = []
        for h, theta, k in raw:
            obs.append(Observation("theta", h, theta, sigma=.01))
            if k > 0:
                obs.append(Observation("K", h, k, sigma=.1))

        shp = list(map(float, shape.split(",")))
        src = np.array([
            float(params["residualVolumetricWaterContent"]),
            float(params["volumetricWaterContentAtSaturation"]),
            shp[0],
            shp[1],
            float(params["modelledSaturatedHydraulicConductivity"]),
        ])
        out.append({
            "bro_id": bro_id,
            "begin_depth": str(begin),
            "end_depth": str(end),
            "hyd_sha256": hashlib.sha256(hyd.encode()).hexdigest(),
            "interval_ordinal": ordinal,
            "source_l": shp[3],
            "horizon": horizon,
            "n_obs": len(raw),
            "h_span": max(hs) - min(hs),
            "theta_span": max(thetas) - min(thetas),
            "logk_span": math.log10(max(ks) / min(ks)) if ks else 0.0,
            "obs": obs,
            "src": src,
        })
    return out


def bind_corpus_rows(intervals):
    """Bind corpus rows to exact live XML records by hydraulic hash."""
    cache = {}
    rows = []
    for row in intervals:
        hyd_hash = row.get("hyd_sha256")
        if not hyd_hash:
            raise ValueError(
                "identity-correct binding requires hyd_sha256 on every corpus row"
            )
        bro_id = row["bro_id"]
        if bro_id not in cache:
            status, _, payload = fetch(DEFAULT_BASE + "/objects/" + bro_id)
            if status // 100 != 2:
                raise RuntimeError(f"fetch {bro_id} returned HTTP {status}")
            records = parse_hydraulic_records(payload)
            by_hash = {}
            for rec in records:
                h = rec["hyd_sha256"]
                if h in by_hash:
                    raise RuntimeError(f"duplicate hydraulic hash in XML for {bro_id}: {h}")
                by_hash[h] = rec
            cache[bro_id] = by_hash

        rec = cache[bro_id].get(hyd_hash)
        if rec is None:
            raise KeyError(f"hydraulic hash not found for {bro_id}: {hyd_hash}")
        if (
            str(row["begin_depth"]) != rec["begin_depth"]
            or str(row["end_depth"]) != rec["end_depth"]
        ):
            raise RuntimeError(
                "hash matched record at different depth: "
                f"{bro_id} corpus={row['begin_depth']}:{row['end_depth']} "
                f"xml={rec['begin_depth']}:{rec['end_depth']}"
            )
        if "lambda" in row and abs(float(row["lambda"]) - float(rec["source_l"])) > 5e-7:
            raise RuntimeError(
                "hydraulic hash matched a record with different source lambda: "
                f"{bro_id} {hyd_hash} corpus={row['lambda']} xml={rec['source_l']}"
            )
        rows.append({**row, **rec})
    return rows
