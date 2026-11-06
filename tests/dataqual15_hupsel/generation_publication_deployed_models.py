"""Actual current-tree POSIX recipes with production build/link integration."""
import argparse,json,os,subprocess,sys,time
from pathlib import Path
import generation_publication_admission as owner

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert os.name=='posix';owner.guard();out=a.output.resolve();out.mkdir(parents=True);events=[];results={}
 steps=[('accepted','run_accepted_output.py',[]),('csv','run_accepted_output_csv.py',['--physical',out/'accepted']),('joint','run_joint_output_generation.py',['--physical',out/'accepted','--csv',out/'csv']),('cold','run_native_output_project.py',[]),('saved','run_saved_output.py',['--cold',out/'cold'])]
 for label,recipe,extra in steps:
  cmd=[sys.executable,'-B',str(owner.ROOT/'tests/nut-output'/recipe),'--output',str(out/label),*map(str,extra)];start=time.monotonic();cp=subprocess.run(cmd,cwd=owner.ROOT,env=dict(os.environ,FC='/usr/bin/gfortran',OMP_NUM_THREADS='1'),capture_output=True,timeout=1800)
  for stream in ('stdout','stderr'):(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(label=label,command=cmd,returncode=cp.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,(label,cp.stderr[-5000:])
  results[label]=json.loads((out/label/'result.json').read_text());print(label,'ACTUAL_CURRENT_NATIVE_ASSERTIONS_PASS',flush=True)
 owner.guard();(out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_CURRENT_PRODUCTION_BUILD_AND_FIVE_NATIVE_RECIPES_O0_O2_PASS',source_head=owner.git('rev-parse','HEAD'),source_tree=owner.git('rev-parse','HEAD^{tree}'),production_sha256={n:owner.sha(owner.normal((owner.ROOT/n).read_bytes()))for n in owner.SOURCES},results=results,events=events,whole_scientific_admission=False),indent=2)+'\n')
if __name__=='__main__':main()
