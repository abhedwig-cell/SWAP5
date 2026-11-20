"""Selected primary drainage interaction batch on the actual current source."""
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('reference-work','build-root','output','primary-full'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 contexts=[('automatic',kind,h) for kind in ('water','cde') for h in (0,1,2)]+[('prescribed','water',0),('prescribed','cde',0),('prescribed','cde',2)]
 result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),selection='Nine35day contexts per optimization; automatic water/CDE h0/1/2 and prescribed waterh0/CDEh0,h2. Actual original constituent/state owners; no unrelated full reruns.',contexts=[])
 for case,kind,h in contexts:
  label=f'{case}-{kind}-h{h}';out=a.output/label;mode,fmt=('monthly','2') if kind=='water' else ('daily','3')
  args=['tests/nomacro_drainage/calendar_runtime.py','--case',case,'--mode',mode,'--format',fmt,'--hysteresis',str(h),'--implicit','--days','35','--optimization',a.optimization,'--reference-work',str(a.reference_work),'--build-root',str(a.build_root/label),'--output',str(out)]
  if kind=='water':args.append('--water-only')
  if (case,kind,h)==('automatic','water',0):args+=['--reuse-build',json.loads((a.primary_full/'RESULT.json').read_text())['build_root']]
  for phase,command in [('producer',args),('independent',['tests/nomacro_drainage/implicit_forensics.py',str(out),'--output',str(out/'FORENSICS_V1.json')])]:
   v=subprocess.run([sys.executable,'-B',*command],cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/(label+'-'+phase+'.stdout')).write_text(v.stdout);(a.output/(label+'-'+phase+'.stderr')).write_text(v.stderr);v.check_returncode()
  result['contexts'].append(dict(case=case,kind=kind,hysteresis=h,root=str(out)));(a.output/'RESULT.json').write_text(json.dumps(result,indent=2));print(label,a.optimization,'PASS',flush=True)
 result['status']='ACTUAL_NINE_PRIMARY_IMPLICIT35DAY_INTERACTIONS_AND27EXACT_NATIVE_WINDOWS_PASS';(a.output/'RESULT.json').write_text(json.dumps(result,indent=2))
if __name__=='__main__':main()
