#!/usr/bin/env python3
"""Postprocess TRACER01-D SWAP5 fixture trajectory through observer and tracer kernel."""
from pathlib import Path
import csv, importlib.util, json, sys

ROOT=Path(__file__).resolve().parent
def load(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/file)
    mod=importlib.util.module_from_spec(spec); sys.modules[name]=mod; spec.loader.exec_module(mod); return mod
obs=load('tr01c','macropore_tracer01_swap_flux_observer.py')
trk=load('tr01a','macropore_tracer01_matrix_reference.py')

def main(path):
    rows=list(csv.DictReader(Path(path).open()))
    dz=[10.0]*10
    state=trk.TracerState(tuple([0.0]*10))
    accepted=0; max_bottom=0.0; max_water_res=0.0; max_tracer_res=0.0
    tracer_input=0.0; tracer_output=0.0
    for row in rows:
        dt=float(row['dt_day']); rain=float(row['rain_cm_day'])
        qtop=float(row['qtop_cm_day']); qbot=float(row['qbot_cm_day'])
        th0=[float(row[f'theta0_{i}']) for i in range(1,11)]
        th1=[float(row[f'theta1_{i}']) for i in range(1,11)]
        ro=obs.reconstruct_accepted_transfers(th0,th1,dz,dt,qtop,qbot)
        if not ro.valid: raise RuntimeError(ro.reason)
        events=[]
        for e in ro.transfers:
            conc=1.0 if e.donor is None and e.receiver==0 and rain>0 else (0.0 if e.donor is None else None)
            events.append(trk.WaterTransfer(e.water_cm,e.donor,e.receiver,conc,e.label))
        w0=[th0[i]*dz[i] for i in range(10)]; w1=[th1[i]*dz[i] for i in range(10)]
        tr=trk.evaluate_trial(state,w0,w1,events)
        if not tr.valid: raise RuntimeError(tr.reason)
        state=trk.commit_trial(state,tr)
        accepted+=1; tracer_input+=tr.external_input_mass; tracer_output+=tr.external_output_mass
        max_bottom=max(max_bottom,abs(ro.bottom_flux_residual_cm_per_day))
        max_water_res=max(max_water_res,tr.water_residual_max)
        max_tracer_res=max(max_tracer_res,abs(tr.tracer_residual))
    final_mass=sum(state.mass)
    result={
      'schema':'swap5.f_macro_tracer01d.fixture_composition.v1',
      'status':'SOFTWARE_FIXTURE_ONLY',
      'accepted_packets':accepted,
      'tracer_input_mass':tracer_input,
      'tracer_external_output_mass':tracer_output,
      'tracer_final_matrix_mass':final_mass,
      'global_tracer_residual':tracer_input-tracer_output-final_mass,
      'max_observer_bottom_flux_residual':max_bottom,
      'max_kernel_water_residual':max_water_res,
      'max_kernel_tracer_residual':max_tracer_res,
      'final_tracer_profile':list(state.mass),
    }
    print(json.dumps(result,indent=2,sort_keys=True))

if __name__=='__main__': main(sys.argv[1])
