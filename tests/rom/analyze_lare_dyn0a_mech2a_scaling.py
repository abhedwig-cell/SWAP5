#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib, re
from collections import defaultdict

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
M=1.0-1.0/N
KS=31.225016
LAM=0.98087
OBS_DT=0.0008
TPULSE=256*OBS_DT
TFULL=1024*OBS_DT
SE_BY_INDEX={1:0.65,2:0.85,3:0.95}
FORCING_BY_INDEX={1:"EQ",2:"WET",3:"DRY",4:"WET_DRY"}
LADDER=list(range(10,141,10))


def fields(payload):
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out


def h_from_se(se):
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA


def k_from_h(h):
    se=(1.0+(ALPHA*abs(h))**N)**(-M)
    return KS*(se**LAM)*(1.0-(1.0-se**(1.0/M))**M)**2


def capacity_from_h(h):
    psi=abs(h)
    term=1.0+(ALPHA*psi)**N
    return (TS-TR)*M*N*(ALPHA**N)*(psi**(N-1.0))*term**(-M-1.0)


def psi_from_theta(theta):
    se=(theta-TR)/(TS-TR)
    if not 0.0 < se < 1.0:
        raise ValueError(f"invalid mean effective saturation {se}")
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA


def k_from_theta(theta):
    se=(theta-TR)/(TS-TR)
    if not 0.0 < se < 1.0:
        raise ValueError(f"invalid mean effective saturation {se}")
    return KS*(se**LAM)*(1.0-(1.0-se**(1.0/M))**M)**2


def load_case(path):
    rows=defaultdict(list)
    for line in path.read_text(errors="replace").splitlines():
        if not line.startswith("LAREDYN0R_NODE|"):
            continue
        d=fields(line.split("|",1)[1])
        rows[int(d["STEP"])].append({
            "node":int(d["NODE"]),
            "z":float(d["Z"]),
            "dz":float(d["DZ"]),
            "h":float(d["H"]),
            "theta":float(d["THETA"]),
        })
    if set(rows)!=set(range(1,1025)):
        raise ValueError(f"incomplete trajectory {path}")
    for step in rows:
        rows[step].sort(key=lambda r:r["node"])
    return dict(rows)


def layer_mean(rows,lo,hi):
    width=hi-lo
    covered=0.0; th=0.0
    for r in rows:
        c=abs(r["z"]); a=max(lo,c-r["dz"]/2); b=min(hi,c+r["dz"]/2)
        if b<=a: continue
        w=b-a; covered+=w; th+=r["theta"]*w
    if abs(covered-width)>1e-9:
        raise ValueError((lo,hi,covered))
    return th/width


def flux_error_at_interface(rows,L):
    # First interface of nested partition: coarse upper layer [0,L] and exact 10-cm lower layer [L,L+10].
    theta_up=layer_mean(rows,0.0,float(L))
    theta_lo=layer_mean(rows,float(L),float(L+10))
    psi_up=psi_from_theta(theta_up)
    psi_lo=psi_from_theta(theta_lo)
    k_up=k_from_theta(theta_up)
    k_lo=k_from_theta(theta_lo)
    du=float(L); dl=10.0
    kface=(dl*k_up+du*k_lo)/(du+dl)
    q_lare=kface*(1.0+2.0*(psi_lo-psi_up)/(du+dl))

    upper_node=L//10
    lower_node=upper_node+1
    ru=rows[upper_node-1]; rl=rows[lower_node-1]
    kref=0.5*(k_from_h(ru["h"])+k_from_h(rl["h"]))
    qref=kref*(1.0+((-rl["h"])-(-ru["h"]))/10.0)
    return q_lare-qref


