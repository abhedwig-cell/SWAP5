"""Validate completed daily checkpoints retained by censored continuations."""
import argparse, csv, hashlib, json, math, runpy, subprocess, time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
def rows(p):
    with p.open() as f:return list(csv.DictReader(f))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('batch',type=Path)
    a=p.parse_args();folder=a.batch.resolve()
    owner=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual07_current.py'))
    owner['source']();f=owner['capsule']();owner['validate'](f)
    exe=folder/'native-O2'
    assert exe.read_bytes()==f['recovery/native-O2']
    retained=[]
    for r in json.loads((folder/'results.json').read_text()):
        case=folder/(r['batch']+'-'+r['id'])
        budget=rows(case/'budget.csv')
        if not budget or not (case/'restart.bin').exists():continue
        end=float(budget[-1]['t1']);assert end==int(end) and end>r['origin_days']
        pre=r['batch']+'/'+r['id']+'/run/'
        original=json.loads(f[pre+'manifest.json'])
        for name in ['input.nml','input.swp','macro.nml']:
            assert (case/name).read_bytes()==f[pre+name]
        assert (case/'origin.bin').read_bytes()==f[pre+'restart.bin']
        for name,h in r['files'].items():assert sha((case/name).read_bytes())==h
        # stop_after=floor(committed clock) skips the daily loop. Huge stop_time
        # preserves the CLI's normal unset-target value. No state advance occurs.
        view=case/'checkpoint-view';view.mkdir()
        for name in ['input.nml','input.swp','macro.nml']:(view/name).write_bytes(f[pre+name])
        raw=(case/'restart.bin').read_bytes();(view/'origin.bin').write_bytes(raw)
        cmd=next(e['command'] for e in original['events'] if e['label']=='native').copy()
        cmd[0]=str(exe);cmd[2]='origin.bin';cmd[3]=str(int(end));cmd[7]='1.7976931348623157e308'
        start=time.monotonic()
        cp=subprocess.run(cmd,cwd=view,capture_output=True,timeout=5)
        seconds=time.monotonic()-start
        (view/'stdout').write_bytes(cp.stdout);(view/'stderr').write_bytes(cp.stderr)
        assert cp.returncode==0 and b'NATIVE_SWSOLU0_MACRO_RUTTER_HEAT_PROJECT_PASS' in cp.stdout
        assert all(not rows(view/n) for n in ['budget.csv','progress.csv','cost.csv','diagnostics.csv'])
        assert (view/'origin.bin').read_bytes()==raw
        state=rows(view/'state.csv');temp=rows(view/'temperature.csv')
        assert len(state)==len(temp)==112
        assert all(math.isfinite(float(v)) for row in state+temp for v in row.values())
        assert all(0<=float(row['theta'])<=1 for row in state)
        cert=['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']
        assert all(math.isfinite(float(v)) for row in budget for v in row.values())
        assert all(abs(float(row[k]))<=1e-10 for row in budget for k in cert)
        completed=[row for row in rows(case/'progress.csv') if float(row['t1'])<=end]
        assert completed and all(int(row['mass_rejections'])==0 for row in completed)
        assert float(budget[0]['t0'])==r['origin_days'] and float(completed[-1]['t1'])==end
        retained.append(dict(id=r['id'],batch=r['batch'],configuration=r['configuration'],
            completed_days=end,origin_days=r['origin_days'],checkpoint_sha256=sha(raw),
            snapshot_seconds=seconds,snapshot_command=cmd,snapshot_no_steps=True,
            qualified_water_only=True,max_water_cm=max(abs(float(row[k])) for row in budget for k in cert),
            state_sha256=sha((view/'state.csv').read_bytes()),temperature_sha256=sha((view/'temperature.csv').read_bytes())))
    def sig(r):
        c=r['configuration'];defaults=dict(mode='experimental',source_surface_demand=False,perched_jacobian=False,
            solver_max_iterations=64,anchored=True,entry_width_cm=1e-4,transformations=[])
        return json.dumps({k:c.get(k,v) for k,v in defaults.items()},sort_keys=True)
    prior=json.loads(f['baseline-rows.json'])+json.loads(f['all-results.json'])
    before={}
    for r in prior:
        if r['status']=='PASS':before[sig(r)]=max(before.get(sig(r),0),r['completed_days'])
    assert len(before)==83 and abs(sum(before.values())-93.61849999972037)<1e-9
    after=dict(before)
    for r in retained:after[sig(r)]=max(after.get(sig(r),0),r['completed_days'])
    result=dict(retained=retained,before_configurations=len(before),after_configurations=len(after),
        before_days=sum(before.values()),after_days=sum(after.values()),extra_days=sum(after.values())-sum(before.values()),
        five_day_completions=sum(r['status']=='PASS' for r in json.loads((folder/'results.json').read_text())),
        caveat='Only completed daily prefixes qualified. Censored/failing five-day targets remain censored/failing.')
    (folder/'RETAINED.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
