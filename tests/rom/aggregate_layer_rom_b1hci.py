#!/usr/bin/env python3
import argparse,json,pathlib
from collections import Counter
MATS=("B02","B05","B06","B11","B12","B16")
COMPS=("storage_rms","cumulative_bottom_rms","qavg_rms","qend_rms","mapped_theta_rms")
def find(root,m):
    xs=list(root.rglob(f"LAYER_ROM_B1HCI_{m}_RESULT.json"))
    if len(xs)!=1: raise RuntimeError((m,len(xs)))
    return xs[0]
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--input-dir",type=pathlib.Path,required=True)
    p.add_argument("--prereg",type=pathlib.Path,required=True)
    p.add_argument("--output",type=pathlib.Path,required=True)
    a=p.parse_args()
    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_INDEPENDENT_NUMERICAL_ORACLE_RESULTS"
    rows={m:json.loads(find(a.input_dir,m).read_text()) for m in MATS}
    for m,r in rows.items():
        assert r["material"]==m and r["integrity"]["pass"]
        assert r["integrity"]["reference_trajectory_used"] is False
    ds={m:rows[m]["decision"] for m in MATS}
    unresolved=[m for m in MATS if ds[m]=="B1HCI_MATERIAL_ORACLE_UNRESOLVED"]
    supported=[m for m in MATS if ds[m]=="B1HCI_MATERIAL_HEUN_LIMIT_SUPPORTED"]
    mixed=[m for m in MATS if ds[m]=="B1HCI_MATERIAL_HEUN_ORACLE_RELATION_MIXED"]
    labels=pre["panel_decision_labels"]
    decision=labels["oracle_unresolved"] if unresolved else (labels["all_six_supported"] if len(supported)==6 else labels["mixed"])
    oracle_counts={c:sum(bool(rows[m]["R16_OP"]["components"][c]["oracle_agreement_pass"]) for m in MATS) for c in COMPS}
    heun_counts={c:sum(bool(rows[m]["R16_OP"]["components"][c]["heun_pass"]) for m in MATS) for c in COMPS}
    class_counts={c:dict(Counter(rows[m]["R16_OP"]["components"][c]["heun_classification"] for m in MATS)) for c in COMPS}
    focus={m:{"decision":rows[m]["decision"],"components":rows[m]["R16_OP"]["components"]} for m in ("B11","B12")}
    if decision==labels["all_six_supported"]:
        sci=[
          "The independent DOP853/Radau oracle pair is numerically resolved on all six materials under the frozen gates.",
          "Fixed-step Heun approaches the independent ODE oracle on every primary R16_OP component across all six materials.",
          "The B1HCH formal exceptions do not indicate a materially unresolved Heun limit on this panel.",
          "The next causal axis is finite-Reference temporal/discretization contribution, not closure or state redesign."
        ]
        nxt="Preregister finite-Reference temporal/discretization diagnosis on the same six-material fixed-head panel."
    elif unresolved:
        sci=["At least one material/component fails independent-oracle agreement; no model-form inference is authorized."]
        nxt="Repair or replace the numerical oracle route before Reference refinement or closure/state redesign."
    else:
        sci=["Independent-oracle agreement is sufficient where declared, but the Heun-to-oracle relation is not supported everywhere.","Closure/state redesign remains held."]
        nxt="Diagnose unsupported Heun-to-oracle components before Reference refinement or model redesign."
    out={
      "schema":"swap5.layer-rom.phase-b1hci.aggregate-result.v1","workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCI",
      "decision":decision,"materials":list(MATS),"material_decisions":ds,"supported_materials":supported,
      "oracle_unresolved_materials":unresolved,"mixed_heun_oracle_materials":mixed,
      "component_oracle_agreement_count_of_6":oracle_counts,"component_heun_pass_count_of_6":heun_counts,
      "component_heun_classification_counts":class_counts,"B11_B12_focus":focus,
      "scientific_adjudication":sci,"next":nxt,
      "application_acceptance_adjudicated":False,"performance_measurement_performed":False,"production_rom_authorized":False}
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"decision":decision,"material_decisions":ds,"oracle_counts":oracle_counts,"heun_counts":heun_counts,"next":nxt},sort_keys=True))
if __name__=="__main__": main()
