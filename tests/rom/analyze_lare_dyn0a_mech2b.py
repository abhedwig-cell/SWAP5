#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib,re
from collections import defaultdict

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
            k,v=item.split("=",1);out[k]=v
    return out


def make_hydraulics(mvg):
    tr=float(mvg["theta_r"]);ts=float(mvg["theta_s"]);a=float(mvg["alpha_per_cm"])
    n=float(mvg["n"]);ks=float(mvg["Ksat_cm_per_day"]);lam=float(mvg["lambda"])
    m=1.0-1.0/n
    def h_from_se(se):
        return -((se**(-1.0/m)-1.0)**(1.0/n))/a
    def k_from_h(h):
        se=(1.0+(a*abs(h))**n)**(-m)
        return ks*(se**lam)*(1.0-(1.0-se**(1.0/m))**m)**2
    def capacity_from_h(h):
        psi=abs(h);term=1.0+(a*psi)**n
        return (ts-tr)*m*n*(a**n)*(psi**(n-1.0))*term**(-m-1.0)
    def psi_from_theta(theta):
        se=(theta-tr)/(ts-tr)
        if not 0.0<se<1.0: raise ValueError(se)
        return ((se**(-1.0/m)-1.0)**(1.0/n))/a
    def k_from_theta(theta):
        se=(theta-tr)/(ts-tr)
        if not 0.0<se<1.0: raise ValueError(se)
        return ks*(se**lam)*(1.0-(1.0-se**(1.0/m))**m)**2
    return h_from_se,k_from_h,capacity_from_h,psi_from_theta,k_from_theta


def load_case(path):
    rows=defaultdict(list)
    for line in path.read_text(errors="replace").splitlines():
        if not line.startswith("LAREDYN0R_NODE|"): continue
        d=fields(line.split("|",1)[1])
        rows[int(d["STEP"])].append({
            "node":int(d["NODE"]),"z":float(d["Z"]),"dz":float(d["DZ"]),
            "h":float(d["H"]),"theta":float(d["THETA"])
        })
    if set(rows)!=set(range(1,1025)): raise ValueError(f"incomplete {path}")
    for step in rows: rows[step].sort(key=lambda r:r["node"])
    return dict(rows)


def layer_mean(rows,lo,hi):
    width=hi-lo;covered=0.0;th=0.0
    for r in rows:
        c=abs(r["z"]);a=max(lo,c-r["dz"]/2);b=min(hi,c+r["dz"]/2)
        if b<=a: continue
        w=b-a;covered+=w;th+=r["theta"]*w
    if abs(covered-width)>1e-9: raise ValueError((lo,hi,covered))
    return th/width


def flux_error(rows,L,psi_from_theta,k_from_theta,k_from_h):
    tu=layer_mean(rows,0.0,float(L))
    tl=layer_mean(rows,float(L),float(L+10))
    pu=psi_from_theta(tu);pl=psi_from_theta(tl)
    ku=k_from_theta(tu);kl=k_from_theta(tl)
    du=float(L);dl=10.0
    kface=(dl*ku+du*kl)/(du+dl)
    ql=kface*(1.0+2.0*(pl-pu)/(du+dl))
    iu=L//10;il=iu+1
    ru=rows[iu-1];rl=rows[il-1]
    kr=0.5*(k_from_h(ru["h"])+k_from_h(rl["h"]))
    qr=kr*(1.0+((-rl["h"])-(-ru["h"]))/10.0)
    return ql-qr


