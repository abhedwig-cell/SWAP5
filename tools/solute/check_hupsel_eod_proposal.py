"""Bounded causal EOD-step experiment; no production qualification or reference replacement."""
import argparse,json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'));import daily_host as h
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--reconcile-existing',action='store_true',help='Validate already completed native runs; execute no model')
a=p.parse_args();a.output=a.output.resolve()
if not a.reconcile_existing:a.output.mkdir()
else:assert a.output.is_dir()
events=json.loads((a.output/'EVENTS.json').read_text()) if a.reconcile_existing else []
frames={};reports={}
for mode in ('control','window562','generic'):
    output=a.output/mode
    if not a.reconcile_existing:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/trace_hupsel_pressure.py'),'--output',str(output),'--first-trace','562','--last','637']
        if mode!='control':
            command+=['--reference',str(a.output/'control/provider'),'--bundle',str(a.output/'control/bundle'),'--full',str(a.output/'control/cold-input'),'--preserve-eod-proposal','--activate-day','562' if mode=='window562' else '1']
        beg=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=300)
        (a.output/(mode+'.log')).write_text(r.stdout+r.stderr,encoding='utf8')
        events.append(dict(mode=mode,command=command,seconds=time.perf_counter()-beg,returncode=r.returncode))
        (a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(mode,r.stderr)
    frames[mode]=json.loads((output/'FRAMES.json').read_text());reports[mode]=json.loads((output/'RESULT.json').read_text())
    assert reports[mode]['status'] in ('PRIVATE_READ_ONLY_PRESSURE_OBSERVATION_NOT_PRODUCTION_QUALIFICATION','PRIVATE_EOD_PROPOSAL_POLICY_NOT_ADMITTED')
    assert reports[mode]['maximum_water_cm']<=1e-10 and reports[mode]['maximum_solute_mg_cm2']<=1e-10
    print(mode,'PASS',reports[mode]['model_seconds'],flush=True)
for field in frames['control']:
    assert frames['window562'][field][:562]==frames['control'][field][:562],field
for mode,f in frames.items():
    for day in range(638):
        assert len(f['PS_HEAD'][day])==h.HUPSEL.nodes and len(f['PS_THETA'][day])==h.HUPSEL.nodes
    reports[mode]={k:v for k,v in reports[mode].items() if k not in ('base_identity','events')}
    reports[mode]['solves']=sum(f['PS_HIST'][-1]);reports[mode]['iterations']=sum((i+1)*v for i,v in enumerate(f['PS_HIST'][-1]))
    reports[mode]['day636_head8_cm']=f['PS_HEAD'][636][7];reports[mode]['oxygen584_cm']=f['HYBRID_UPTAKE'][584][3]
(a.output/'RESULT.json').write_text(json.dumps(dict(status='PRIVATE_EOD_POLICY_CAUSAL_EXPERIMENT_COMPLETE_NOT_ADMITTED',analysis_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),reconciled_without_model_execution=a.reconcile_existing,reports=reports,events=events),indent=2)+'\n')
