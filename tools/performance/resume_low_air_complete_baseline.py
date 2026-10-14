#!/usr/bin/env python3
"""Resume verified original baseline children; interrupted enclosing wall is UNKNOWN.

Completed numerical programs are not repeated. Full validation still runs after
all missing children finish. CPU remains additive; this is not continuous wall A/B.
"""
import argparse, concurrent.futures, gzip, hashlib, json, os, pathlib, re, subprocess, threading, time
from run_low_air_complete import ROOT, MATRIX
BASE = 'c591205c5e03f1c96c6488eb53c562265f749556'
def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder',type=pathlib.Path);a=p.parse_args()
    out=a.folder.resolve();report=json.loads((out/'RESULTS.json').read_text())
    if report['policy']!='baseline' or report['complete'] or report['workers']!=4:
        raise ValueError('not the incomplete original baseline')
    if report['source_tree']!=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip():raise ValueError('numerical source drift')
    import sys
    sys.path.insert(0,str(ROOT/'tests/performance'))
    from low_air_successor_authority import verify_source
    verify_source()
    expected={(o,n,f) for o in [0,2] for n,c in MATRIX.items() for f in (range(1,c+1) if c else [None])}
    seen=set();recipes={};binaries={}
    for o,n,f in expected:
        path=f'tests/frost/test_{n}.f90';original=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
        driver=out/f'o{o}/{n}.f90'
        if original!=(ROOT/path).read_bytes() or original!=driver.read_bytes():raise ValueError('original recipe drift')
        recipes[o,n]=sha(driver);binaries[o,n]=sha(out/f'o{o}/{n}')
    for run in report['runs']:
        o,n,f=key=run['optimization'],run['program'],run['family']
        if key not in expected or key in seen or not run['complete'] or run['exit']:raise ValueError('foreign/incomplete completed child')
        seen.add(key)
        data=(out/f'o{o}-{n}-family-{f}.stdout').read_text()
        
        if sha(out/f'o{o}-{n}-family-{f}.stdout')!=run['stdout_sha256'] or data.count('_RUNTIME=PASS')!=1 or data.count('FINE_COMPARISON')!=6:raise ValueError('completed executed science drift')
        if recipes[o,n]!=run['recipe_sha256'] or binaries[o,n]!=run['binary_sha256']:raise ValueError('executed artifact drift')
    # Bind reuse to all original compiler/source/provider objects and fixture inputs.
    from verify_low_air_ab import verify
    for o in [0,2]:
        command=next(e['command'] for e in report['events'] if e['label']==f'compile-ppa_wu05b8_low_air_runtime-o{o}')
        build=pathlib.Path(command[command.index('-I')+1])
        manifest=json.loads((build/'RESULTS.json').read_text());prior=build.parent/f'qual-o{o}';verify(prior)
        qualified=json.loads((prior/'RESULTS.json').read_text())
        if sha(build/'RESULTS.json')!=report['builds'][str(o)]['manifest_sha256'] or qualified['build_manifest_sha256']!=sha(build/'RESULTS.json'):raise ValueError('manifest drift')
        if manifest['compiler']!=subprocess.check_output(['gfortran','--version'],text=True):raise ValueError('compiler drift')
        for path,h in {**manifest['sources'],**qualified['objects']}.items():
            if sha(path)!=h:raise ValueError('provider/input drift '+path)
        for path,h in report['builds'][str(o)]['extra_inputs'].items():
            if sha(ROOT/path)!=h:raise ValueError('fixture drift')
    initial=out/'INTERRUPTED_RESULTS.json'
    if initial.exists():raise ValueError('second interruption requires explicit recovery investigation')
    initial.write_text(json.dumps(report,indent=2)+'\n')
    start=time.monotonic();own=time.process_time();lock=threading.Lock()
    report['parent_cpu_scope']='RECOVERY_SEGMENT_ONLY_ORIGINAL_PARENT_UNKNOWN';report['interrupted_wall']=True;report['recovery']={'completed_reused':len(seen),'missing_executed':len(expected-seen),'continuous_whole_wall':'UNKNOWN'}
    def persist():(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n')
    def run(key):
        o,n,f=key;label=f'o{o}-{n}-family-{f}'
        # Preserve interrupted partial output; never overwrite it as successful evidence.
        for suffix in ['stdout','stderr']:
            old=out/(label+'.'+suffix)
            if old.exists():old.rename(out/(label+'.interrupted.'+suffix))
        command=[str(out/f'o{o}/{n}')]+([str(f)] if f else [])
        begin=time.monotonic();print('START '+label,flush=True)
        with (out/(label+'.stdout')).open('w') as so,(out/(label+'.stderr')).open('w') as se:
            child=subprocess.Popen(command,stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
            _,status,usage=os.wait4(child.pid,0);exit=os.waitstatus_to_exitcode(status)
        text=(out/(label+'.stdout')).read_text();
        record={'label':label,'command':command,'wall':time.monotonic()-begin,'cpu':usage.ru_utime+usage.ru_stime,'exit':exit,'optimization':o,'program':n,'family':f,'original_sha256':recipes[o,n],'recipe_sha256':recipes[o,n],'binary_sha256':binaries[o,n],'stdout_sha256':sha(out/(label+'.stdout')),'fine_comparisons':text.count('FINE_COMPARISON'),'counters':[list(map(int,x)) for x in re.findall(r'substeps=\s*(\d+)\s+rejections=\s*(\d+)',text)],'complete':exit==0 and text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6}
        with lock:report['runs'].append(record);persist()
        print(json.dumps(record),flush=True)
        if not record['complete']:raise RuntimeError('original baseline science failed; preserve '+label)
    persist()
    missing=sorted(expected-seen,key=lambda x:(x[0],list(MATRIX).index(x[1]),x[2] or 0))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(run,missing))
    report['complete']=True;report['native_cpu']=sum(r['cpu'] for r in report['runs']);report['build_link_cpu']=sum(e['cpu'] for e in report['events']);report['parent_cpu']=time.process_time()-own
    report['whole_wall']=None;report['recovery']['remaining_wall']=time.monotonic()-start;report['cold_provider_build']='EXCLUDED_VERIFIED_WARM_PROVIDERS';persist()
    from verify_low_air_complete import verify_complete
    proof=verify_complete(out,check_binaries=True);(out/'VERIFICATION.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(proof),flush=True)
if __name__=='__main__':main()
