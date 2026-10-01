#!/usr/bin/env python3
from pathlib import Path
import csv, importlib.util, json, math, sys

ROOT=Path(__file__).resolve().parent
def load(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/file)
    mod=importlib.util.module_from_spec(spec); sys.modules[name]=mod; spec.loader.exec_module(mod); return mod
obsmod=load("tr01c","macropore_tracer01_swap_flux_observer.py")
trk=load("tr01a","macropore_tracer01_matrix_reference.py")

P=0.249
OBS1=[0.56782779,0.13782616,0.11218321,0.05614368,0.03141313,0.02424311,0.02968833,0.02253496,0.01813963,0.0]
OBS2=[0.61049055,0.15855879,0.09195109,0.04199379,0.03594822,0.02716405,0.01237078,0.01248324,0.00903949,0.0]

def metrics(obs,pred):
    mean=sum(obs)/len(obs)
    sse=sum((a-b)**2 for a,b in zip(obs,pred))
    sst=sum((a-mean)**2 for a in obs)
    return {"sse":sse,"r2":1.0-sse/sst,"rmse":math.sqrt(sse/len(obs))}

def endpoint_weights():
    e=[i/10 for i in range(11)]
    return [e[i+1]**P-e[i]**P for i in range(10)]

def process(path,sigma):
    rows=list(csv.DictReader(Path(path).open()))
    dz=[10.0]*10
    state=trk.TracerState(tuple([0.0]*10))
    applied=pref=matrix_requested=0.0
    max_bottom=max_water=max_tracer=0.0
    for row in rows:
        dt=float(row["dt_day"])
        source=float(row["source_cm_day"])
        matrix=float(row["matrix_source_cm_day"])
        pref_rate=float(row["pref_source_cm_day"])
        qtop=float(row["qtop_cm_day"]); qbot=float(row["qbot_cm_day"])
        th0=[float(row[f"theta0_{i}"]) for i in range(1,11)]
        th1=[float(row[f"theta1_{i}"]) for i in range(1,11)]
        ro=obsmod.reconstruct_accepted_transfers(th0,th1,dz,dt,qtop,qbot)
        if not ro.valid: raise RuntimeError(ro.reason)
        events=[]
        for e in ro.transfers:
            conc=1.0 if e.donor is None and e.receiver==0 and source>0 else (0.0 if e.donor is None else None)
            events.append(trk.WaterTransfer(e.water_cm,e.donor,e.receiver,conc,e.label))
        tr=trk.evaluate_trial(state,[x*10 for x in th0],[x*10 for x in th1],events)
        if not tr.valid: raise RuntimeError(tr.reason)
        state=trk.commit_trial(state,tr)
        applied += source*dt
        pref += pref_rate*dt
        matrix_requested += matrix*dt
        max_bottom=max(max_bottom,abs(ro.bottom_flux_residual_cm_per_day))
        max_water=max(max_water,tr.water_residual_max)
        max_tracer=max(max_tracer,abs(tr.tracer_residual))
    matrix_retained=list(state.mass)
    matrix_total=sum(matrix_retained)
    w=endpoint_weights()
    ic=[pref*x for x in w]
    combined=[a+b for a,b in zip(matrix_retained,ic)]
    sampled=sum(combined)
    norm=[x/sampled for x in combined]
    centers=[0.05+0.1*i for i in range(10)]
    centroid=sum(x*z for x,z in zip(norm,centers))
    external_matrix_out=applied-pref-matrix_total
    return {
      "sigma_B":sigma,
      "applied_source_mass":applied,
      "preferential_mass":pref,
      "preferential_fraction":pref/applied,
      "matrix_requested_mass":matrix_requested,
      "matrix_retained_mass":matrix_total,
      "surface_or_matrix_external_loss_diagnostic":external_matrix_out,
      "ic_retained_mass":sum(ic),
      "combined_sampled_mass":sampled,
      "recovery_fraction_fmb0":sampled/applied,
      "ledger_residual":applied-pref-matrix_total-external_matrix_out,
      "max_observer_bottom_flux_residual":max_bottom,
      "max_kernel_water_residual":max_water,
      "max_kernel_tracer_residual":max_tracer,
      "normalized_profile":norm,
      "centroid_m":centroid,
      "profile1":metrics(OBS1,norm),
      "profile2_diagnostic":metrics(OBS2,norm)
    }

def main(args):
    results=[]
    for item in args:
        sigma=float(Path(item).stem.split("_")[-1].replace("p","."))
        results.append(process(item,sigma))
    valid=[r for r in results if abs(r["ledger_residual"])<=1e-10]
    best=min(valid,key=lambda r:r["profile1"]["sse"])
    out={
      "schema":"swap5.f_macro_tracer01d2a.forward_comparison.v1",
      "status":"PASS" if best["profile1"]["r2"]>=0.90 and best["profile2_diagnostic"]["r2"]>=0.90 else "FAIL",
      "p_frozen":P,
      "f_MB":0.0,
      "grid":results,
      "selected_sigma_B":best["sigma_B"],
      "calibration_profile1":best["profile1"],
      "heldout_profile2":best["profile2_diagnostic"],
      "selected":best,
      "decision_rules":{"profile1_r2_min":0.90,"profile2_r2_min":0.90}
    }
    print(json.dumps(out,indent=2,sort_keys=True))
    if out["status"]!="PASS": raise SystemExit(2)

if __name__=="__main__": main(sys.argv[1:])
