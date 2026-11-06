"""Cold current complete-source three-reader qualification after physical delta."""
import argparse,json,os,shutil,subprocess
from pathlib import Path
from joint_logical import ROOT,NAMES,SOURCES,normal,sha,candidate,age_literal,prepare,build,measure,prior
BASE='5a6cde28d49e584fa88ce087c848b6acd24c56fd'

def guard():
 assert subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,capture_output=True).returncode==0
 for area in ('src','app','reference'):
  assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT)==subprocess.check_output(['git','rev-parse',BASE+':'+area],cwd=ROOT)
  assert not subprocess.check_output(['git','diff','HEAD','--',area],cwd=ROOT)
 assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','src','app','reference'],cwd=ROOT)
 for name in NAMES:
  assert candidate(name)==normal((ROOT/'tests/dataqual15_hupsel/joint_logical_candidates'/Path(SOURCES[name]).name).read_bytes())
 return dict(source_sha256={path:sha(normal((ROOT/path).read_bytes()))for path in SOURCES.values()})

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--optimization',choices=('O0','O2'),required=True);parser.add_argument('--compiler',default=shutil.which('gfortran'));a=parser.parse_args()
 guard();os.environ['OMP_NUM_THREADS']='1';out=a.output.resolve();prior.guard=guard;prior.DRIVERS=dict(prior.DRIVERS,age='tests/nut-sol/test_age_joint.f90')
 fixture,ordered,drivers=prepare(out);assert len(ordered)==335
 result=dict(status='RUNNING',baseline=BASE,optimization=a.optimization,production_admission=False,whole_scientific_admission=False,roles={})
 for role in ('baseline','candidate'):
  directory=out/role;exes,events=build(directory,Path(a.compiler).resolve(),a.optimization,fixture,ordered,drivers,out/'baseline'if role=='candidate'else None)
  result['roles'][role]=measure(directory,exes,events,role)
  (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(role,'complete current335-provider native and physical execution',flush=True)
 for name in NAMES:
  for leaf in ('restart.bin','end.bin','fresh.bin'):assert(out/'baseline'/name/leaf).read_bytes()==(out/'candidate'/name/leaf).read_bytes()
 result['status']='COMPLETE_PRIVATE_JOINT_LOGICAL_READER_CLUSTER_PASS';(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');guard()
 import joint_current_evidence as evidence
 platform='WINDOWS'if os.name=='nt'else'POSIX';stem='JOINT_CURRENT_'+platform+'_'+a.optimization+'_20261106';evidence.pack(out,stem);print(json.dumps(evidence.verify(stem,True),sort_keys=True))

if __name__=='__main__':main()
