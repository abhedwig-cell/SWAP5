"""Positive classification control on the same frozen contexts; not a model-period run."""
from pathlib import Path
import os,json,subprocess,shutil,time
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());os.environ['PATH']=r'C:\msys64\ucrt64\bin;'+os.environ.get('PATH','');out=[]
for opt in ['O0','O2']:
 b=Path(res[opt]['path'])/'PERCHED_COMPONENT_R1';d=b/'LOW_CRIT_CONTROL';d.mkdir();src=b/'CANDIDATE';shutil.copyfile(src/'component.exe',d/'component.exe');lines=(src/'CONTEXTS.txt').read_text().splitlines();header=lines[0].split();assert float(header[2])==0.1;header[2]='0.01';lines[0]=' '.join(header);(d/'CONTEXTS.txt').write_text('\n'.join(lines)+'\n')
 t=time.perf_counter();p=subprocess.run([str(d/'component.exe')],cwd=d,capture_output=True,text=True,timeout=20);q=dict(opt=opt,status='FAILED',critical_air_cm=0.01,seconds=time.perf_counter()-t,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr,scope='Same frozen original heads/theta/grid; criterion-only analytic positive control; no full original model or trajectory claim');(d/'RUN.json').write_text(json.dumps(q,indent=2)+'\n');assert p.returncode==0
 rows=p.stdout.splitlines();assert len(rows)==4
 for line in rows[2:]:
  x=line.split();assert int(x[7])==24 and int(x[8])==28
 q['status']='REAL_PERCHED_RECOGNIZED_ON_BOTH_SIDES_WHEN_GAP_EXCEEDS_CRITERION';out.append(q);(d/'RUN.json').write_text(json.dumps(q,indent=2)+'\n')
q=dict(status='PASS_THRESHOLD_POSITIVE_CONTROL',results=out,models_launched='2 standalone CALCGWL executables; no SWAP model periods')
(R/'PERCHED_THRESHOLD_CONTROL.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
