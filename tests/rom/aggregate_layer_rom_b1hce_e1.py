#!/usr/bin/env python3
from __future__ import annotations

import argparse,json,pathlib

MATERIALS=("B02","B05","B06","B11","B12","B16")

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text())
    if p["phase"]!="PREREGISTERED_BEFORE_FIXED_HEAD_OPERATOR_LOCALIZATION":
        raise SystemExit("wrong preregistration")

    rows={}
    for f in a.input_dir.rglob("LAYER_ROM_B1HCE_E1_*_RESULT.json"):
        r=json.loads(f.read_text())
        if r.get("schema")!="swap5.layer-rom.phase-b1hce.e1.material-result.v1":
            continue
        rows[r["material"]]=r
    if set(rows)!=set(MATERIALS):
        raise SystemExit(f"material result mismatch {sorted(rows)}")

    internal_all=all(rows[m]["identity"]["internal_identity_pass"] for m in MATERIALS)
    bottom_all=all(rows[m]["identity"]["bottom_identity_pass"] for m in MATERIALS)
    constitutive_all=all(rows[m]["identity"]["constitutive_identity_pass"] for m in MATERIALS)
    e2=internal_all and bottom_all and constitutive_all
    if not constitutive_all:
        decision="B1HCE_E1_CONSTITUTIVE_IDENTITY_BLOCKED"
    elif not internal_all:
        decision="B1HCE_E1_INTERNAL_OPERATOR_IDENTITY_BLOCKED"
    elif not bottom_all:
        decision="B1HCE_E1_BOTTOM_TERMINAL_OPERATOR_SEMANTICS_DIFFER_E2_HELD"
    else:
        decision="B1HCE_E1_EQUAL_GRID_OPERATOR_IDENTITY_E2_AUTHORIZED"

    bottom={
      m:rows[m]["bottom_pointwise_candidate_minus_logged_reference_flux"]["R16_OP"]
      for m in MATERIALS
    }
    critical={}
    for m in MATERIALS:
        critical[m]={}
        for member in ("L4","L6","R8"):
            faces=rows[m]["internal_interface_flux_diagnostic"][member]
            critical[m][member]=max(
                ({"face_cm":face,**v} for face,v in faces.items()),
                key=lambda x:x["rms"]
            )

    result={
      "schema":"swap5.layer-rom.phase-b1hce.e1.aggregate-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCE-E1",
      "decision":decision,
      "identity":{
        "all_material_R16_internal_identity_pass":internal_all,
        "all_material_R16_bottom_identity_pass":bottom_all,
        "all_material_constitutive_identity_pass":constitutive_all,
        "E2_authorized":e2
      },
      "R16_bottom_pointwise_by_material":bottom,
      "critical_internal_interface_by_material_member":critical,
      "material_results":rows,
      "next":(
        "Execute frozen E2 temporal ladder exactly as preregistered."
        if e2 else
        "Hold E2. Reconcile terminal-flux evaluation/state semantics against Reference SWKIMPL=0 and accepted-interval observation semantics before changing any boundary closure or time integrator."
      ),
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,
      "identity":result["identity"],
      "R16_bottom":bottom,
      "critical_internal":critical
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
