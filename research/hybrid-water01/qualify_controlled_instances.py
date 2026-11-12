"""Interleaved independent original project instances with typed external input."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn,CAUCHY_FORCING,GROUNDWATER_FORCING,IRRIGATION_FORCING
p=argparse.ArgumentParser(description=__doc__)
for n in ['workspace','cauchy','groundwater','irrigation','output']:p.add_argument('--'+n,type=Path,required=True)
a=p.parse_args();a.output.mkdir();idx=json.loads((a.workspace/'PROOF_INDEX.json').read_text());reference=a.workspace/idx['reference']
inputs={k:json.loads(getattr(a,k).joinpath('RESULT.json').read_text()) for k in ['cauchy','groundwater','irrigation']}
for r in inputs.values():assert r['sources']['app/hybrid_water/daily_coupling.py']==h.sha(ROOT/'app/hybrid_water/daily_coupling.py')
started=[];expired=[];real_start=h.start_process
def track(*args):
    process,log=real_start(*args);started.append(process);return process,log
h.start_process=track
def stop():
    expired.append(True)
    for proc in started:
        if proc.poll() is None:proc.kill()
timer=threading.Timer(120,stop);timer.daemon=True;timer.start();begin=time.monotonic()
report={'status':'RUNNING','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    'sources':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/daily_coupling.py','app/hybrid_water/daily_host.py',
        'app/hybrid_water/irrigation_forcing.py','research/hybrid-water01/qualify_controlled_instances.py']},'groups':[]}
def physical(row):return {k:v for k,v in row.items() if k not in ('column','revision','coupling','committed','candidate_only')}
def load(path):
    with zipfile.ZipFile(path) as z:return json.loads(z.read('checkpoint.json')),{n:z.read(n) for n in h.CHECKPOINT_FILES}
def reject(fn):
    try:fn()
    except ValueError:return
    raise AssertionError('Foreign proposal accepted')
try:
    for opt in ['O0','O2']:
        out=a.output/opt;out.mkdir();models={};fixtures={};requests={};events=[];olds={}
        cr=next(c for c in inputs['cauchy']['cases'] if c['optimization']==opt)
        gr=next(c for c in inputs['groundwater']['cases'] if c['optimization']==opt and c['cut']==2)
        ir=next(c for c in inputs['irrigation']['cases'] if c['optimization']==opt and c['scenario']=='modified')
        controls={'andelst':a.cauchy/opt/'external','grass':a.groundwater/opt/'window-2-to-4/external','hupsel':a.irrigation/opt/'modified/external'}
        specs={'andelst':(h.ANDELST,CAUCHY_FORCING,20,a.cauchy/opt/'accepted-origin-day-20.zip',a.workspace/idx['cases']['andelst-'+opt]['build'],cr['requests']),
               'grass':(h.GRASSGROWTH,GROUNDWATER_FORCING,2,a.workspace/idx['cases']['grass-'+opt]['continuous']/'accepted-column-1-day-2.zip',a.workspace/idx['cases']['grass-'+opt]['build'],[gr['first_forcing'],gr['second_forcing']]),
               'hupsel':(h.HUPSEL,IRRIGATION_FORCING,4,a.irrigation/opt/'no-file-original/accepted-column-1-day-4.zip',a.irrigation/opt/'build',[ir['first'],ir['second']])}
        for key,(project,mode,cut,origin,bundle,segments) in specs.items():
            if os.name!='nt':
                for name in ['day_donor','day_kernel']:h.executable(bundle,name).chmod(0o755)
            (out/(key+'-BUILD.json')).write_bytes((bundle/'BUILD.json').read_bytes())
            models[key]=CoupledDailyColumn(bundle,reference,out/key,project,'interleaved-'+opt+'-'+key,
                origin=origin,day=cut,adopt_native=True,forcing_mode=mode)
            fixtures[key]=[load(controls[key]/f'accepted-column-1-day-{cut+i}.zip') for i in [1,2]]
            requests[key]=segments
        def snapshot(m):
            return {'day':m.day,'revision':m.revision,'accepted_sha256':h.sha(m.checkpoint),
                'pending_sha256':None if m._pending is None else h.sha(m._candidate[3]),'coupling_id':m.coupling_id}
        def states():return {k:snapshot(m) for k,m in models.items()}
        def act(owner,action,fn):
            before=states();value=fn();after=states()
            assert all(before[k]==after[k] for k in models if k!=owner)
            if action=='foreign-refusal':assert before==after
            events.append({'owner':owner,'action':action,'before':before,'after':after});return value
        def forcing(key,step):
            m=models[key];f=requests[key][step]
            if key=='andelst':return {'cauchy':m.cauchy_forcing(f['head_start_cm'],f['head_end_cm'],f['provenance'])}
            if key=='grass':return {'groundwater':m.groundwater_forcing(f['head_start_cm'],f['head_end_cm'],f['provenance'])}
            return {'irrigation':m.irrigation_forcing(f['depth_mm'],f['concentration_mg_cm3'],f['rate_mm_h'],f['provenance'],enabled=f['enabled'])}
        def prepare(key,step):
            q=act(key,'prepare',lambda:models[key].prepare(**forcing(key,step)))
            expected,data=fixtures[key][step]
            assert physical(q.budget)==physical(expected['receipt']) and load(models[key]._candidate[3])[1]==data
            return q
        pending={key:prepare(key,0) for key in ['andelst','hupsel','grass']}
        for key,foreign in [('grass','hupsel'),('andelst','grass'),('hupsel','andelst')]:
            act(key,'foreign-refusal',lambda:reject(lambda:models[key].accept(pending[foreign])))
        old=pending['hupsel'];act('hupsel','discard',lambda:models['hupsel'].discard(old))
        act('grass','accept',lambda:models['grass'].accept(pending['grass']))
        pending['hupsel']=prepare('hupsel',0);act('hupsel','foreign-refusal',lambda:reject(lambda:models['hupsel'].accept(old)))
        for key in ['andelst','hupsel']:act(key,'accept',lambda:models[key].accept(pending[key]))
        first_endpoints={key:str(m.checkpoint.relative_to(a.output)) for key,m in models.items()}
        # Reconstruct each owner after mixed first-day acceptance, without rerunning its already qualified live day2.
        for key in ['hupsel','grass','andelst']:
            old=models[key];olds[key]=(old,snapshot(old));project,mode,cut,origin,bundle,segments=specs[key]
            def cold():
                models[key]=CoupledDailyColumn(bundle,reference,out/(key+'-cold'),project,old.coupling_id,
                    origin=old.checkpoint,day=cut+1,forcing_mode=mode)
            act(key,'cold-reconstruct',cold);assert snapshot(models[key])==snapshot(old)
        pending={key:prepare(key,1) for key in ['grass','andelst','hupsel']}
        for key,foreign in [('hupsel','grass'),('grass','andelst'),('andelst','hupsel')]:
            act(key,'foreign-refusal',lambda:reject(lambda:models[key].discard(pending[foreign])))
        old=pending['grass'];act('grass','discard',lambda:models['grass'].discard(old))
        act('andelst','accept',lambda:models['andelst'].accept(pending['andelst']))
        pending['grass']=prepare('grass',1)
        for key in ['hupsel','grass']:act(key,'accept',lambda:models[key].accept(pending[key]))
        final_endpoints={key:str(m.checkpoint.relative_to(a.output)) for key,m in models.items()}
        for key,m in models.items():
            assert load(m.checkpoint)[1]==fixtures[key][1][1] and physical(load(m.checkpoint)[0]['receipt'])==physical(fixtures[key][1][0]['receipt'])
            assert snapshot(olds[key][0])==olds[key][1] and m.revision==2
        group={'optimization':opt,'events':events,'first_endpoints':first_endpoints,'final_endpoints':final_endpoints,
            'controls':{key:{'first_sha256':h.sha(controls[key]/f'accepted-column-1-day-{specs[key][2]+1}.zip'),
                             'final_sha256':h.sha(controls[key]/f'accepted-column-1-day-{specs[key][2]+2}.zip')} for key in specs},
            'all_interleaved_physical_native_controls_exact':True,'all_accepted_pending_siblings_unchanged':True,
            'foreign_refusals':7,'discarded_physical_proposals':2,'old_live_mirrors_unchanged_after_cold_accept':True}
        report['groups'].append(group);print(opt,'mixed controlled instances PASS',flush=True)
    assert not expired;report['status']='INTERLEAVED_CONTROLLED_PROJECT_INSTANCE_STATE_NATIVE_ISOLATION_PASS'
except BaseException:
    report.update(status='FAILED',traceback=traceback.format_exc());raise
finally:
    timer.cancel();report['censored']=bool(expired);report['elapsed_seconds']=time.monotonic()-begin
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
