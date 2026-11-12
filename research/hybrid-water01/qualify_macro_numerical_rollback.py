"""Bounded actual O0/O2 physical rollback, daily mass and complete own restart."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from numerical_macro_rollback import build_bundle,PHYSICAL_FIELDS


def physical(row):return {k:v for k,v in row.items() if k!='revision'}


def native(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path,required=True)
    p.add_argument('--base-o0',type=Path,required=True)
    p.add_argument('--base-o2',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    report={'status':'RUNNING','source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'scope':'original object poolO2; changed macro/headcalc/main owners and kernelO0/O2; original equations, mass guard, solver/cache and native format unchanged',
        'full_runs':0,'cases':[]}
    def persist():(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    persist()
    def probe(case,name,cut,end,checkpoint=None):
        command=[sys.executable,'-B',str(Path(__file__).with_name('probe_original_macro_block.py')),
            '--bundle',str(case/'build'),'--reference',str(a.reference),'--output',str(case/name),
            '--cut',str(cut),'--end',str(end),'--cap-seconds','20']
        if checkpoint:command+=['--checkpoint',str(checkpoint)]
        r=subprocess.run(command,capture_output=True,text=True,timeout=35)
        (case/(name+'-command.json')).write_text(json.dumps({'command':command,'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr},indent=2)+'\n')
        print(name,r.returncode,r.stdout.strip(),flush=True)
        if r.returncode:raise ValueError('Actual prerequisite failed: '+name)
        return json.loads((case/name/'RESULT.json').read_text())
    try:
        for opt,base in [('O2',a.base_o2),('O0',a.base_o0)]:
            case=a.output/opt;case.mkdir();entry={'optimization':opt,'status':'RUNNING'};report['cases'].append(entry);persist()
            started=time.perf_counter();build_bundle(base,a.reference,case/'build',owner_optimization=opt)
            entry['compile_link_seconds']=time.perf_counter()-started;print('BUILD',opt,entry['compile_link_seconds'],flush=True)
            fresh=probe(case,'fresh',0,4)
            restart=probe(case,'restart2to4',2,4,case/'fresh/accepted-column-1-day-2.zip')
            assert all(physical(row)==physical(fresh['rows'][row['day']-1]) for row in restart['rows'])
            for day in (3,4):assert native(case/f'fresh/accepted-column-1-day-{day}.zip')==native(case/f'restart2to4/accepted-column-1-day-{day}.zip')
            continued=probe(case,'continue4to16',4,16,case/'fresh/accepted-column-1-day-4.zip')
            own=probe(case,'own14to16',14,16,case/'continue4to16/accepted-column-1-day-14.zip')
            expected={r['day']:r for r in continued['rows']}
            assert all(physical(r)==physical(expected[r['day']]) for r in own['rows'])
            for day in (15,16):assert native(case/f'continue4to16/accepted-column-1-day-{day}.zip')==native(case/f'own14to16/accepted-column-1-day-{day}.zip')
            command=[sys.executable,'-B',str(Path(__file__).with_name('probe_macro_numerical_rollback.py')),
                '--bundle',str(case/'build'),'--reference',str(a.reference),
                '--checkpoint',str(case/'continue4to16/accepted-column-1-day-14.zip'),
                '--control',str(case/'own14to16'),'--output',str(case/'observation')]
            r=subprocess.run(command,capture_output=True,text=True,timeout=90)
            (case/'observation-command.json').write_text(json.dumps({'command':command,'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr},indent=2)+'\n')
            print('OBSERVATION',opt,r.returncode,r.stdout.strip(),flush=True)
            if r.returncode:raise ValueError(r.stdout+r.stderr)
            observed=json.loads((case/'observation/RESULT.json').read_text())
            assert [f['field'] for f in observed['field_results']]==list(PHYSICAL_FIELDS)
            assert observed['rollback_count']>0
            assert all(f['changed_rejections']==0 and f['maximum_difference']==0 for f in observed['field_results'])
            rows=fresh['rows']+continued['rows']
            entry.update(status='PHYSICAL_NUMERICAL_ROLLBACK_AND_COMPLETE_OWN_RESTART_PASS',
                build=json.loads((case/'build/BUILD.json').read_text()),actual_rollback_count=observed['rollback_count'],
                maximum_daily_residual_cm=max(abs(r['independent_residual_cm']) for r in rows),
                model_seconds={'fresh':fresh['elapsed_seconds'],'restart2to4':restart['elapsed_seconds'],
                    'continue4to16':continued['elapsed_seconds'],'own14to16':own['elapsed_seconds'],'observed14to16':observed['seconds']},
                complete_own_native_days_exact=[3,4,15,16],all25_physical_fields_restored_exactly=True,
                actual_observer_parent_native_exact=True);persist()
        report['status']='NUMERICAL_MACRO_ROLLBACK_O0_O2_OWN_STATE_AND_MASS_PASS'
    except Exception:
        report['status']='FAILED';report['error']=traceback.format_exc()
    persist();print(json.dumps({'status':report['status']}));return 0 if report['status'].endswith('_PASS') else 2


if __name__=='__main__':raise SystemExit(main())
