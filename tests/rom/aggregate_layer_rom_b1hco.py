#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
from collections import Counter

MATERIALS=("B02","B05","B06","B11","B12","B16")
MEMBERS=("L4","L6","R8")
GW=("storage_rms_cm","cumulative_bottom_rms_cm","qavg_rms_cm_per_day","qavg_sign_mismatch",
    "qend_rms_cm_per_day","qend_sign_mismatch","max_abs_final_cumulative_bottom_error_cm")

def find(root:pathlib.Path,member:str)->pathlib.Path:
    xs=list(root.rglob(f"LAYER_ROM_B1HCO_B05_{member}_RESULT.json"))
    if len(xs)!=1: raise SystemExit(f"{member}: expected one result, got {len(xs)}")
    return xs[0]

def nonworse(high,low,tol=1e-12):
    for k in GW:
        if "sign_mismatch" in k:
            if int(high[k])>int(low[k]): return False
        elif float(high[k])>float(low[k])+tol:
            return False
    return True

def relation(layer,cor,tol=1e-12):
    cor_nw=layer_nw=True;cor_strict=layer_strict=False
    for k in GW:
        a=layer[k];b=cor[k]
        if "sign_mismatch" in k:
            if int(b)>int(a): cor_nw=False
            if int(b)<int(a): cor_strict=True
            if int(a)>int(b): layer_nw=False
            if int(a)<int(b): layer_strict=True
        else:
            if float(b)>float(a)+tol: cor_nw=False
            if float(b)<float(a)-tol: cor_strict=True
            if float(a)>float(b)+tol: layer_nw=False
            if float(a)<float(b)-tol: layer_strict=True
    if cor_nw and cor_strict:return "COR_COMPONENTWISE_NO_WORSE"
    if layer_nw and layer_strict:return "LAYER_ROM_COMPONENTWISE_NO_WORSE"
    if cor_nw and layer_nw:return "NUMERICALLY_EQUIVALENT"
    return "TRADEOFF"

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--b1hcn-aggregate",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    old=json.loads(a.b1hcn_aggregate.read_text())
    rows={m:json.loads(find(a.input_dir,m).read_text()) for m in ("L6","R8")}
    for member,r in rows.items():
        if r["material"]!="B05" or r["member"]!=member or not r["integrity"]["pass"]:
            raise SystemExit(f"{member}: identity/integrity drift")

    supported=all(r["integrity"]["temporal_supported"] for r in rows.values())
    decision=pre["decisions"]["supported"] if supported else pre["decisions"]["unresolved"]

    vectors=json.loads(json.dumps(old["continuous_time_vectors"]))
    for member,r in rows.items():
        vectors["B05"][member]={
          "LayerROM":r["continuous_time_fidelity"]["LayerROM"],
          "CoRichards":r["continuous_time_fidelity"]["CoRichards"],
          "groundwater_relation":r["groundwater_relation"],
          "profile_relation":r["profile_relation"],
          "temporal_supported":r["integrity"]["temporal_supported"]
        }

    unresolved=[]
    for m in MATERIALS:
        for member in MEMBERS:
            if not vectors[m][member]["temporal_supported"]:
                unresolved.append(f"{m}:{member}")

    rels={member:Counter() for member in MEMBERS}
    profiles={member:Counter() for member in MEMBERS}
    material_relations={}
    for m in MATERIALS:
        material_relations[m]={}
        for member in MEMBERS:
            cell=vectors[m][member]
            if cell["temporal_supported"]:
                rel=relation(cell["LayerROM"],cell["CoRichards"])
                cell["groundwater_relation"]=rel
                material_relations[m][member]=rel
                rels[member][rel]+=1
                p=cell["profile_relation"]
                if isinstance(p,dict): p=p.get("lower_error_route")
                profiles[member][p]+=1
            else:
                material_relations[m][member]="HELD_TEMPORAL_UNRESOLVED"

    dim={"LayerROM":{},"CoRichards":{}}
    for route in ("LayerROM","CoRichards"):
        for m in MATERIALS:
            l4=vectors[m]["L4"][route];l6=vectors[m]["L6"][route];r8=vectors[m]["R8"][route]
            dim[route][m]={
              "L4_to_L6_componentwise_nonworse":nonworse(l6,l4),
              "L6_to_R8_componentwise_nonworse":nonworse(r8,l6),
              "full_ladder_componentwise_nonworse":nonworse(l6,l4) and nonworse(r8,l6)
            }

    complete=not unresolved and supported
    result={
      "schema":"swap5.layer-rom.phase-b1hco.adjudication.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCO",
      "decision":decision,
      "focused_cells":{m:rows[m] for m in ("L6","R8")},
      "unresolved_cells_after_holdout":unresolved,
      "completed_panel":complete,
      "groundwater_relation_counts":{k:dict(v) for k,v in rels.items()},
      "groundwater_relations":material_relations,
      "profile_lower_error_route_counts":{k:dict(v) for k,v in profiles.items()},
      "dimension_order":dim,
      "continuous_time_vectors":vectors,
      "integrity":{
        "pass":True,"B1HCO_cells_supported":supported,
        "all_18_temporal_cells_supported":complete,
        "only_B05_L6_R8_replaced":True,
        "hydrological_model_changed":False
      },
      "scientific_adjudication":(
        [
          "The prospective fourth CoRichards level resolves both previously held B05 cells under the unchanged first-order temporal hypothesis.",
          "All 18 material-member CoRichards cells are therefore temporally qualified for the bounded fixed-head panel.",
          "The completed same-partition relations compare continuous-time Layer-ROM and temporally extrapolated CoRichards against the same B1HCL Reference temporal limit.",
          "A CoRichards advantage is interpreted as a bounded Layer-ROM-specific model-form/localization burden, not as an additive closure error.",
          "A Layer-ROM advantage indicates that coarse Richards discretization error is not a lower bound on the layer-closure route and may reflect error compensation; it must not be called proof of greater physical fidelity."
        ] if complete else [
          "At least one of the two predeclared B05 cells remains outside the frozen CoRichards temporal-limit gate.",
          "The full 18-cell model-form decomposition remains held. No tolerance or temporal order is retuned."
        ]
      ),
      "application_acceptance_adjudicated":False,
      "performance_measurement_performed":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":decision,"unresolved_cells_after_holdout":unresolved,
      "groundwater_relation_counts":result["groundwater_relation_counts"],
      "groundwater_relations":material_relations,
      "profile_lower_error_route_counts":result["profile_lower_error_route_counts"],
      "dimension_order":dim
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
