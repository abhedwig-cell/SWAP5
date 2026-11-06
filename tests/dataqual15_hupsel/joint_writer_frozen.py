"""Typed immutable writer-research replay after the independent event successor.

No old guard is weakened and frozen execution does not qualify current physics.
"""
import argparse,json,subprocess,sys
from pathlib import Path
import joint_production as g
import joint_writer as writer
FROZEN='5264f3e0335b40df5aa5223cca84e028f5ae617d'
PEER='d32ebe55cd2ed8ee9e9d8ebe237a19994c1cdc57'
DELTA={'app/solute_project/main_water.f90','src/runtime/mod_interception_source_window_runtime.f90'}

def guard():
 assert {x for x in g.git('diff','--name-only',FROZEN,'HEAD','--','src','app','reference').splitlines()}==DELTA
 assert not g.git('diff','HEAD','--','src','app','reference')
 assert {a:g.blob('HEAD',a)for a in('src','app','reference')}=={a:g.blob(PEER,a)for a in('src','app','reference')}
 # All source, data, commands, control recipes and original acceptance checks
 # remain byte-identical to the fully executed immutable qualification tree.
 paths=set(g.frozen())|g.GATES
 paths|={'tests/dataqual15_hupsel/'+n+'.py'for n in('joint_writer','joint_writer_runtime','joint_writer_probe','joint_writer_evidence')}
 paths|={'tests/dataqual15_hupsel/joint_writer_candidates/'+Path(p).name for p in g.SOURCES.values()}
 for platform in('WINDOWS','POSIX'):
  for opt in('O0','O2'):
   stem='integration/dataqual15_hupsel/JOINT_WRITER_'+platform+'_'+opt+'_20261106'
   paths|={stem+'.json',stem+'.tar.xz'}
 for path in paths:
  assert g.raw('HEAD',path)==g.raw(FROZEN,path)==g.normal((g.ROOT/path).read_bytes())if not path.endswith(('.xz','.zip'))else g.raw('HEAD',path)==g.raw(FROZEN,path)==(g.ROOT/path).read_bytes()
 try:writer.guard()
 except AssertionError as error:
  assert str(error)=='exact three-reader production footprint'
 else:raise AssertionError('old current-source guard unexpectedly admitted independent event changes')

def main(out):
 guard();out.mkdir(parents=True,exist_ok=False)
 view=g.immutable_view(out,'qualified-writer-source',FROZEN)
 events=[]
 try:
  for platform in('WINDOWS','POSIX'):
   for opt in('O0','O2'):
    command=[sys.executable,'-B','tests/dataqual15_hupsel/joint_writer_evidence.py','--stem','JOINT_WRITER_'+platform+'_'+opt+'_20261106','--self-test']
    cp=subprocess.run(command,cwd=view,capture_output=True,timeout=1200)
    label=platform+'_'+opt
    (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
    events.append(dict(command=command,returncode=cp.returncode,platform=platform,optimization=opt))
    assert cp.returncode==0,cp.stderr[-3000:]
 finally:
  subprocess.run(['git','worktree','remove','--force',str(view)],cwd=g.ROOT,check=True,capture_output=True)
 result=dict(status='IMMUTABLE_PRIVATE_WRITER_RESEARCH_PASS',frozen=FROZEN,current_peer=PEER,head=g.git('rev-parse','HEAD'),events=events,current_old_guard='EXPECTED_REFUSAL_RETAINED',production_admission=False,current_physics_qualified=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();main(a.output.resolve())
