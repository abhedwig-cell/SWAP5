#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re

HISTS=("X01","X02","X03","X04")
NSTEPS=1024


def first_fail(path:pathlib.Path):
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("F_ROMV2_D13_REF_FAIL"):
            return line.strip()
    return None


def scalar(raw:str,key:str):
    m=re.search(re.escape(key)+r"=([^\n]+)",raw)
    return None if not m else m.group(1).strip()


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--evidence-dir",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True)
    ap.add_argument("--member",required=True)
    ap.add_argument("--dimension",required=True,type=int)
    ap.add_argument("--thickness",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    dz=[float(x) for x in a.thickness.split(",") if x]
    if len(dz)!=a.dimension or abs(sum(dz)-160.0)>1e-12:
        raise SystemExit("B1HC-Q dimension/thickness drift")

    manifest=json.loads((a.evidence_dir/"execution_manifest.json").read_text())
    if manifest["material"]!=a.material or manifest["member"]!=a.member:
        raise SystemExit("B1HC-Q execution manifest identity drift")

    rows={}
    qualified=[]
    failed=[]
    technical=[]
    maxmass=0.0
    all_identity=True

    for h in HISTS:
        row=manifest["histories"][h]
        status=row["status"]
        o0=a.evidence_dir/row["o0_file"]
        o2=a.evidence_dir/row["o2_file"]
        if status=="QUALIFIED":
            r0=o0.read_text(errors="replace")
            sci_identity=o0.read_bytes()==o2.read_bytes()
            all_identity &= sci_identity
            state_count=r0.count("F_ROMV2_D13_REF_STATE|")
            initial_count=r0.count("F_ROMV2_D13_REF_INITIAL|")
            complete="F_ROMV2_D13_REF_EXECUTION_COMPLETE=PASS" in r0
            mass_raw=scalar(r0,"F_ROMV2_D13_REF_MAX_ABS_MASS")
            fallback_raw=scalar(r0,"F_ROMV2_D13_REF_TOTAL_FALLBACK_COUNT")
            hist_raw=scalar(r0,"F_ROMV2_D13_REF_HISTORY_COUNT")
            mass=float(mass_raw) if mass_raw is not None else float("inf")
            fallbacks=int(fallback_raw) if fallback_raw is not None else -1
            history_count=int(hist_raw) if hist_raw is not None else -1
            valid=(
                sci_identity and state_count==NSTEPS and initial_count==1
                and complete and history_count==1 and math.isfinite(mass)
                and mass<=1e-12 and fallbacks>=0
            )
            if not valid:
                status="TECHNICAL_FAILURE"
                technical.append(h)
            else:
                qualified.append(h)
                maxmass=max(maxmass,abs(mass))
            rows[h]={
              "status":status,
              "O0_O2_identity":sci_identity,
              "state_count":state_count,
              "initial_count":initial_count,
              "history_count":history_count,
              "max_abs_mass_cm":mass,
              "fallback_count":fallbacks,
              "failure_marker":None
            }
        elif status=="FAIL_CLOSED_REFERENCE_POLICY":
            f0=first_fail(o0); f2=first_fail(o2)
            ident=f0 is not None and f0==f2
            all_identity &= ident
            if not ident:
                status="TECHNICAL_FAILURE"; technical.append(h)
            else:
                failed.append(h)
            rows[h]={
              "status":status,"O0_O2_identity":ident,
              "state_count":0,"initial_count":None,"history_count":None,
              "max_abs_mass_cm":None,"fallback_count":None,
              "failure_marker":f0
            }
        else:
            technical.append(h)
            all_identity=False
            rows[h]={
              "status":"TECHNICAL_FAILURE","O0_O2_identity":False,
              "state_count":None,"initial_count":None,"history_count":None,
              "max_abs_mass_cm":None,"fallback_count":None,
              "failure_marker":first_fail(o0)
            }

    result={
      "schema":"swap5.layer-rom.phase-b1hc-q.member-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HC-Q",
      "material":a.material,"member":a.member,
      "dimension":a.dimension,"thickness_cm":dz,
      "qualified_histories":qualified,
      "qualified_history_count":len(qualified),
      "fail_closed_histories":failed,
      "technical_failure_histories":technical,
      "all_status_or_trace_identity":all_identity,
      "maximum_qualified_mass_residual_cm":maxmass,
      "histories":rows,
      "hydrological_comparison_performed":False,
      "performance_measurement_performed":False,
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "material":a.material,"member":a.member,
      "qualified_histories":qualified,
      "fail_closed_histories":failed,
      "technical_failure_histories":technical,
      "maximum_qualified_mass_residual_cm":maxmass
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
