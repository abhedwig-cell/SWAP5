#!/usr/bin/env python3
from __future__ import annotations

import argparse,importlib.util,json,math,pathlib,sys

COMPONENTS={
  "storage_rms":"storage","cumulative_bottom_rms":"cumulative_bottom",
  "qavg_rms":"qavg","qend_rms":"qend","mapped_theta_rms":"mapped_theta"
}

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None: raise RuntimeError(path)
    m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m);return m

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--member",required=True)
    ap.add_argument("--mid-dir",required=True,type=pathlib.Path)
    ap.add_argument("--fine-dir",required=True,type=pathlib.Path)
    ap.add_argument("--ultra-dir",required=True,type=pathlib.Path)
    ap.add_argument("--ref-fine",required=True,type=pathlib.Path)
    ap.add_argument("--ref-ultra",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--b1hcm-result",required=True,type=pathlib.Path)
    ap.add_argument("--basis-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_B05_L6_R8_FOURTH_CORICHARDS_TEMPORAL_RESPONSE":
        raise SystemExit("wrong B1HCO preregistration")
    specs={x["id"]:x for x in pre["scope"]["members"]}
    if a.member not in specs: raise SystemExit("member outside B1HCO scope")
    spec=specs[a.member];bounds=[0.0]
    for d in spec["thickness_cm"]: bounds.append(bounds[-1]+float(d))

    b1h=json.loads(a.b1h_result.read_text());bp=json.loads(a.b1h_prereg.read_text())
    cm=json.loads(a.b1hcm_result.read_text())
    if b1h["material"]!="B05" or cm["material"]!="B05": raise SystemExit("B05 authority drift")
    lambdas=[float(x) for x in bp["initial_state_transfer"]["frozen_scaled_lambda"]["B05"]]
    if max(abs(x-y) for x,y in zip(lambdas,[float(x) for x in b1h["scaled_lambdas"]]))>1e-15:
        raise SystemExit("lambda drift")

    n=load_module("b1hco_n",pathlib.Path("tests/rom/analyze_layer_rom_b1hcn_corichards_temporal.py"))
    h=load_module("b1hco_h",pathlib.Path("tests/rom/analyze_layer_rom_b1hcl_richardson.py"))
    ci=load_module("b1hco_ci",pathlib.Path("tests/rom/analyze_layer_rom_b1hci_oracle.py"))
    c4v=ci.load("b1hco_c4v",a.basis_dir/"analyze_lare_bc2_c4v_one_day.py")
    ci.patch_material(c4v,b1h["material_parameters"],lambdas)

    mid=n.load_route(a.mid_dir,a.member,2,bounds,c4v,prefix="COR_MID")
    fine=n.load_route(a.fine_dir,a.member,4,bounds,c4v,prefix="COR_FINE")
    ultra=n.load_route(a.ultra_dir,a.member,8,bounds,c4v,prefix="COR_ULTRA")

    pred=n.linear_route(fine,mid,1.5,-0.5)
    cstar=n.linear_route(ultra,fine,2.0,-1.0)
    mf=ci.pooled_stats(mid,fine);fu=ci.pooled_stats(fine,ultra);pu=ci.pooled_stats(pred,ultra)

    floors={k:float(v) for k,v in pre["numerical_floors"].items() if k!="source"}
    temporal={}
    for comp,obs in COMPONENTS.items():
        floor=floors[comp]
        e1=float(mf[obs]["rms"]);e2=float(fu[obs]["rms"]);ep=float(pu[obs]["rms"])
        conv=e2<=e1+floor
        bound=max(floor,0.10*e2)
        pp=ep<=bound
        order=None if e1<=floor or e2<=floor else math.log(e1/e2,2.0)
        temporal[comp]={
          "mid_fine_rms":e1,"fine_ultra_rms":e2,
          "ultra_prediction_rms":ep,"prediction_bound":bound,
          "continued_convergence":conv,"prediction_pass":pp,
          "observed_order":order,"pass":conv and pp
        }
    supported=all(x["pass"] for x in temporal.values())

    rf=h.parse_reference(a.ref_fine,4);ru=h.parse_reference(a.ref_ultra,8)
    rstar=h.linear_route(ru,rf,2.0,-1.0)
    cr=ci.pooled_stats(cstar,rstar)
    cor={
      "storage_rms_cm":float(cr["storage"]["rms"]),
      "cumulative_bottom_rms_cm":float(cr["cumulative_bottom"]["rms"]),
      "qavg_rms_cm_per_day":float(cr["qavg"]["rms"]),
      "qavg_sign_mismatch":n.sign_mismatch(cstar,rstar,"QAVG"),
      "qend_rms_cm_per_day":float(cr["qend"]["rms"]),
      "qend_sign_mismatch":n.sign_mismatch(cstar,rstar,"QEND"),
      "mapped_theta_rms":float(cr["mapped_theta"]["rms"]),
      "max_abs_final_cumulative_bottom_error_cm":n.final_cumulative_max(cstar,rstar)
    }
    lr=cm["representations"][a.member]
    layer={
      "storage_rms_cm":float(lr["fidelity"]["storage"]["rms"]),
      "cumulative_bottom_rms_cm":float(lr["fidelity"]["cumulative_bottom"]["rms"]),
      "qavg_rms_cm_per_day":float(lr["fidelity"]["qavg"]["rms"]),
      "qavg_sign_mismatch":int(lr["sign_mismatch"]["QAVG"]),
      "qend_rms_cm_per_day":float(lr["fidelity"]["qend"]["rms"]),
      "qend_sign_mismatch":int(lr["sign_mismatch"]["QEND"]),
      "mapped_theta_rms":float(lr["fidelity"]["mapped_theta"]["rms"]),
      "max_abs_final_cumulative_bottom_error_cm":float(lr["max_abs_final_cumulative_bottom_error_cm"])
    }
    relation=n.vector_relation(layer,cor) if supported else "HELD_TEMPORAL_UNRESOLVED"
    decision=(pre["decisions"]["supported"] if supported else pre["decisions"]["unresolved"])
    result={
      "schema":"swap5.layer-rom.phase-b1hco.member-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCO",
      "material":"B05","member":a.member,"decision":decision,
      "temporal":temporal,
      "max_mass_residual_cm":{"ultra":ultra["maxmass"]},
      "continuous_time_fidelity":{"LayerROM":layer,"CoRichards":cor},
      "groundwater_relation":relation,
      "profile_relation":(
        "LayerROM" if layer["mapped_theta_rms"]<cor["mapped_theta_rms"]-1e-12
        else ("CoRichards" if cor["mapped_theta_rms"]<layer["mapped_theta_rms"]-1e-12 else "NUMERICALLY_EQUAL")
      ) if supported else "HELD_TEMPORAL_UNRESOLVED",
      "integrity":{"pass":True,"temporal_supported":supported,"hydrological_model_changed":False},
      "interpretation_firewalls":[
        "The fourth level is a prospective holdout for only the two predeclared B05 cells.",
        "The temporal order remains frozen at one even if observed order differs.",
        "Model-form relation is held unless every component in this cell passes the frozen holdout gate."
      ],
      "application_acceptance_adjudicated":False,
      "performance_measurement_performed":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"member":a.member,"decision":decision,"temporal":temporal,
                      "LayerROM":layer,"CoRichards":cor,"groundwater_relation":relation,
                      "profile_relation":result["profile_relation"]},sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
