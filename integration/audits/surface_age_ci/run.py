#!/usr/bin/env python3
"""Execute all three existing CI bodies locally with unchanged native assertions."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time,uuid
ROOT=Path(__file__).resolve().parents[3]
if len(sys.argv)>1 and sys.argv[1]=='--compiler':
 args=sys.argv[2:];start=time.perf_counter();r=subprocess.run([os.environ['AGE03_REAL_FC'],*args])
 row=dict(args=args,seconds=time.perf_counter()-start,returncode=r.returncode)
 (Path(os.environ['AGE03_COMPILER_EVENTS'])/(uuid.uuid4().hex+'.json')).write_text(json.dumps(row))
 raise SystemExit(r.returncode)
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--case',choices=['fci51','fci58','fgc']);a=p.parse_args()
out=Path(a.out).resolve();out.mkdir(exist_ok=False,parents=True);(out/'compiler').mkdir();(out/'bin').mkdir()
fc=os.environ.get('FC','gfortran');import shutil
real=shutil.which(fc)if'/'not in fc else fc;assert real
wrapper=out/'bin/gfortran';wrapper.write_text('#!/bin/sh\nexec '+sys.executable+' '+str(Path(__file__).resolve())+' --compiler "$@"\n');wrapper.chmod(0o755)
paths=subprocess.check_output(['git','ls-files','--','src','tests','tools','reference','.github','integration/audits/surface_age_ci','integration/audits/surface_age_longrun/verify.py'],cwd=ROOT,text=True).splitlines()
inputs={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths}
env=dict(os.environ,GITHUB_REF_NAME='integration/f-ci-canonical',PATH=str(out/'bin')+os.pathsep+os.environ['PATH'],FC=str(wrapper),AGE03_REAL_FC=real,AGE03_COMPILER_EVENTS=str(out/'compiler'))
cases={'fci51':'tests/fci/run_fci51p_wof43a_successor_preservation.sh','fci58':'tests/fci/run_fci93_fsi35_semantic_successor_preservation.sh','fgc':'tests/fgc/run_fgc_fixed_interface_closeout.sh'}
import yaml
workflow=yaml.safe_load((ROOT/'.github/workflows/fci51p-wof43a-moving-preservation.yml').read_text())
body=next(s['run']for s in workflow['jobs']['preserve-qualified-wof43a']['steps']if 'run'in s)
(out/'fci51-workflow.sh').write_text(body)
cases['fci51']=str(out/'fci51-workflow.sh')
events=[]
for case,script in cases.items():
 if a.case and case!=a.case:continue
 start=time.perf_counter();print('START',case,flush=True)
 with (out/(case+'.stdout')).open('wb')as so,(out/(case+'.stderr')).open('wb')as se:r=subprocess.run(['bash',script],cwd=ROOT,env=env,stdout=so,stderr=se)
 events.append(dict(case=case,command=['bash',script],returncode=r.returncode,seconds=time.perf_counter()-start,stdout=case+'.stdout',stderr=case+'.stderr'))
 ee=[json.loads(p.read_text())for p in sorted((out/'compiler').glob('*.json'))];(out/'compiler-events.json').write_text(json.dumps(ee,indent=2)+'\n')
 result=dict(status='FAILED'if r.returncode else'PARTIAL_PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,events=events,compiler=subprocess.check_output([real,'--version'],text=True).splitlines()[0])
 (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
 print('FINISH',case,r.returncode,events[-1]['seconds'],flush=True)
 if r.returncode:
  print((out/(case+'.stderr')).read_text()[-4500:],flush=True);raise SystemExit(r.returncode)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in inputs.items()),'execution inputs mutated'
if not a.case:result['status']='THREE_EXISTING_CI_ROUTES_LOCAL_PASS'
result['cost_seconds']=dict(compile=sum(e['seconds']for e in ee if'-c'in e['args']),link=sum(e['seconds']for e in ee if'-c'not in e['args']and'-o'in e['args']),cases={e['case']:e['seconds']for e in events})
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)
