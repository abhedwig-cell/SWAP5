"""Two real maximum-cadence transport compositions, each only two days."""
import argparse,json,subprocess,sys,time
from pathlib import Path
import implicit_conductivity_runtime as c


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--pilot-root',type=Path);a=p.parse_args();a.output.mkdir()
 q=dict(status='RUNNING',optimization=a.optimization,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),cases={},selection='Actual implicit conductivity with original1440print/day and FLPRINTDT; CDE head and hysteretic water air-boundary select distinct real transport/history/clock boundaries. Implicit AGE is outside admission. Only2days each plus1to2complete native cold, not35/1096day stress.')
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 save()
 try:
  for name,solute,hys,bottom,k in [('cde-head',1,0,5,3),('water-air-history',0,1,8,2)]:
   old=a.pilot_root/f'implicit-conductivity-limit-{name}-{a.optimization}-v1' if a.pilot_root else None
   if old and (old/'RESULT.json').exists():
    root=old;item=json.loads((root/'RESULT.json').read_text(encoding='utf8'));project=c.m.e.load(Path(item['input_root']),original_output=True);c.m.validate_bundle(Path(item['build_root']),a.reference_work,project);elapsed=None
   else:
    root=a.output/name;cmd=[sys.executable,'-B',str(Path(__file__).with_name('implicit_conductivity_runtime.py')),'--reference-work',str(a.reference_work),'--output',str(root),'--optimization',a.optimization,'--solute',str(solute),'--hysteresis',str(hys),'--bottom',str(bottom),'--kmean',str(k),'--perstep','--nprintday','1440','--phase','limit']
    start=time.perf_counter();r=subprocess.run(cmd,cwd=c.ROOT,capture_output=True,text=True,timeout=300);elapsed=time.perf_counter()-start;(a.output/(name+'.stdout')).write_text(r.stdout,encoding='utf8');(a.output/(name+'.stderr')).write_text(r.stderr,encoding='utf8');r.check_returncode();item=json.loads((root/'RESULT.json').read_text(encoding='utf8'))
   assert item['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_LIMIT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS' and item['trajectory']['days']==2 and len(item['cold'])==1
   assert item['parameters']['nprintday']==1440 and item['parameters']['perstep'] is True
   q['cases'][name]=dict(root=str(root),report=item,seconds=elapsed,actual_current_source_pilot_reused=root==old);save();print(name,'ACTUAL_1440_TWO_DAY_COMPLETE_COLD_PASS',flush=True)
  q['status']='TWO_ACTUAL_IMPLICIT_WATER_CDE_1440_NATIVE_LIMITS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
