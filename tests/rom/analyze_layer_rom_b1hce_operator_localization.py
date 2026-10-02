#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
from collections import defaultdict

import numpy as np

HISTS=("X01","X02","X03","X04")
MEMBERS={
    "L4":[0.0,130.0,140.0,150.0,160.0],
    "L6":[0.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R8":[0.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
    "R16_OP":[float(x) for x in range(0,161,10)],
}


def fields(payload:str)->dict[str,str]:
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1)
            out[k]=v
    return out


def parse_reference(path:pathlib.Path):
    states={}
    nodes=defaultdict(dict)
    for line in path.read_text(errors="replace").splitlines():
        if "F_ROMV2_D13_REF_STATE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_STATE|",1)[1])
            states[(r["HISTORY"].strip(),int(r["STEP"]))]=r
        elif "F_ROMV2_D13_REF_NODE|" in line:
            r=fields(line.split("F_ROMV2_D13_REF_NODE|",1)[1])
            nodes[(r["HISTORY"].strip(),int(r["STEP"]))][int(r["NODE"])]=r
    expected={(h,s) for h in HISTS for s in range(1,1025)}
    if set(states)!=expected or set(nodes)!=expected:
        raise SystemExit(f"reference structure mismatch states={len(states)} nodes={len(nodes)}")
    if any(set(nodes[k])!=set(range(1,17)) for k in expected):
        raise SystemExit("reference node structure mismatch")
    return states,dict(nodes)


def constitutive(params:dict[str,float],theta:float)->tuple[float,float]:
    tr=float(params["theta_r"]);ts=float(params["theta_s"])
    alpha=float(params["alpha_per_cm"]);n=float(params["n"])
    ks=float(params["Ksat_cm_per_day"]);ell=float(params["lambda"])
    m=1.0-1.0/n
    se=(theta-tr)/(ts-tr)
    if not 0.0<se<1.0:
        raise ValueError(f"theta outside constitutive domain {theta}")
    psi=((se**(-1.0/m)-1.0)**(1.0/n))/alpha
    term=1.0-(1.0-se**(1.0/m))**m
    k=ks*(se**ell)*(term**2)
    if not (math.isfinite(psi) and math.isfinite(k) and psi>0.0 and k>=0.0):
        raise ValueError("nonfinite constitutive result")
    return psi,k


def layer_means(theta16:list[float],bounds:list[float])->list[float]:
    out=[]
    for lo,hi in zip(bounds,bounds[1:]):
        total=0.0
        for idx,t in enumerate(theta16):
            a=idx*10.0;b=(idx+1)*10.0
            w=max(0.0,min(hi,b)-max(lo,a))
            total+=t*w
        out.append(total/(hi-lo))
    return out


def layer_flux(params,tu,tl,du,dl):
    pu,ku=constitutive(params,tu)
    pl,kl=constitutive(params,tl)
    kface=(dl*ku+du*kl)/(du+dl)
    return kface*(1.0+2.0*(pl-pu)/(du+dl))


def fine_face_flux(params,theta16,boundary):
    i=int(round(boundary/10.0))
    tu=theta16[i-1];tl=theta16[i]
    pu,ku=constitutive(params,tu)
    pl,kl=constitutive(params,tl)
    return 0.5*(ku+kl)*(1.0+(pl-pu)/10.0)


def bottom_flux(params,tbottom,dzbottom):
    psi,k=constitutive(params,tbottom)
    return k*(1.0-psi/(0.5*dzbottom))


def summarize(values):
    a=np.asarray(values,dtype=float)
    return {
      "count":int(a.size),
      "rms":float(np.sqrt(np.mean(a*a))) if a.size else 0.0,
      "mean_signed":float(np.mean(a)) if a.size else 0.0,
      "mean_abs":float(np.mean(np.abs(a))) if a.size else 0.0,
      "max_abs":float(np.max(np.abs(a))) if a.size else 0.0,
    }


