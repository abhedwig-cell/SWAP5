"""Bounded acceptance of literal public build/run/restart commands from a clean checkout.

No imported provider, research archive or previous executable is accepted.
"""
import argparse,hashlib,json,math,os,subprocess,sys,time,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True)
reference=out/'provider';events=[];reports=[]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def call(label,arguments,*,fail=False,env=None,absent=None,timeout=180):
    command=[sys.executable,'-B','tools/solute/run_water.py',*map(str,arguments)]
    started=time.monotonic()
    result=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=timeout)
    (out/(label+'.log')).write_text(result.stdout+result.stderr)
    events.append(dict(label=label,command=command,seconds=time.monotonic()-started,returncode=result.returncode,expected_refusal=fail))
    (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
    assert (result.returncode!=0)==fail,(label,result.stdout,result.stderr)
    if absent is not None:assert not absent.exists(),label+' touched output before refusal'
    print(label,'REFUSED' if fail else 'PASS',round(events[-1]['seconds'],2),flush=True)
def rows(path):return [json.loads(x) for x in (path/'daily.jsonl').read_text().splitlines()]
def physical(row):return {k:v for k,v in row.items() if k not in ('column','revision')}
def payload(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in ('result.end','macro.bin')}
call('source-preparation',['--no-macro-release','--prepare-sources','--reference-work',reference],timeout=240)
prepared=json.loads((reference/'PREPARED.json').read_text())
assert prepared['original_model_executions']==prepared['active_macro_executions']==0
assert not (reference/'distribution/SWAP_4.3.1/cases/3.andelst').exists()
for key,model,last,case in [('grass','HYBRID_GRASSGROWTH_WATER',1827,'2.grassgrowth'),('hupsel','HYBRID_HUPSEL_WATER',1096,'1.hupselbrook'),('saltfarm','HYBRID_SALTFARM_WATER',1461,'4.salinitystress-04dS')]:
    for opt in ('O0','O2'):
        name=key+'-'+opt;bundle=out/(name+'-build');base=['--no-macro-release','--model',model,'--reference-work',reference]
        call(name+'-build',base+['--build-only','--output',bundle,'--kernel-opt',opt])
        reuse=base+['--build-bundle',bundle]
        cold=out/(name+'-cold');control=out/(name+'-control');resume=out/(name+'-resume')
        call(name+'-cold',reuse+['--output',cold,'--days',4,'--checkpoint-at',2])
        call(name+'-control',reuse+['--output',control,'--days',4,'--checkpoint-at',4])
        origin=cold/'accepted-column-1-day-2.zip';before=sha(origin)
        call(name+'-resume',reuse+['--output',resume,'--days',4,'--checkpoint-at',4,'--restart',origin,'--restart-day',2])
        assert list(map(physical,rows(cold)))==list(map(physical,rows(control)))
        assert list(map(physical,rows(resume)))==list(map(physical,rows(control)[2:]))
        assert payload(resume/'accepted-column-1-day-4.zip')==payload(control/'accepted-column-1-day-4.zip')
        assert sha(origin)==before
        for path in (cold,control,resume):
            for r in rows(path):
                assert r['committed'] and abs(r['independent_residual_cm'])<=1e-10 and abs(r['kernel_residual_cm'])<=1e-10
                assert abs(r.get('solute_independent_residual_mg_cm2',0))<=1e-10
        report=dict(project=key,optimization=opt,exact_physical_suffix=True,exact_native_auxiliary=True,origin_unchanged=True,
                    build_sha256=sha(bundle/'BUILD.json'),maximum_water_residual_cm=max(abs(r['independent_residual_cm']) for r in rows(control)),
                    maximum_solute_residual_mg_cm2=max(abs(r.get('solute_independent_residual_mg_cm2',0)) for r in rows(control)))
        if opt=='O2':
            full=out/(name+'-full')
            call(name+'-full',reuse+['--output',full],timeout=90)
            fullrows=rows(full);assert len(fullrows)==last and [r['day'] for r in fullrows]==list(range(1,last+1))
            assert all(r['committed'] and abs(r['independent_residual_cm'])<=1e-10 and abs(r['kernel_residual_cm'])<=1e-10 and abs(r.get('solute_independent_residual_mg_cm2',0))<=1e-10 for r in fullrows)
            report.update(full_days=last,full_maximum_water_residual_cm=max(abs(r['independent_residual_cm']) for r in fullrows),
                          full_maximum_solute_residual_mg_cm2=max(abs(r.get('solute_independent_residual_mg_cm2',0)) for r in fullrows),
                          full_signed_water_residual_cm=math.fsum(r['independent_residual_cm'] for r in fullrows))
        reports.append(report)
        (out/'PROFILES.json').write_text(json.dumps(reports,indent=2)+'\n')
# Negative public CLI contracts. Existing accepted output and origins remain immutable.
base=['--no-macro-release','--model','HYBRID_GRASSGROWTH_WATER','--reference-work',reference]
bundle=out/'grass-O2-build';reuse=base+['--build-bundle',bundle]
def refuse(label,args,env=None):
    target=out/('refused-'+label);call('negative-'+label,args+['--output',target],fail=True,env=env,absent=target)
refuse('active-macro',['--no-macro-release','--model','HYBRID_ANDELST_WATER','--reference-work',reference])
refuse('foreign-project',['--no-macro-release','--model','HYBRID_HUPSEL_WATER','--reference-work',reference,'--build-bundle',bundle])
refuse('wrong-optimization',reuse+['--kernel-opt','O0'])
refuse('missing-input',['--no-macro-release','--model','HYBRID_GRASSGROWTH_WATER','--reference-work',out/'absent'])
refuse('missing-toolchain',reuse,env=dict(os.environ,PATH=''))
path=reference/'distribution/SWAP_4.3.1/cases/2.grassgrowth/swap.swp';original=path.read_bytes()
for label,data in [('changed-input',original+b'\n! edited input\n'),('active-input',original.replace(b'SWMACRO = 0',b'SWMACRO = 1'))]:
    assert data!=original
    try:path.write_bytes(data);refuse(label,reuse)
    finally:path.write_bytes(original)
obj=next((reference/'build/swap-obj').glob('*.o'));original=obj.read_bytes()
try:obj.write_bytes(original+b'corrupt');refuse('changed-object',reuse)
finally:obj.write_bytes(original)
extra=reference/'build/swap-obj/foreign.o'
try:extra.write_bytes(b'foreign');refuse('extra-object',reuse)
finally:extra.unlink()
meta=bundle/'BUILD.json';original=meta.read_bytes();changed=json.loads(original);changed['binding']['case']='foreign'
try:meta.write_text(json.dumps(changed));refuse('changed-binding',reuse)
finally:meta.write_bytes(original)
archive=ROOT/'reference/swap-4.3.1/source-archives/SWAP.ZIP';original=archive.read_bytes()
try:
    archive.write_bytes(original+b'corrupt')
    target=out/'refused-source-provider'
    call('negative-source-archive',['--no-macro-release','--prepare-sources','--reference-work',target],fail=True,absent=target)
finally:archive.write_bytes(original)
existing=out/'grass-O2-cold';prior=sha(existing/'RESULT.json')
call('negative-existing-output',reuse+['--output',existing,'--days',4],fail=True)
assert sha(existing/'RESULT.json')==prior
(out/'RESULT.json').write_text(json.dumps(dict(status='CLEAN_USER_ROUTE_PASS',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    source_preparation=prepared,profiles=reports,events=events,physical_sources_unchanged=True,
    science='Original failed oxygen criteria and underqualified references retained; heat export research-only'),indent=2)+'\n')
print('CLEAN_USER_ROUTE_PASS',flush=True)
