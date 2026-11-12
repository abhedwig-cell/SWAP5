from pathlib import Path
import os, sys, types, json, subprocess, time, hashlib,argparse
parser=argparse.ArgumentParser();parser.add_argument('--provider',type=Path,default=Path('/workspace/scratch/847fc052fa43'));args=parser.parse_args()
OLD=args.provider.resolve();ROOT=Path(__file__).resolve().parent;BASE=ROOT if (ROOT/'PREREGISTRATION.json').exists() else ROOT/'b1-accept01';OUT=BASE/'O0-closure'
OUT.mkdir(parents=True,exist_ok=True)
comp=OLD/'compiler'
os.environ['PATH']=str(comp/'bin')+':'+os.environ['PATH']
os.environ['GCC_EXEC_PREFIX']=str(comp/'root/usr/lib/gcc/')
os.environ['COMPILER_PATH']=str(comp/'root/usr/libexec/gcc/x86_64-linux-gnu/14')
os.environ['LIBRARY_PATH']=str(comp/'root/usr/lib/gcc/x86_64-linux-gnu/14')+':/usr/lib/gcc/x86_64-linux-gnu/14'
sys.modules['reference_identity']=types.SimpleNamespace(verify_b0_archive=None)
p=OLD/'evidence/tools/vq/b0_source_runner.py'
source=p.read_text();ns={'__name__':'o0_builder','__file__':str(p)}
exec(compile(source.replace('"-O2"','"-O0"'),str(p),'exec'),ns)
logs=[]
def run(cmd,cwd):
    if cmd[0].endswith('gfortran') and '-o' in cmd and '-c' not in cmd:cmd=cmd[:1]+['-B/usr/lib/gcc/x86_64-linux-gnu/14/']+cmd[1:]
    start=time.monotonic();r=subprocess.run(cmd,cwd=cwd,capture_output=True,text=True,timeout=60)
    logs.append(dict(command=cmd,cwd=str(cwd),returncode=r.returncode,seconds=time.monotonic()-start,stdout=r.stdout,stderr=r.stderr))
    (OUT/'BUILD_LOG.json').write_text(json.dumps(logs,indent=2)+'\n')
    if len(logs)%40==0:print('O0 build commands completed:',len(logs),flush=True)
    return subprocess.CompletedProcess(cmd,r.returncode,r.stdout+r.stderr)
ns['run']=run
start=time.monotonic();exe,_=ns['build_gfortran'](OLD/'distribution',OUT)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(OUT/'IDENTITY.json').write_text(json.dumps(dict(executable=str(exe),exe_sha256=sha(exe),seconds=time.monotonic()-start,runner_sha256=sha(p),runner_change='Only -O2 to -O0 in build flags; explicit system GCC linker path.',selected_sources={p.name:sha(p) for p in (OUT/'swap-selected').glob('*.f90')},objects={p.name:sha(p) for p in (OUT/'swap-obj').glob('*.o')},ttutil_sha256=sha(OUT/'ttutil-obj/libttutil.a')),indent=2)+'\n')
print('O0 closure complete',round(time.monotonic()-start,3),flush=True)
