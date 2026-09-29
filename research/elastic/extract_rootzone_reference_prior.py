#!/usr/bin/env python3
"""F-PE-ELASTIC12E deterministic 20-kPa wet-state reference prior extraction."""
from __future__ import annotations
import argparse, json, math, statistics
from pathlib import Path

EXPECTED_INTERVALS = 21
EXPECTED_SUPPORTED = 16
STRESS = 20.0
STATE = "WET_MAX_THETA"
PIM = 1.0e-6


def summarize(values):
    xs=sorted(values)
    return {
        "n":len(xs),
        "min":min(xs) if xs else None,
        "median":statistics.median(xs) if xs else None,
        "max":max(xs) if xs else None,
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--transfer",required=True)
    ap.add_argument("--out",required=True)
    a=ap.parse_args()

    src=json.loads(Path(a.transfer).read_text())
    rows=[
        r for r in src["transfer_rows"]
        if r["state"]==STATE and float(r["stress_kpa"])==STRESS
    ]
    if len(rows)!=EXPECTED_INTERVALS:
        raise SystemExit(f"F_PE_ELASTIC12E_FAIL interval count {len(rows)}")

    identities=[(r["bro_id"],float(r["begin_depth_m"]),float(r["end_depth_m"])) for r in rows]
    if len(set(identities))!=EXPECTED_INTERVALS:
        raise SystemExit("F_PE_ELASTIC12E_FAIL duplicate interval identity")

    out=[]
    for r in sorted(rows,key=lambda x:(x["bro_id"],x["begin_depth_m"],x["end_depth_m"])):
        s=float(r["projected_ssk_cm_inv"])
        if not (math.isfinite(s) and s>0.0):
            raise RuntimeError("nonpositive/nonfinite Ssk")
        supported=bool(r["water_predictor_in_calibration_domain"])
        cls="REFERENCE_PRIOR_SUPPORTED" if supported else "WATER_DOMAIN_EXTRAPOLATION"
        out.append({
            "bro_id":r["bro_id"],
            "begin_depth_m":float(r["begin_depth_m"]),
            "end_depth_m":float(r["end_depth_m"]),
            "horizon_code":r.get("horizon_code"),
            "organic_matter_pct":r.get("organic_matter_pct"),
            "dry_bulk_density_g_cm3":float(r["dry_bulk_density_g_cm3"]),
            "wet_theta_cm3_cm3":float(r["source_theta_cm3_cm3"]),
            "source_potential_cm_h2o":float(r["source_potential_cm_h2o"]),
            "converted_gravimetric_water_content_pct":float(r["converted_gravimetric_water_content_pct"]),
            "water_predictor_in_calibration_domain":supported,
            "reference_stress_kpa":STRESS,
            "reference_ssk_cm_inv":s,
            "ratio_to_1e_6":s/PIM,
            "classification":cls,
            "hyd_sha256":r["hyd_sha256"],
        })

    supported_rows=[r for r in out if r["classification"]=="REFERENCE_PRIOR_SUPPORTED"]
    extrap=[r for r in out if r["classification"]=="WATER_DOMAIN_EXTRAPOLATION"]
    if len(supported_rows)!=EXPECTED_SUPPORTED:
        raise SystemExit(f"F_PE_ELASTIC12E_FAIL supported count {len(supported_rows)}")
    if len(extrap)!=EXPECTED_INTERVALS-EXPECTED_SUPPORTED:
        raise SystemExit("F_PE_ELASTIC12E_FAIL extrapolation count")

    supvals=[r["reference_ssk_cm_inv"] for r in supported_rows]
    allvals=[r["reference_ssk_cm_inv"] for r in out]
    summary={
        "work_unit":"F-PE-ELASTIC12E",
        "source_status":src.get("status"),
        "reference_stress_kpa":STRESS,
        "material_state":STATE,
        "interval_count":len(out),
        "supported_interval_count":len(supported_rows),
        "extrapolative_interval_count":len(extrap),
        "supported_prior":summarize(supvals),
        "all_interval_sensitivity":summarize(allvals),
        "supported_ratio_to_1e_6":summarize([v/PIM for v in supvals]),
        "supported_below_1e_6":sum(v<PIM for v in supvals),
        "supported_at_or_above_1e_6":sum(v>=PIM for v in supvals),
        "classification":"REFERENCE_PRIOR_POPULATION_QUALIFIED",
    }

    outdir=Path(a.out);outdir.mkdir(parents=True,exist_ok=True)
    (outdir/"reference_prior.json").write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    (outdir/"summary.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")

    print("F_PE_ELASTIC12E_INTERVALS=21")
    print("F_PE_ELASTIC12E_SUPPORTED=16")
    print("F_PE_ELASTIC12E_EXTRAPOLATIVE=5")
    print("F_PE_ELASTIC12E_SUPPORTED_RANGE="+json.dumps(summary["supported_prior"],separators=(",",":")))
    print("F_PE_ELASTIC12E_CLASSIFICATION=REFERENCE_PRIOR_POPULATION_QUALIFIED")
    print("F_PE_ELASTIC12E=PASS")

if __name__=="__main__":
    main()
