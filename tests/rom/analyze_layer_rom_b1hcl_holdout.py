#!/usr/bin/env python3
from __future__ import annotations
import argparse,importlib.util,json,pathlib,sys
from typing import Any
import numpy as np

COMPONENTS={
    "storage_rms":"storage",
    "cumulative_bottom_rms":"cumulative_bottom",
    "qavg_rms":"qavg",
    "qend_rms":"qend",
    "mapped_theta_rms":"mapped_theta",
}
HISTS=("X01","X02","X03","X04")

def load(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod)
    return mod

def linear_route(a:dict[str,Any],b:dict[str,Any],wa:float,wb:float)->dict[str,Any]:
    out={"series":{}}
    for h in HISTS:
        out["series"][h]={}
        for key in ("S","C","QAVG","QEND","theta"):
            x=np.asarray(a["series"][h][key],dtype=float)
            y=np.asarray(b["series"][h][key],dtype=float)
            if x.shape!=y.shape:
                raise RuntimeError(f"shape mismatch {h} {key}")
            z=wa*x+wb*y
            if not np.all(np.isfinite(z)):
                raise RuntimeError(f"nonfinite linear route {h} {key}")
            out["series"][h][key]=z.tolist()
    return out

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True)
    ap.add_argument("--mid-reference",required=True,type=pathlib.Path)
    ap.add_argument("--fine-reference",required=True,type=pathlib.Path)
    ap.add_argument("--ultra-reference",required=True,type=pathlib.Path)
    ap.add_argument("--b1hck-result",required=True,type=pathlib.Path)
    ap.add_argument("--panel",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hci-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_FOURTH_REFERENCE_LEVEL_RESPONSE":
        raise SystemExit("wrong B1HCL phase")
    if int(pre["hypothesis"]["frozen_order"])!=1:
        raise SystemExit("Richardson order drift")
    if a.material not in pre["scope"]["materials"]:
        raise SystemExit("material outside frozen panel")

    ck=json.loads(a.b1hck_result.read_text())
    if ck["material"]!=a.material or ck["decision"]!="REFERENCE_TEMPORAL_NOT_YET_BOUNDED":
        raise SystemExit("B1HCK material authority drift")

    b0=json.loads(a.panel.read_text())
    bp=json.loads(a.b1h_prereg.read_text())
    mat=next(x for x in b0["panel"] if x["id"]==a.material)
    lams=[float(x) for x in bp["initial_state_transfer"]["frozen_scaled_lambda"][a.material]]

    ckmod=load("b1hcl_ck",pathlib.Path("tests/rom/analyze_layer_rom_b1hck_reference_temporal.py"))
    ci=load("b1hcl_ci",pathlib.Path("tests/rom/analyze_layer_rom_b1hci_oracle.py"))
    mid=ckmod.parse_reference(a.mid_reference,2)
    fine=ckmod.parse_reference(a.fine_reference,4)
    ultra=ckmod.parse_reference(a.ultra_reference,8)

    # Reproduce immutable B1HCK mid-fine diagnostics before using the new holdout.
    midfine=ci.pooled_stats(mid,fine)
    for comp,obs in COMPONENTS.items():
        old=float(ck["components"][comp]["reference_mid_fine_rms"])
        new=float(midfine[obs]["rms"])
        if abs(old-new)>max(1e-15,1e-12*max(abs(old),abs(new),1.0)):
            raise RuntimeError(f"B1HCK mid-fine reproduction drift {comp}: {old} {new}")

    c4v=ci.load("b1hcl_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    ci.patch_material(c4v,mat,lams)
    reps={x["id"]:x for x in bp["representations"]}
    cip=json.loads(a.b1hci_prereg.read_text())
    ospec=next(x for x in cip["independent_oracles"] if x["id"]=="DOP853_STRICT")
    dop=ci.run_oracle(c4v,reps["R16_OP"],ospec,1e-10)

    fine_ultra=ci.pooled_stats(fine,ultra)
    dop_fine=ci.pooled_stats(dop,fine)
    dop_ultra=ci.pooled_stats(dop,ultra)
    predicted_ultra=linear_route(fine,mid,1.5,-0.5)
    prediction_error=ci.pooled_stats(predicted_ultra,ultra)
    richardson=linear_route(ultra,fine,2.0,-1.0)
    dop_richardson=ci.pooled_stats(dop,richardson)

    floors={k:float(v) for k,v in pre["numerical_floors"].items() if k!="source"}
    components={}
    for comp,obs in COMPONENTS.items():
        floor=floors[comp]
        prev=float(midfine[obs]["rms"])
        fu=float(fine_ultra[obs]["rms"])
        df=float(dop_fine[obs]["rms"])
        du=float(dop_ultra[obs]["rms"])
        hp=float(prediction_error[obs]["rms"])
        rr=float(dop_richardson[obs]["rms"])
        g1=fu<=prev+floor
        g2=du<=df+floor
        pred_bound=max(floor,0.10*fu)
        rich_bound=max(floor,0.10*du)
        g3=hp<=pred_bound
        g4=rr<=rich_bound
        components[comp]={
          "observable":obs,
          "absolute_floor":floor,
          "B1HCK_mid_fine_rms":prev,
          "fine_ultra_rms":fu,
          "fine_ultra_over_mid_fine":fu/max(prev,floor),
          "observed_order_log2_midfine_over_fineultra":(
              float(np.log2(prev/fu)) if prev>floor and fu>0 else None
          ),
          "DOP853_to_fine_rms":df,
          "DOP853_to_ultra_rms":du,
          "DOP853_ultra_over_fine":du/max(df,floor),
          "holdout_prediction_to_ultra_rms":hp,
          "holdout_prediction_bound":pred_bound,
          "DOP853_to_Richardson_limit_rms":rr,
          "Richardson_limit_bound":rich_bound,
          "gates":{
             "continued_reference_convergence":g1,
             "continued_candidate_convergence":g2,
             "holdout_prediction_bound":g3,
             "richardson_limit_bound":g4,
          },
          "supported":g1 and g2 and g3 and g4,
        }

    supported=all(x["supported"] for x in components.values())
    decision=(
      "B1HCL_MATERIAL_FIRST_ORDER_LIMIT_SUPPORTED"
      if supported else "B1HCL_MATERIAL_FIRST_ORDER_LIMIT_MIXED"
    )
    result={
      "schema":"swap5.layer-rom.phase-b1hcl.material-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCL",
      "decision":decision,"material":a.material,
      "components":components,
      "reference_pairwise":{
        "mid_fine":midfine,"fine_ultra":fine_ultra,
      },
      "candidate":{
        "DOP853_to_fine":dop_fine,
        "DOP853_to_ultra":dop_ultra,
        "DOP853_to_Richardson_limit":dop_richardson,
      },
      "holdout_prediction_to_ultra":prediction_error,
      "integrity":{
        "pass":True,
        "ultra_max_abs_interval_mass_cm":float(ultra["max_abs_interval_mass_cm"]),
        "ultra_max_abs_common_time_water_ledger_cm":float(ultra["max_abs_common_time_water_ledger_cm"]),
        "DOP853_max_abs_water_ledger_cm":float(dop["max_abs_water_ledger_cm"]),
        "B1HCK_mid_fine_reproduced":True,
        "hydrological_model_changed":False,
      },
      "interpretation_firewalls":[
        "The p=1 extrapolation and both 0.10 confirmation bounds were frozen before the ultrafine Reference response.",
        "No Richardson order is fitted to the ultrafine result.",
        "Support concerns the temporal limit of this fixed 16-cell laboratory, not the continuous Richards PDE or application acceptance."
      ],
      "application_acceptance_adjudicated":False,
      "performance_measurement_performed":False,
      "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "material":a.material,"decision":decision,
      "components":components,
      "ultra_mass":result["integrity"]["ultra_max_abs_interval_mass_cm"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