def sign(x):
    return 1 if x>0 else (-1 if x<0 else 0)


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--b1h-result",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_FIXED_HEAD_OPERATOR_LOCALIZATION":
        raise SystemExit("wrong B1HCE preregistration phase")
    b1h=json.loads(a.b1h_result.read_text())
    if b1h["material"]!=a.material or b1h["decision"]!="B1H_MATERIAL_TRANSFER_CHARACTERIZED":
        raise SystemExit("B1H material authority mismatch")
    params=b1h["material_parameters"]
    states,nodes=parse_reference(a.reference)

    psi_res=[]
    internal={m:defaultdict(list) for m in MEMBERS}
    internal_sign={m:defaultdict(int) for m in MEMBERS}
    bottom={m:[] for m in MEMBERS}
    bottom_sign={m:0 for m in MEMBERS}

    for hist in HISTS:
      for step in range(1,1025):
        key=(hist,step)
        theta16=[float(nodes[key][i]["THETA"]) for i in range(1,17)]
        for i in range(1,17):
            psi,_=constitutive(params,theta16[i-1])
            psi_res.append(psi + float(nodes[key][i]["H"]))

        qref_bottom=float(states[key]["BOTTOM_FLUX"])
        for member,bounds in MEMBERS.items():
            means=layer_means(theta16,bounds)
            for j,boundary in enumerate(bounds[1:-1]):
                qcand=layer_flux(
                    params,means[j],means[j+1],
                    bounds[j+1]-bounds[j],bounds[j+2]-bounds[j+1]
                )
                qfine=fine_face_flux(params,theta16,boundary)
                internal[member][str(int(boundary))].append(qcand-qfine)
                internal_sign[member][str(int(boundary))]+=int(
                    sign(qfine)!=0 and sign(qcand)!=sign(qfine)
                )
            qbot=bottom_flux(params,means[-1],bounds[-1]-bounds[-2])
            bottom[member].append(qbot-qref_bottom)
            bottom_sign[member]+=int(sign(qref_bottom)!=0 and sign(qbot)!=sign(qref_bottom))

    interface_results={}
    for member in MEMBERS:
        interface_results[member]={}
        for face,values in sorted(internal[member].items(),key=lambda x:int(x[0])):
            s=summarize(values)
            s["sign_mismatch_count"]=internal_sign[member][face]
            interface_results[member][face]=s

    bottom_results={}
    for member in MEMBERS:
        s=summarize(bottom[member])
        s["sign_mismatch_count"]=bottom_sign[member]
        bottom_results[member]=s

    r16_internal_max=max(
        row["max_abs"] for row in interface_results["R16_OP"].values()
    )
    r16_bottom_max=bottom_results["R16_OP"]["max_abs"]
    psi_max=max(abs(x) for x in psi_res)
    gates=pre["stage_E1_teacher_forced_operator_localization"]["hard_identity_gates"]
    identity={
      "R16_OP_internal_interface_max_abs_cm_per_day":r16_internal_max,
      "R16_OP_internal_interface_gate_cm_per_day":float(gates["R16_OP_internal_interface_max_abs_cm_per_day"]),
      "bottom_pointwise_R16_OP_max_abs_cm_per_day":r16_bottom_max,
      "bottom_pointwise_R16_OP_gate_cm_per_day":float(gates["bottom_pointwise_R16_OP_max_abs_cm_per_day"]),
      "constitutive_psi_vs_logged_head_max_abs_cm":psi_max,
      "constitutive_gate_cm":float(gates["constitutive_psi_vs_logged_head_max_abs_cm"]),
    }
    identity["internal_identity_pass"]=r16_internal_max<=identity["R16_OP_internal_interface_gate_cm_per_day"]
    identity["bottom_identity_pass"]=r16_bottom_max<=identity["bottom_pointwise_R16_OP_gate_cm_per_day"]
    identity["constitutive_identity_pass"]=psi_max<=identity["constitutive_gate_cm"]
    identity["E2_authorized"]=all((
        identity["internal_identity_pass"],
        identity["bottom_identity_pass"],
        identity["constitutive_identity_pass"],
    ))

    if not identity["constitutive_identity_pass"]:
        decision="B1HCE_E1_CONSTITUTIVE_IDENTITY_BLOCKED"
    elif not identity["internal_identity_pass"]:
        decision="B1HCE_E1_INTERNAL_OPERATOR_IDENTITY_BLOCKED"
    elif not identity["bottom_identity_pass"]:
        decision="B1HCE_E1_BOTTOM_TERMINAL_OPERATOR_SEMANTICS_DIFFER"
    else:
        decision="B1HCE_E1_EQUAL_GRID_OPERATOR_IDENTITY_E2_AUTHORIZED"

    result={
      "schema":"swap5.layer-rom.phase-b1hce.e1.material-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCE-E1",
      "material":a.material,
      "decision":decision,
      "identity":identity,
      "internal_interface_flux_diagnostic":interface_results,
      "bottom_pointwise_candidate_minus_logged_reference_flux":bottom_results,
      "interpretation_firewalls":[
        "The fine internal-face quantity is a Darcy diagnostic reconstructed from the immutable committed Reference state, not a separately logged internal Reference flux.",
        "The logged BOTTOM_FLUX is the Reference backend terminal bottom outward flux returned for the accepted interval; disagreement with an algebraic flux reconstructed from the committed state can reflect evaluation-time/state semantics and is not automatically a different boundary formula.",
        "No Layer-ROM state is propagated in E1.",
        "No application acceptance or speed claim is made."
      ],
      "reduced_state_propagated":False,
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "material":a.material,
      "decision":decision,
      "identity":identity,
      "bottom":bottom_results,
      "critical_internal":{
        m:max(
          ({"face_cm":face,**row} for face,row in interface_results[m].items()),
          key=lambda r:r["rms"]
        ) for m in MEMBERS
      }
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
