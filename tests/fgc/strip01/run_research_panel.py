"""Reproduce bounded STRIP01 research successes and negative controls locally."""
import argparse,json,subprocess,sys
from pathlib import Path

def main():
 p=argparse.ArgumentParser();p.add_argument('--swap-library',required=True);p.add_argument('--mf-library',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 a.output.mkdir(parents=True,exist_ok=True);scripts=Path(__file__).resolve().parent;rows=[]
 cases=[('rain_1e4',1e-4,.1,-4.5,-4.5,0),('rain_1e3',1e-3,.1,-4.5,-4.5,0),('rain_1e2',1e-2,.1,-4.5,-4.5,0),('hydrostatic',1e-4,0,-4.5,-4.5,0),('rain_shifted',1e-4,.1,-4.55,-4.55,0),('head_drop',1e-4,0,-4.5,-4.500001,0),('rain_unsaturated',1e-7,.1,-6.5,-6.5,0),('elastic_1e4',1e-4,.1,-4.5,-4.5,1e-7),('elastic_1e3',1e-3,.1,-4.5,-4.5,1e-7),('elastic_1e2',1e-2,.1,-4.5,-4.5,1e-7),('elastic_short',3e-6,.1,-4.5,-4.5,1e-7),('elastic_equilibrated',3e-6,.1,-5,-5,1e-7)]
 def run(name,cmd):
  r=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(a.output/(name+'.log')).write_text(r.stdout);rows.append(dict(case=name,command=cmd,exit_code=r.returncode));print(name,r.returncode,flush=True)
 for name,dt,rain,initial,head,elastic in cases:
  run(name,[sys.executable,str(scripts/'component.py'),'--library',a.swap_library,'--dt',str(dt),'--rain-cm-day',str(rain),'--initial-head',str(initial),'--head',str(head),'--elastic-per-cm',str(elastic),'--output',str(a.output/(name+'.json'))])
 for name,initial,dt,windows,startup in [('coupled_initial_jump',-4.5,3e-6,1,None),('coupled_short',-5,3e-6,4,None),('coupled_extension',-5,1e-4,5,3e-6),('coupled_longer',-5,.01,4,3e-6)]:
  cmd=[sys.executable,str(scripts/'run_coupled.py'),'--swap-library',a.swap_library,'--mf-library',a.mf_library,'--dt',str(dt),'--windows',str(windows),'--initial-head',str(initial),'--elastic-per-cm','1e-7','--output',str(a.output/name)]
  if startup:cmd+=['--startup-dt',str(startup)]
  run(name,cmd)
 (a.output/'panel.json').write_text(json.dumps(dict(status='RESEARCH_PANEL_EXECUTED_NOT_FULL_C_QUALIFICATION',cases=rows),indent=2)+'\n')
 expected={'hydrostatic','rain_unsaturated','elastic_short','elastic_equilibrated','coupled_short'}
 assert all((row['exit_code']==0)==(row['case'] in expected) for row in rows),'outcome changed: inspect evidence'
if __name__=='__main__':main()
