"""Coherent copied-source runtime experiment; no production promotion."""
import argparse, hashlib, json, shutil, subprocess, sys, time
from pathlib import Path
from micro_pressure_probe import OLD, NEW, PROCESS
from full_profile_evidence import DAYS

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def build(bundle,out,fc):
    out.mkdir();record=json.loads((bundle/'BUILD.json').read_text())
    assert subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0]==record['compiler']
    for key in ('source_sha256','object_sha256'):
        assert all(sha(Path(p))==h for p,h in record[key].items()),key
    provider=record['publication_provider']
    assert sha(Path(record['ttutil_archive']))==record['archive_sha256']
    assert sha(Path(provider['source']))==provider['source_sha256']
    assert sha(Path(provider['object']))==provider['object_sha256']
    original=(ROOT/PROCESS).read_text();assert original.count(OLD)==1
    candidate=original.replace(OLD,NEW)
    assert candidate.replace(NEW,OLD)==original
    source=out/Path(PROCESS).name;source.write_text(candidate,encoding='utf-8',newline='\n')
    flags=[v for v in record['flags'] if not v.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
    objects=[];events=[];started=time.monotonic()
    def run(command):
        begin=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,timeout=240)
        index=len(events)
        (out/f'{index}.stdout').write_bytes(r.stdout);(out/f'{index}.stderr').write_bytes(r.stderr)
        events.append(dict(command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-begin))
        (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
        assert r.returncode==0,r.stderr
    sources={};changed=[]
    for index,name in enumerate(record['source_sha256']):
        path=Path(name);relative=path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else None
        actual=source if relative==PROCESS else path
        if relative==PROCESS:changed.append(relative)
        obj=out/f'{index}.o';run([fc,*flags,'-c',actual,'-o',obj]);objects.append(obj)
        sources[str(actual)]=sha(actual)
    assert changed==[PROCESS] and len(objects)==236
    exe=out/'pressure-runtime.exe'
    args=['-fopenmp','-Wl,--stack,16777216',*map(str,objects),provider['object'],record['ttutil_archive'],'-o',str(exe)]
    response=out/'link.args';response.write_text('\n'.join('"'+x.replace('\\','/')+'"' for x in args)+'\n',encoding='utf-8')
    run([fc,'@'+str(response)])
    result=dict(baseline=record,source_sha256=sources,compiled_objects_sha256={p.name:sha(p) for p in objects},
                source_copy_sha256=sha(source),source_original_sha256=sha(ROOT/PROCESS),only_intervention=PROCESS,
                complete_module_closure_rebuilt=True,executable_sha256=sha(exe),events=events,seconds=time.monotonic()-started)
    (out/'BUILD.json').write_text(json.dumps(result,indent=2)+'\n');return exe

def execute(exe,inputs,out,end,seed=None,capture=(),compatible=False):
    cmd=[sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/run_canopy_observation.py'),
         '--exe',str(exe),'--predecessor',str(inputs),'--output',str(out),'--end',str(end),'--timeout','3600']
    cmd+=['--strict-restart',str(seed)] if seed else ['--from-start']
    if compatible:cmd+=['--compatibility-control']
    if capture:cmd+=['--capture',*map(str,capture)]
    r=subprocess.run(cmd,cwd=ROOT,capture_output=True)
    (out/'WRAPPER.stdout').write_bytes(r.stdout);(out/'WRAPPER.stderr').write_bytes(r.stderr)
    assert r.returncode==0,r.stderr
    result=json.loads((out/'RESULT.json').read_text())
    assert result['returncode']==0,result
    # Polling can miss the final publication; retain only the actual final CRC
    # validated checkpoint, never synthesize or repair a state.
    if end in capture and not (out/f'checkpoint-{end}.bin').exists():
        from inspect_profiles import profile
        raw=(out/'checkpoint.bin').read_bytes();assert profile(raw)['day']==end
        (out/f'checkpoint-{end}.bin').write_bytes(raw)
        (out/'FINAL_CAPTURE_FALLBACK.json').write_text(json.dumps(dict(day=end,actual_final_copy=True))+'\n')
    assert all((out/f'checkpoint-{d}.bin').exists() for d in capture)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for n in ('o0','o2','inputs','output','compiler'):p.add_argument('--'+n,type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir()
    reg=json.loads((BASE/'MICRO_PRESSURE_RUNTIME_PREREGISTRATION_20261104.json').read_text())
    (out/'REGISTRATION.json').write_text(json.dumps(reg,indent=2)+'\n')
    executables={}
    for opt,bundle in [('O2',a.o2),('O0',a.o0)]:
        executables[opt]=build(bundle.resolve(),out/('build-'+opt),a.compiler.resolve())
    try:
        execute(executables['O2'],a.inputs.resolve(),out/'full-O2',1096,capture=reg['checkpoints'])
        execute(executables['O2'],out/'full-O2',out/'strict-O2-1088',1096,seed=out/'full-O2/checkpoint-1088.bin')
        execute(executables['O0'],out/'full-O2',out/'compatible-O0-1077',1096,seed=out/'full-O2/checkpoint-1077.bin',capture=[1088],compatible=True)
        execute(executables['O0'],out/'compatible-O0-1077',out/'strict-O0-1088',1096,seed=out/'compatible-O0-1077/checkpoint-1088.bin')
    except Exception as error:
        (out/'FAILED.json').write_text(json.dumps(dict(stage='RUNTIME_QUALIFICATION_FAILED',error=str(error),production_admission=False),indent=2)+'\n')
        raise
    (out/'EXECUTED.json').write_text(json.dumps(dict(stage='ACTUAL_RUNTIME_EXECUTIONS_COMPLETE_AUDIT_PENDING',production_admission=False),indent=2)+'\n')

if __name__=='__main__':main()
