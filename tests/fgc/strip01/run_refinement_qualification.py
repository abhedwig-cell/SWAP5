"""Local research qualification runner; expected failures remain evidence."""
import argparse,json,subprocess,sys
from pathlib import Path

def main():
 p=argparse.ArgumentParser();p.add_argument('--swap-library',required=True);p.add_argument('--mf-library',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--static-only',action='store_true');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);scripts=Path(__file__).resolve().parent;commands=[]
 def run(name,script,args,expected=0):
  cmd=[sys.executable,str(scripts/script),*args];r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);(a.output/(name+'.log')).write_text(r.stdout);commands.append(dict(name=name,command=cmd,expected_exit=expected,actual_exit=r.returncode));(a.output/'commands.json').write_text(json.dumps(commands,indent=2)+'\n');assert r.returncode==expected,(name,r.returncode,r.stdout[-2000:]);print(name,'EXPECTED_OUTCOME',flush=True)
 profile=a.output/'steady_transfer_initial.json';run('steady_oracle','steady_transfer.py',['--library',a.swap_library,'--output',str(profile)])
 common=['--swap-library',a.swap_library,'--mf-library',a.mf_library,'--initial-head','-5','--elastic-per-cm','1e-7']
 for name,extra,expected in [('strip01-steady-transfer-final',[],0),('strip01-steady-transfer-disconnected',['--disconnect-cell','50'],1)]:run(name,'run_coupled.py',[*common,'--dt','.1','--windows','10','--steady-profile',str(profile),'--output',str(a.output/name),*extra],expected)
 if a.static_only:return
 for name,flags in [('strip01-refinement-results',[]),('strip01-refinement-repaired',['--depth-budget-rate']),('strip01-refinement-allocated',['--depth-budget-rate','--newton-budget'])]:run(name,'refinement.py',['--library',a.swap_library,'--output',str(a.output/name),*flags])
 allocation=['--depth-budget-rate','--newton-budget','--mf-budget-allocate']
 for name,dt,count in [('strip01-clean-day005',.005,200),('strip01-clean-day0025',.0025,400)]:
  schedule=a.output/(name+'.json');schedule.write_text(json.dumps([3e-6]+[.0001]*4+[.001]*5+[dt]*count)+'\n');run(name,'run_coupled.py',[*common,*allocation,'--dt',str(dt),'--dt-sequence',str(schedule),'--output',str(a.output/name)])
 for name,extra in [('strip01-coupled-repaired',[]),('strip01-coupled-shifted',['--mf-datum-offset','5']),('strip01-coupled-cg',['--mf-linear-solver','CG']),('strip01-coupled-cg-shifted',['--mf-linear-solver','CG','--mf-datum-offset','5'])]:run(name,'run_coupled.py',[*common,'--depth-budget-rate','--newton-budget','--dt','.0001','--startup-dt','3e-6','--windows','5','--output',str(a.output/name),*extra],1)
 schedule=a.output/'day-ceiling.json';schedule.write_text(json.dumps([3e-6]+[.0001]*4+[.001]*5+[.005]*200+[.01])+'\n');run('strip01-coupled-one-day','run_coupled.py',[*common,*allocation,'--dt','.005','--dt-sequence',str(schedule),'--output',str(a.output/'strip01-coupled-one-day')],1)
 run('analysis','analyze_refinement.py',['--evidence',str(a.output),'--output',str(a.output/'figures')])
if __name__=='__main__':main()