def rms(values):
    return math.sqrt(sum(v*v for v in values)/len(values)) if values else 0.0


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference-dir",required=True,type=pathlib.Path)
    ap.add_argument("--status",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    p=json.loads(args.prereg.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_NEW_B14_DYN0A_TRAJECTORY_GENERATION"
    h_from_se,k_from_h,capacity_from_h,psi_from_theta,k_from_theta=make_hydraulics(p["blind_material"]["mvg"])

    status=json.loads(args.status.read_text())["geometries"]["fine"]
    required=[f"S{s}_B1_F{f}" for s in (1,2,3) for f in (2,3)]
    missing=[cid for cid in required if status[cid]["status"]!="QUALIFIED"]

    scaling={}
    peaks=[]
    if not missing:
        for case in sorted(status):
            if status[case]["status"]!="QUALIFIED": continue
            m=re.fullmatch(r"S([123])_B1_F([1234])",case)
            if not m: raise ValueError(case)
            se0=SE_BY_INDEX[int(m.group(1))];forcing=FORCING_BY_INDEX[int(m.group(2))]
            h0=h_from_se(se0);D0=k_from_h(h0)/capacity_from_h(h0)
            ell=math.sqrt(D0*TPULSE);ell_full=math.sqrt(D0*TFULL)
            traj=load_case(args.reference_dir/f"fine-{case}-o2.txt")
            ladder={}
            for L in LADDER:
                errs=[flux_error(traj[step],L,psi_from_theta,k_from_theta,k_from_h) for step in range(1,1025)]
                pulse=errs[:256]
                ladder[str(L)]={
                    "dimension":1+(160-L)//10,
                    "lambda_pulse":L/ell,
                    "lambda_full":L/ell_full,
                    "pulse_rms_flux_error_cm_per_day":rms(pulse),
                    "pulse_max_abs_flux_error_cm_per_day":max(abs(x) for x in pulse),
                    "full_rms_flux_error_cm_per_day":rms(errs),
                    "full_max_abs_flux_error_cm_per_day":max(abs(x) for x in errs)
                }
            row={
                "se0":se0,"forcing":forcing,"h0_cm":h0,
                "K0_cm_per_day":k_from_h(h0),"C0_per_cm":capacity_from_h(h0),
                "D0_cm2_per_day":D0,"ell_pulse_cm":ell,"ell_full_cm":ell_full,
                "ladder":ladder
            }
            if forcing in {"WET","DRY"}:
                peak_L=max(LADDER,key=lambda L:ladder[str(L)]["pulse_rms_flux_error_cm_per_day"])
                row["pulse_peak"]={
                    "L_cm":peak_L,
                    "lambda_pulse":ladder[str(peak_L)]["lambda_pulse"],
                    "rms_flux_error_cm_per_day":ladder[str(peak_L)]["pulse_rms_flux_error_cm_per_day"]
                }
                peaks.append({"case":case,"se0":se0,"forcing":forcing,**row["pulse_peak"]})
            scaling[case]=row

    if missing:
        decision="B14_REFERENCE_BLOCKED"
        anchor_pass={}
    else:
        band=p["trigger_authority"]["B01_observed_peak_lambda_band"]
        by_se=defaultdict(list)
        for row in peaks: by_se[row["se0"]].append(row)
        anchor_pass={}
        for se in (0.65,0.85,0.95):
            pred=p["blind_predictions"][f"Se0_{se:.2f}"]
            checks=[]
            for row in by_se[se]:
                ok=row["L_cm"]==pred["predicted_peak_L_cm"]
                if pred["qualification"]=="DIRECT_BAND_HIT":
                    ok=ok and band[0]-1e-12 <= row["lambda_pulse"] <= band[1]+1e-12
                checks.append(ok)
            anchor_pass[f"{se:.2f}"]=len(checks)==2 and all(checks)
        n=sum(anchor_pass.values())
        if n==3: decision="SCALING_TRANSFER_SUPPORTED"
        elif n>0: decision="SCALING_TRANSFER_PARTIAL"
        else: decision="SCALING_TRANSFER_NOT_SUPPORTED"

    result={
        "schema":"swap5.lare.dyn0a.mech2b.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-DYN0A-MECH2B",
        "decision":decision,
        "required_WET_DRY_reference_cases":required,
        "blocked_required_cases":missing,
        "anchor_prediction_pass":anchor_pass,
        "pulse_peak_cases":peaks,
        "observed_peak_lambda_band":(
            [min(r["lambda_pulse"] for r in peaks),max(r["lambda_pulse"] for r in peaks)]
            if peaks else None
        ),
        "B01_frozen_peak_lambda_band":p["trigger_authority"]["B01_observed_peak_lambda_band"],
        "cases":scaling,
        "interpretation_firewall":[
            "B14 ladder and scaling were frozen before the new B14 DYN0A trajectories were generated.",
            "No B14 parameter, forcing, ladder coordinate or B01 peak band is refitted.",
            "The transfer test concerns mechanism scaling only, not application acceptance or universal grid design."
        ],
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],"decision":decision,
        "blocked_required_cases":missing,
        "anchor_prediction_pass":anchor_pass,
        "pulse_peak_cases":peaks,
        "observed_peak_lambda_band":result["observed_peak_lambda_band"]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