def rms(values):
    return math.sqrt(sum(v*v for v in values)/len(values))


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--status",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    prereg=json.loads(args.prereg.read_text())
    assert prereg["phase"]=="FORMALIZE_EXPLORATORY_B01_SCALING_BEFORE_CROSS_MATERIAL_VALIDATION"
    assert prereg["prior_exposure"]["exploratory_B01_curve_seen"] is True

    status=json.loads(args.status.read_text())
    qualified=[c for c,r in status["geometries"]["fine"].items() if r["status"]=="QUALIFIED"]

    scaling={}
    pulse_peak=[]
    for case in sorted(qualified):
        m=re.fullmatch(r"S([123])_B1_F([1234])",case)
        if not m: raise ValueError(case)
        se0=SE_BY_INDEX[int(m.group(1))]
        forcing=FORCING_BY_INDEX[int(m.group(2))]
        h0=h_from_se(se0)
        D0=k_from_h(h0)/capacity_from_h(h0)
        ell_p=math.sqrt(D0*TPULSE)
        ell_f=math.sqrt(D0*TFULL)
        traj=load_case(args.reference_dir/f"fine-{case}-o2.txt")

        ladder={}
        for L in LADDER:
            errs=[flux_error_at_interface(traj[step],L) for step in range(1,1025)]
            pulse=errs[:256]
            ladder[str(L)]={
                "dimension":1+(160-L)//10,
                "lambda_pulse":L/ell_p,
                "lambda_full":L/ell_f,
                "pulse_rms_flux_error_cm_per_day":rms(pulse),
                "pulse_max_abs_flux_error_cm_per_day":max(abs(x) for x in pulse),
                "full_rms_flux_error_cm_per_day":rms(errs),
                "full_max_abs_flux_error_cm_per_day":max(abs(x) for x in errs),
            }

        case_result={
            "se0":se0,
            "forcing":forcing,
            "h0_cm":h0,
            "K0_cm_per_day":k_from_h(h0),
            "C0_per_cm":capacity_from_h(h0),
            "D0_cm2_per_day":D0,
            "ell_pulse_cm":ell_p,
            "ell_full_cm":ell_f,
            "ladder":ladder,
        }
        if forcing in {"WET","DRY"}:
            peak_L=max(LADDER,key=lambda L:ladder[str(L)]["pulse_rms_flux_error_cm_per_day"])
            case_result["pulse_peak"]={
                "L_cm":peak_L,
                "lambda_pulse":ladder[str(peak_L)]["lambda_pulse"],
                "rms_flux_error_cm_per_day":ladder[str(peak_L)]["pulse_rms_flux_error_cm_per_day"],
            }
            pulse_peak.append({
                "case":case,
                "se0":se0,
                "forcing":forcing,
                **case_result["pulse_peak"],
            })
        scaling[case]=case_result

    peaks=[row["lambda_pulse"] for row in pulse_peak]
    observed_band=[min(peaks),max(peaks)]
    prior_band=prereg["exploratory_pattern_to_record"]["previously_seen_peak_lambda_band"]
    reproduced=(observed_band[0]>=prior_band[0]-1e-12 and observed_band[1]<=prior_band[1]+1e-12)

    result={
        "schema":"swap5.lare.dyn0a.mech2a.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-MECH2A",
        "decision":"B01_DIFFUSION_LENGTH_PATTERN_REPRODUCED" if reproduced else "B01_DIFFUSION_LENGTH_PATTERN_NOT_REPRODUCED",
        "qualified_reference_cases":sorted(qualified),
        "pulse_peak_cases":pulse_peak,
        "pulse_peak_lambda_observed_band":observed_band,
        "pulse_peak_lambda_mean":sum(peaks)/len(peaks),
        "exploratory_band_predeclared":prior_band,
        "pattern_reproduced":reproduced,
        "cases":scaling,
        "interpretation":[
            "B01 is an exposed mechanism dataset, not an independent transfer validation.",
            "The nested ladder changes only the position of the first coarse-to-10cm interface; no new LARE trajectory is propagated.",
            "The dimensionless lambda=L/sqrt(D0*T) uses initial-state linearized Richards diffusivity and is diagnostic, not yet a universal grid rule."
        ],
        "cross_material_generalization_claimed":False,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],
        "decision":result["decision"],
        "pulse_peak_cases":pulse_peak,
        "pulse_peak_lambda_observed_band":observed_band,
        "pulse_peak_lambda_mean":result["pulse_peak_lambda_mean"],
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
