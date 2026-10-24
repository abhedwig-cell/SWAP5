"""Reconstructed production Picard/Robin and incumbent typed contracts.

The lost test hashes remain in the historical receipt. This source needs fresh
execution; it is not presented as a byte recovery of those missing sources.
"""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 bundle=json.loads((a.bundle/'bundle.json').read_text());exe=Path(bundle['exe']);b=json.loads((exe.parent/'build-complete.json').read_text())
 out=a.output.resolve();out.mkdir();events=[]
 for path,h in b['input_sha256'].items():assert sha(ROOT/path)==h,path
 for path,h in b['reused_artifact_sha256'].items():assert sha(Path(path))==h,path
 physical=b['source_build'];objects=[e['command'][-1]for e in physical['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')]
 assert len(objects)==193
 archive=[p for p in b['reused_artifact_sha256']if p.endswith('/libttutil.a')];assert len(archive)==1
 tests=['tests/nut-sol/test_cauchy3_picard.f90','tests/fmig431/test_low03_typed_solver.f90']
 report=dict(status='RUNNING',events=events,source_sha256={p:sha(ROOT/p)for p in tests},build_candidate=b['candidate'])
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 for src in tests:
  stage=out/Path(src).stem;stage.mkdir()
  flags=[f for f in b['flags']if not f.startswith('-J')]+['-J'+str(stage)]
  for category,cmd in [('compile_link',b['compiler_command']+flags+[str(ROOT/src),*objects,*archive,'-o',str(stage/'test')]),('native',[str(stage/'test')])]:
   t=time.perf_counter();r=subprocess.run(cmd,cwd=stage,capture_output=True,timeout=120)
   for stream in ['stdout','stderr']:(stage/(category+'.'+stream)).write_bytes(getattr(r,stream))
   events.append(dict(category=category,command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t));save()
   assert r.returncode==0,r.stderr.decode()+r.stdout.decode()
 report['status']='REFERENCE_CAUCHY3_REAL_CONTRACTS_PASS';save();print(report['status'])
if __name__=='__main__':main()
