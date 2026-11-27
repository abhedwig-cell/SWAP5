"""One finite portable cohort for ordinary/Snow and Frost hydraulic state."""
import argparse,json,subprocess,sys,time
from pathlib import Path
R=Path(__file__).resolve().parents[2]
ORDINARY=['gardner-water','model7-snow-cde-fitted','model3-water','model4-snow-water','model5-cde-profile','model6-snow-cde-profile','mixed8-9-water','mixed10-11-snow-water','mixed1-7-cde']
FROST=['mixed2-3-water-d0-b5','mixed4-5-cde-d1-b5','mixed6-7-cde-d0-b8','mixed8-9-water-d1-b8','mixed10-11-water-d0-b5']
NATIVE={'ordinary-model7-snow-cde-fitted','ordinary-mixed8-9-water','frost-mixed4-5-cde-d1-b5','frost-mixed10-11-water-d0-b5'}
def main():
 p=argparse.ArgumentParser()
 for name in ['output','build-root','reference-work']:p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--platform',choices=['Windows','Ubuntu'],required=True)
 a=p.parse_args();a.output.mkdir();a.build_root.mkdir();head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
 q=dict(status='RUNNING_ACTUAL_PORTABLE_IMPLICIT_HYDRAULIC_STATE',actual_producer_source=head,platform=a.platform,optimization=a.optimization,canonical_admission=False,contexts=[],native_controls=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 for kind,case in [('ordinary',v) for v in ORDINARY]+[('frost',v) for v in FROST]:
  name=kind+'-'+case;script='implicit_'+('frost_' if kind=='frost' else '')+'hydraulic_state_feedback.py';folder=a.output/name
  cmd=[sys.executable,'-B',str(R/'tests/nomacro_drainage'/script),'--case',case,'--optimization',a.optimization,'--reference-work',str(a.reference_work),'--output',str(folder),'--build-output',str(a.build_root/name)]
  start=time.perf_counter()
  with (a.output/(name+'.stdout')).open('xb') as stdout,(a.output/(name+'.stderr')).open('xb') as stderr:child=subprocess.run(cmd,cwd=R,stdout=stdout,stderr=stderr)
  result=json.loads((folder/'RESULT.json').read_text()) if (folder/'RESULT.json').exists() else {}
  q['contexts'].append(dict(name=name,kind=kind,case=case,command=cmd,returncode=child.returncode,seconds=time.perf_counter()-start,actual_source=result.get('actual_source'),status=result.get('status'),error=result.get('error')));save()
  print(name,child.returncode,result.get('status'),flush=True)
  if child.returncode:continue
  if name in NATIVE:
   target=a.output/(name+'-native-controls');cmd=[sys.executable,'-B',str(R/'tests/nomacro_drainage/implicit_hydraulic_state_native_controls.py'),'--profile',str(folder),'--output',str(target),'--reference-work',str(a.reference_work)]
   with (a.output/(name+'-controls.stdout')).open('xb') as stdout,(a.output/(name+'-controls.stderr')).open('xb') as stderr:control=subprocess.run(cmd,cwd=R,stdout=stdout,stderr=stderr)
   q['native_controls'].append(dict(name=name,command=cmd,returncode=control.returncode));save()
 assert len(q['contexts'])==14
 good=all(v['returncode']==0 for v in q['contexts']) and len(q['native_controls'])==4 and all(v['returncode']==0 for v in q['native_controls'])
 q['status']='FOURTEEN_PORTABLE_ORIGINAL_IMPLICIT_HYDRAULIC_STATE_CONTEXTS_PASS_NOT_ADMITTED' if good else 'FAILED_PORTABLE_ORIGINAL_IMPLICIT_HYDRAULIC_STATE_CONTEXTS_OR_REFUSALS_RETAINED';save()
 if not good:raise SystemExit(1)
 print(q['status'],flush=True)
if __name__=='__main__':main()
