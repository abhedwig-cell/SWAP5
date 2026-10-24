"""Run full/split/resume native candidate, independently check accepted mass."""
import argparse,csv,json,subprocess,time
from pathlib import Path
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False);scratch=out.parent;exe=a.build.resolve()/'native_fct';r=dict(status='RUNNING',cases=[])
 for head in ['uniform','sloping']:
  case=out/head;case.mkdir();source=scratch/f'wet-initial-diagnostic/o2-{head}-frozen';events=[]
  for label,restart,stop in [('full','-',4),('split','-',2),('resume',str(case/'split/restart.bin'),4)]:
   folder=case/label;folder.mkdir();cmd=[str(exe),str(source/'input.nml'),restart,str(stop),str(source/'project.swp')];t=time.monotonic();p=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=180)
   (folder/'stdout').write_bytes(p.stdout);(folder/'stderr').write_bytes(p.stderr);events.append(dict(command=cmd,returncode=p.returncode,seconds=time.monotonic()-t));(case/'events.json').write_text(json.dumps(events,indent=2));assert p.returncode==0,p.stdout[-1000:]
  for name in ['restart.bin','state.csv','endpoint.csv']:assert (case/'full'/name).read_bytes()==(case/'resume'/name).read_bytes(),name
  read=lambda p:list(csv.DictReader(p.open()));full=read(case/'full/budget.csv');assert full[2:]==read(case/'resume/budget.csv') and len(full)==4
  maxima={}
  for s,u in [('water','cm'),('solute','mg_cm2')]:
   maxima[s]=max(abs(float(x[f'{s}_end_{u}'])-float(x[f'{s}_start_{u}'])-float(x[f'{s}_in_{u}'])+float(x[f'{s}_out_{u}'])) for x in full);assert maxima[s]<1e-10
  r['cases'].append(dict(head=head,exact_restart=True,maxima=maxima,events=events));(out/'RESULT.json').write_text(json.dumps(r,indent=2));print(head,maxima,flush=True)
 r['status']='BOUNDED_RESEARCH_CANDIDATE_NATIVE_RESTART_PASS';(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
if __name__=='__main__':main()
