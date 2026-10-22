"""Real committed root binding and rejected joint chemical trial; same-build reuse."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser()
 for opt in ['O0','O2']:ap.add_argument('--column-'+opt,type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 inputs=['tests/nut-sol/test_root_substep_transaction.f90','tests/nut-sol/qualify_root_substep_transaction.py']
 report={'status':'RUNNING','inputs':{p:sha(ROOT/p) for p in inputs},'builds':{},'events':[],'cases':{}}
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=60)
  n=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{n:04d}.{stream}').write_bytes(getattr(r,stream))
  report['events'].append({'command':list(map(str,cmd)),'returncode':r.returncode,'seconds':time.perf_counter()-start});save()
  assert r.returncode==0,(r.stdout,r.stderr)
  return r
 for opt in ['O0','O2']:
  column=getattr(args,'column_'+opt).resolve();build=json.loads((column.parent/'build-complete.json').read_text())
  assert build['status']=='BUILT' and sha(column)==build['executable_sha256']
  assert all(sha(ROOT/p)==h for p,h in build['input_sha256'].items())
  objects=[]
  for e in build['events']:
   if e['category']=='compile' and e['command'][-3]!=str(ROOT/'app/solute_crop/main.f90'):
    objects.append(Path(e['command'][-1]))
  # Each recorded compile command is FC flags -c SOURCE -o OBJECT.
  assert len(objects)==build['provider_count']-1
  identities={str(p):sha(p) for p in objects+[column.parent/'libttutil.a']}
  report['builds'][opt]=build
  case=out/opt;case.mkdir();exe=case/'transaction'
  flags=[f for f in build['flags'] if not f.startswith('-J')]+['-J'+str(case)]
  run(build['compiler_command']+flags+[ROOT/inputs[0],*objects,column.parent/'libttutil.a','-o',exe],case)
  r=run([exe],case);assert b'ROOT_SUBSTEP_FEEDBACK_TRACE_REJECTION_RETRY_ABA_ABSENT_PASS' in r.stdout
  assert all(sha(Path(p))==h for p,h in identities.items())
  assert (case/'original.bin').read_bytes()==(case/'rejected.bin').read_bytes()
  assert (case/'retry.bin').read_bytes()==(case/'fresh.bin').read_bytes()
  assert (case/'retry.bin').read_bytes()==(case/'again.bin').read_bytes()
  assert (case/'original.bin').read_bytes()==(case/'invalid.bin').read_bytes()
  assert (case/'absent.bin').read_bytes()==(case/'absent-fresh.bin').read_bytes()
  report['cases'][opt]={'original_rejected_sha256':sha(case/'original.bin'),'retry_fresh_sha256':sha(case/'retry.bin'),'reused_provider_objects':len(objects),'reused_artifact_sha256':identities}
 report['status']='ROOT_SUBSTEP_REAL_TRACE_REJECT_RETRY_ABA_O0_O2_PASS';save();print(json.dumps({'status':report['status'],'provider_objects':len(objects)}))
if __name__=='__main__':main()

