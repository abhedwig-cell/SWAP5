"""Source-bound common-profile public runs and own continuation; no old-profile equality claim."""
import argparse,hashlib,json,subprocess,sys,time,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--reference',type=Path,help='Reuse a source/compiler-verified original provider, still build fresh application binaries')
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();events=[];profiles=[]
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
reference=a.reference.resolve() if a.reference else a.output/'provider'
def call(label,arguments,*,script='tools/solute/run_water.py',timeout=180):
    command=[sys.executable,'-B',script,*map(str,arguments)];begin=time.perf_counter()
    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=timeout)
    (a.output/(label+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
    events.append(dict(label=label,command=command,returncode=r.returncode,seconds=time.perf_counter()-begin))
    (a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
    assert r.returncode==0,(label,r.stdout,r.stderr)
    print(label,'PASS',round(events[-1]['seconds'],3),flush=True)
def rows(directory):
    return [{k:v for k,v in json.loads(s).items() if k not in ('column','revision')}
            for s in (directory/'daily.jsonl').read_text().splitlines()]
def native(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in ('result.end','macro.bin')}
def csv(directory):
    return [s for s in (directory/'original/result_output.csv').read_text().splitlines() if s.strip() and not s.startswith('*')]
if a.reference:
    (a.output/'PREPARED_REUSED.json').write_bytes((reference/'PREPARED.json').read_bytes())
else:call('prepare',['--no-macro-release','--prepare-sources','--reference-work',reference],timeout=240)
for project,model,last,cut in [('grass','HYBRID_GRASSGROWTH_WATER',1827,365),('hupsel','HYBRID_HUPSEL_WATER',1096,365),('saltfarm','HYBRID_SALTFARM_WATER',1461,109)]:
    for opt in ('O0','O2'):
        label=project+'-'+opt;end=4 if opt=='O0' else last;origin_day=2 if opt=='O0' else cut
        bundle=a.output/(label+'-candidate-build')
        base=['--no-macro-release','--model',model,'--reference-work',reference]
        call(label+'-build',base+['--build-only','--kernel-opt',opt,'--output',bundle])
        reuse=base+['--build-bundle',bundle];control=a.output/(label+'-control');full=a.output/(label+'-candidate-full');resume=a.output/(label+'-own-resume')
        call(label+'-control',reuse+['--days',end,'--checkpoint-at',end,'--output',control])
        call(label+'-full',reuse+['--days',end,'--checkpoint-at',origin_day,'--output',full])
        saved=full/f'accepted-column-1-day-{origin_day}.zip';origin_hash=hashlib.sha256(saved.read_bytes()).hexdigest()
        call(label+'-resume',reuse+['--days',end,'--restart',saved,'--restart-day',origin_day,'--checkpoint-at',end,'--output',resume])
        c,f,r=rows(control),rows(full),rows(resume)
        assert len(c)==len(f)==end and len(r)==end-origin_day
        assert c==f and r==c[origin_day:]
        assert native(control/f'accepted-column-1-day-{end}.zip')==native(resume/f'accepted-column-1-day-{end}.zip')
        assert csv(control)==csv(full) and csv(resume)[-len(r):]==csv(full)[-len(r):]
        assert hashlib.sha256(saved.read_bytes()).hexdigest()==origin_hash
        for v in c+r:
            assert v['committed'] and abs(v['independent_residual_cm'])<=1e-10 and abs(v['kernel_residual_cm'])<=1e-10
            assert abs(v.get('solute_independent_residual_mg_cm2',0))<=1e-10
        report=dict(project=project,opt=opt,days=end,cut=origin_day,exact_all_physical=True,exact_all_printed_csv=True,exact_own_native_auxiliary=True,origin_unchanged=True,
            maximum_water_cm=max(abs(v['independent_residual_cm']) for v in f),maximum_solute_mg_cm2=max(abs(v.get('solute_independent_residual_mg_cm2',0)) for v in f),
            floating_point_profile=json.loads((bundle/'BUILD.json').read_text())['identity']['floating_point_profile'],
            time_step_policy=json.loads((bundle/'BUILD.json').read_text())['identity'].get('time_step_policy'),
            model_seconds=json.loads((full/'RESULT.json').read_text())['model_and_controller_seconds'])
        if project=='hupsel' and opt=='O2':report['oxygen584_cm']=f[583]['uptake_terms_cm'][3]
        profiles.append(report);(a.output/'PROFILES.json').write_text(json.dumps(profiles,indent=2)+'\n')
call('refusals',['--reference',reference,'--bundle',a.output/'grass-O2-candidate-build','--output',a.output/'refusals'],script='tools/solute/check_rc1_build_validation.py',timeout=120)
call('external',['--reference',reference,'--qualification',a.output,'--output',a.output/'external'],script='tools/solute/check_publisher_coupling.py',timeout=120)
(a.output/'RESULT.json').write_text(json.dumps(dict(status='COMMON_PROFILE_PUBLIC_O0_O2_FULL_OWN_PASS',source=source,profiles=profiles,events=events,
    scope='Within-profile exact own controls; no old-profile equality, cross-platform whole-science or native-solver speedup claim.'),indent=2)+'\n')
print('COMMON_PROFILE_PUBLIC_O0_O2_FULL_OWN_PASS',flush=True)
