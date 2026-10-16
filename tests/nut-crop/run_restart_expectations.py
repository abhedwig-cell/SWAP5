"""Fresh decoder executions over hash-verified unchanged qualified providers."""
from pathlib import Path
import hashlib,json,os,shlex,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
PRIMARY=Path(os.environ['CROP_N_PRIMARY']).resolve();OUT=Path(os.environ['CROP_N_EDGE_DIR']).resolve();OUT.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();events=[]
r=json.loads((PRIMARY/'result.json').read_text());assert r['status']=='PHYSICAL_PASS_NOT_ADMITTED'
assert all(sha(ROOT/p)==h for p,h in r['input_sha256'].items())
res=dict(status='RUNNING',source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),primary_result_sha256=sha(PRIMARY/'result.json'),runs={})
def run(args,cwd,category):
 args=list(map(str,args));t=time.perf_counter();p=subprocess.run(args,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
 events.append(dict(command=args,category=category,seconds=time.perf_counter()-t,returncode=p.returncode,stdout_sha256=hashlib.sha256(p.stdout).hexdigest(),stderr_sha256=hashlib.sha256(p.stderr).hexdigest(),stdout_file=f'{i:04d}.stdout',stderr_file=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:print(p.stdout.decode());print(p.stderr.decode());raise RuntimeError('retained failed edge')
 return p.stdout.decode()
source=ROOT/'tests/nut-crop/test_crop_restart_expectations.f90';FC=shlex.split(os.environ.get('FC','gfortran'))
for opt in ['O0','O2']:
 b=PRIMARY/opt;out=OUT/opt;out.mkdir(exist_ok=True)
 artifacts={p.name:sha(p)for p in b.iterdir()if p.suffix in ['.o','.mod']}
 objects=sorted(b.glob('provider-*.o'),key=lambda p:int(p.stem.split('-')[1]))
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(out),'-I'+str(b),'-I'+str(ROOT/'tests/nut-crop'),'-I'+str(ROOT/'tests/nut-reactive')]
 obj=out/'driver.o';exe=out/'expected-config'
 run(FC+flags+['-c',source,'-o',obj],out,'compile');run(FC+flags+objects+[obj,'-o',exe],out,'link')
 output=run([exe,b/'test_crop_soil_joint-restart.bin'],out,'native');assert 'CROP_SOIL_SEVEN_EXPECTED_CONFIGURATION_IDENTITY_NEGATIVES=PASS'in output
 after={p.name:sha(p)for p in b.iterdir()if p.suffix in ['.o','.mod']};assert after==artifacts
 res['runs'][opt]=dict(stdout=output,artifacts_before=artifacts,artifacts_after=after)
res.update(status='PASS',input_sha256={str(p.relative_to(ROOT)):sha(p)for p in [source,Path(__file__),ROOT/'tests/nut-crop/crop_fixture.inc',ROOT/'tests/nut-reactive/reactive_parameters.inc']},cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile','link','native']})
(OUT/'result.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps(res['cost_seconds']))
