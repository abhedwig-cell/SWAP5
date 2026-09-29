#!/usr/bin/env python3
"""F-PE-ELASTIC12A target-free BHR-P -> BHR-GT mechanical transfer audit."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
import time
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BASE = "https://publiek.broservices.nl/sr/bhrp/v2"
USER_AGENT = "SWAP5-F-PE-ELASTIC12A/0.1 research reproducibility"
RHO_W = 0.9982
M5_B0 = -5.213084677584852
M5_BW = 1.0383403589566573
LOG_STRESS_MIN = 1.7871769924705538
LOG_STRESS_MAX = 2.6651446013599136
LOG_WATER_MIN = 1.3654879848908996
LOG_WATER_MAX = 2.656577291396114
STRESSES = (5.0, 10.0, 20.0, 50.0, 100.0)
TARGET_POTENTIALS = (-10.0, -100.0, -1000.0)


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def fetch(url: str, attempts: int = 3, timeout: float = 30.0) -> bytes:
    last = None
    for i in range(attempts):
        req = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/xml"})
        try:
            with urlopen(req, timeout=timeout) as r:
                if int(r.status) != 200:
                    raise RuntimeError(f"HTTP {r.status} for {url}")
                return r.read()
        except (HTTPError, URLError) as e:
            last = e
            if i + 1 < attempts:
                time.sleep(0.5 * (i + 1))
    raise RuntimeError(f"fetch failed for {url}: {last}")


def one_text(node, name):
    vals = [(e.text or "").strip() for e in node.iter() if local(e.tag) == name and (e.text or "").strip()]
    return vals[0] if vals else None


def hydraulic_records(raw: bytes, bro_id: str):
    root = ET.fromstring(raw)
    found_id = next(((e.text or "").strip() for e in root.iter() if local(e.tag) == "broId" and (e.text or "").strip()), None)
    if found_id != bro_id:
        raise RuntimeError(f"BRO identity mismatch requested={bro_id} observed={found_id}")
    records = []
    for iv in (e for e in root.iter() if local(e.tag) == "InvestigatedInterval"):
        begin = one_text(iv, "beginDepth")
        end = one_text(iv, "endDepth")
        if begin is None or end is None:
            continue
        for da in (e for e in iv.iter() if local(e.tag) == "DataArray"):
            et = None
            values = ""
            for e in da.iter():
                if local(e.tag) == "elementType":
                    et = e.attrib.get("name")
                elif local(e.tag) == "values":
                    values = (e.text or "").strip()
            if et != "WaterContentAndConductivityAtSpecificSoilWaterPotential":
                continue
            tuples = []
            for block in values.split():
                p = block.split(",")
                if len(p) != 3:
                    raise RuntimeError(f"unexpected hydraulic tuple {block!r}")
                h, theta, k = map(float, p)
                if not (math.isfinite(h) and math.isfinite(theta)):
                    continue
                tuples.append((h, theta, k))
            if not tuples:
                raise RuntimeError(f"empty hydraulic record {bro_id} {begin}:{end}")
            density = []
            for e in iv.iter():
                if local(e.tag) != "dryBulkDensity":
                    continue
                txt = (e.text or "").strip()
                if not txt:
                    continue
                uom = e.attrib.get("uom")
                density.append((float(txt), uom))
            records.append({
                "bro_id": bro_id,
                "begin_depth": float(begin),
                "end_depth": float(end),
                "hyd_sha256": hashlib.sha256(values.encode()).hexdigest(),
                "values": values,
                "tuples": tuples,
                "dry_bulk_density_raw": density,
            })
    return records


def key_depth(bro, begin, end):
    return (bro, round(float(begin), 9), round(float(end), 9))


def choose_states(tuples):
    wet = max(tuples, key=lambda x: (x[1], x[0]))
    dry = min(tuples, key=lambda x: (x[1], x[0]))
    out = [("WET_MAX_THETA", wet)]
    for target in TARGET_POTENTIALS:
        row = min(tuples, key=lambda x: (abs(x[0] - target), x[0]))
        out.append((f"NEAREST_{int(abs(target))}CM", row))
    out.append(("DRY_MIN_THETA", dry))
    return out


def summarize(rows, field):
    vals = [r[field] for r in rows]
    return {"n": len(vals), "min": min(vals), "median": statistics.median(vals), "max": max(vals)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--authority-root", required=True)
    ap.add_argument("--raw-dir", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    authority = Path(args.authority_root)
    raw_dir = Path(args.raw_dir)
    raw_dir.mkdir(parents=True, exist_ok=True)

    identity_path = authority / "spatial-lambda-corpus.json"
    provenance_path = authority / "lambda-prior-cross-provenance.json"
    schema_path = authority / "hydraulic-tuple-schema.xml"
    if not all(p.exists() for p in (identity_path, provenance_path, schema_path)):
        raise RuntimeError("required HYDROFIT authority files missing")

    schema = schema_path.read_text()
    for required in ('uom code="cm[H2O]"', 'uom code="cm3/cm3"', 'uom code="cm/d"'):
        if required not in schema:
            raise RuntimeError(f"hydraulic tuple unit authority missing {required}")

    identity_doc = json.loads(identity_path.read_text())
    identity = identity_doc["intervals"]
    if len(identity) != 31:
        raise RuntimeError(f"frozen identity count drift {len(identity)}")
    if sum(bool(r.get("hyd_sha256")) for r in identity) != 31:
        raise RuntimeError("missing frozen hydraulic hashes")

    prov_doc = json.loads(provenance_path.read_text())
    prov_rows = prov_doc["rows"]
    if len(prov_rows) != 31:
        raise RuntimeError(f"cross-provenance count drift {len(prov_rows)}")

    bro_ids = sorted({r["bro_id"] for r in identity})
    if len(bro_ids) != 9:
        raise RuntimeError(f"frozen BRO object count drift {len(bro_ids)}")

    all_records = []
    object_manifest = []
    for bro in bro_ids:
        raw = fetch(f"{BASE}/objects/{bro}")
        sha = hashlib.sha256(raw).hexdigest()
        (raw_dir / f"{bro}.xml").write_bytes(raw)
        object_manifest.append({"bro_id": bro, "bytes": len(raw), "sha256": sha})
        all_records.extend(hydraulic_records(raw, bro))
    (raw_dir / "objects.manifest.json").write_text(json.dumps(object_manifest, indent=2, sort_keys=True) + "\n")

    rec_by_identity = defaultdict(list)
    for r in all_records:
        rec_by_identity[(key_depth(r["bro_id"], r["begin_depth"], r["end_depth"]), r["hyd_sha256"])].append(r)

    matched = {}
    for frozen in identity:
        ikey = (
            key_depth(frozen["bro_id"], frozen["begin_depth"], frozen["end_depth"]),
            frozen["hyd_sha256"],
        )
        hits = rec_by_identity.get(ikey, [])
        if len(hits) != 1:
            raise RuntimeError(f"frozen hydrophysical identity mismatch {ikey}: {len(hits)} hits")
        matched[(ikey[0], ikey[1])] = hits[0]
    if len(matched) != 31:
        raise RuntimeError("not all 31 frozen identities reconstructed")

    prov_by_depth = defaultdict(list)
    for p in prov_rows:
        prov_by_depth[key_depth(p["bro_id"], p["begin_depth"], p["end_depth"])].append(p)

    clean = []
    for frozen in identity:
        dkey = key_depth(frozen["bro_id"], frozen["begin_depth"], frozen["end_depth"])
        phits = prov_by_depth[dkey]
        if len(phits) != 1:
            # duplicate-depth hydrophysical identities are outside the clean density subset
            continue
        p = phits[0]
        dd = p["descriptors"]["dryBulkDensity"]
        if dd.get("status") != "ASSIGNED":
            continue
        rho_d = float(dd["assigned"])
        if not math.isfinite(rho_d) or rho_d <= 0:
            raise RuntimeError(f"invalid assigned dry bulk density {dkey}")
        r = matched[(dkey, frozen["hyd_sha256"])]
        raw_density = [(v, u) for v, u in r["dry_bulk_density_raw"] if math.isfinite(v)]
        if not raw_density:
            raise RuntimeError(f"no raw density for clean interval {dkey}")
        if any(u != "g/cm3" for _, u in raw_density):
            raise RuntimeError(f"unexpected dryBulkDensity unit {dkey}: {raw_density}")
        unique = sorted({round(v, 12) for v, _ in raw_density})
        if len(unique) != 1 or not math.isclose(unique[0], rho_d, rel_tol=0.0, abs_tol=5e-13):
            raise RuntimeError(f"raw/provenance density mismatch {dkey}: raw={unique} assigned={rho_d}")
        clean.append((frozen, p, r, rho_d))

    if len(clean) != 21:
        raise RuntimeError(f"clean ASSIGNED dryBulkDensity population drift {len(clean)}")
    if len({x[0]["bro_id"] for x in clean}) != 7:
        raise RuntimeError("clean object population drift")

    transfer = []
    for frozen, p, record, rho_d in clean:
        om = p["descriptors"].get("organicMatterContent", {})
        horizon = p["descriptors"].get("horizonCode", {})
        for state_name, (potential, theta, conductivity) in choose_states(record["tuples"]):
            if theta <= 0:
                raise RuntimeError("nonpositive theta cannot convert to gravimetric water content")
            w_pct = 100.0 * theta * RHO_W / rho_d
            if not math.isfinite(w_pct) or w_pct <= 0:
                raise RuntimeError("invalid converted gravimetric water content")
            logw = math.log10(w_pct)
            water_in = LOG_WATER_MIN <= logw <= LOG_WATER_MAX
            for stress in STRESSES:
                logs = math.log10(stress)
                stress_in = LOG_STRESS_MIN <= logs <= LOG_STRESS_MAX
                pred_log = M5_B0 + M5_BW * logw - logs
                ssk = 10.0 ** pred_log
                transfer.append({
                    "bro_id": frozen["bro_id"],
                    "begin_depth_m": float(frozen["begin_depth"]),
                    "end_depth_m": float(frozen["end_depth"]),
                    "hyd_sha256": frozen["hyd_sha256"],
                    "state": state_name,
                    "source_potential_cm_h2o": potential,
                    "source_theta_cm3_cm3": theta,
                    "source_k_cm_d": conductivity,
                    "dry_bulk_density_g_cm3": rho_d,
                    "organic_matter_pct": float(om["assigned"]) if om.get("status") == "ASSIGNED" else None,
                    "horizon_code": horizon.get("assigned") if horizon.get("status") == "ASSIGNED" else None,
                    "converted_gravimetric_water_content_pct": w_pct,
                    "water_predictor_in_calibration_domain": water_in,
                    "stress_kpa": stress,
                    "stress_predictor_in_calibration_domain": stress_in,
                    "fully_in_calibration_predictor_domain": water_in and stress_in,
                    "projected_log10_ssk_cm_inv": pred_log,
                    "projected_ssk_cm_inv": ssk,
                    "ratio_to_1e_6": ssk / 1.0e-6,
                })

    if len(transfer) != 21 * 5 * 5:
        raise RuntimeError(f"transfer matrix size drift {len(transfer)}")

    by_stress = {}
    for stress in STRESSES:
        rows = [r for r in transfer if r["stress_kpa"] == stress]
        by_stress[str(stress)] = {
            "ssk_cm_inv": summarize(rows, "projected_ssk_cm_inv"),
            "ratio_to_1e_6": summarize(rows, "ratio_to_1e_6"),
            "fully_in_domain_rows": sum(r["fully_in_calibration_predictor_domain"] for r in rows),
            "water_in_domain_rows": sum(r["water_predictor_in_calibration_domain"] for r in rows),
            "stress_in_domain": all(r["stress_predictor_in_calibration_domain"] for r in rows),
        }

    by_state = {}
    for state in ("WET_MAX_THETA", "NEAREST_10CM", "NEAREST_100CM", "NEAREST_1000CM", "DRY_MIN_THETA"):
        rows = [r for r in transfer if r["state"] == state]
        by_state[state] = {
            "converted_water_pct": summarize(rows, "converted_gravimetric_water_content_pct"),
            "water_in_domain_rows": sum(r["water_predictor_in_calibration_domain"] for r in rows),
        }

    result = {
        "status": "PASS",
        "authority": {
            "identity_intervals": len(identity),
            "bro_objects": len(bro_ids),
            "clean_intervals": len(clean),
            "clean_objects": len({x[0]["bro_id"] for x in clean}),
            "water_density_g_cm3": RHO_W,
            "hydraulic_units": {
                "potential": "cm[H2O]",
                "theta": "cm3/cm3",
                "conductivity": "cm/d",
                "dry_bulk_density": "g/cm3",
            },
        },
        "model": {
            "b0": M5_B0,
            "bW": M5_BW,
            "stress_exponent": -1.0,
            "log_water_domain": [LOG_WATER_MIN, LOG_WATER_MAX],
            "log_stress_domain": [LOG_STRESS_MIN, LOG_STRESS_MAX],
        },
        "stress_scenarios_kpa": list(STRESSES),
        "summary_by_stress": by_stress,
        "summary_by_water_state": by_state,
        "object_ids": bro_ids,
        "transfer_rows": transfer,
    }
    Path(args.out).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")

    print("F_PE_ELASTIC12A_FROZEN_IDENTITIES=31")
    print("F_PE_ELASTIC12A_OBJECTS=9")
    print("F_PE_ELASTIC12A_CLEAN_INTERVALS=21")
    print("F_PE_ELASTIC12A_CLEAN_OBJECTS=7")
    print("F_PE_ELASTIC12A_HYDRO_IDENTITY=PASS")
    print("F_PE_ELASTIC12A_RESPONSE_PROVENANCE_ARCHIVED=PASS")
    print("F_PE_ELASTIC12A_DRY_DENSITY_UNIT=PASS")
    print("F_PE_ELASTIC12A_TRANSFER_ROWS=525")
    for stress in STRESSES:
        print("F_PE_ELASTIC12A_STRESS=" + str(stress) + "|SUMMARY=" +
              json.dumps(by_stress[str(stress)], separators=(",", ":"), sort_keys=True))
    for state, summary in by_state.items():
        print("F_PE_ELASTIC12A_STATE=" + state + "|SUMMARY=" +
              json.dumps(summary, separators=(",", ":"), sort_keys=True))
    print("F_PE_ELASTIC12A=PASS")


if __name__ == "__main__":
    main()
