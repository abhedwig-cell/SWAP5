"""One coherent targeted groundwater water native/calendar qualification block."""
import argparse,json,subprocess,sys,time
from pathlib import Path
import groundwater_water_runtime as runtime

# implicit, hysteresis, perstep, nprintday, mode, format, reset, drainage, full
CASES={
 'explicit-ordinary':(0,0,False,1,'periodic',3,1,1,True),
 'explicit-history-step':(0,1,True,3,'explicit',2,0,1,False),
 'explicit-history-clock':(0,2,False,3,'monthly',0,0,0,True),
 'implicit-ordinary-step':(1,0,True,3,'explicit',3,1,1,True),
 'implicit-history-clock':(1,1,False,3,'periodic',2,0,1,False),
 'implicit-history-step':(1,2,True,1,'monthly',0,0,1,False),
}


def arguments(case):
 implicit,hys,step,npd,mode,fmt,reset,drainage,_=case
 return ['--implicit',str(implicit),'--hysteresis',str(hys),'--nprintday',str(npd),'--mode',mode,'--format',str(fmt),'--reset',str(reset),'--drainage',str(drainage),*(['--perstep'] if step else [])]


def main():
 p=argparse.ArgumentParser()
 for name in ('reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
 if not (a.reference_work/'PREPARED.json').exists():runtime.m.user_prepare.prepare(a.reference_work)
 runtime.m.user_prepare.validate(a.reference_work)
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime.ROOT,text=True).strip(),optimization=a.optimization,cases={},controls={},limits={},selection='Six short complete native contexts and actual active/public/policy controls before three representative full periods. Reuse unchanged physical providers; no old physical model campaigns.',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 def run(script,target,args):
  command=[sys.executable,'-B',str(Path(__file__).with_name(script)),'--reference-work',str(a.reference_work),'--output',str(target),'--optimization',a.optimization,*map(str,args)];start=time.monotonic();r=subprocess.run(command,cwd=runtime.ROOT,capture_output=True,text=True,timeout=600)
  (a.output/(target.name+'.stdout')).write_text(r.stdout,encoding='utf8');(a.output/(target.name+'.stderr')).write_text(r.stderr,encoding='utf8');q.setdefault('executions',[]).append(dict(command=command,returncode=r.returncode,seconds=time.monotonic()-start));save();r.check_returncode();return json.loads((target/'RESULT.json').read_text(encoding='utf8'))
 save()
 try:
  for name,case in CASES.items():
   target=a.output/('short-'+name);item=run('groundwater_water_runtime.py',target,[*arguments(case),'--phase','short']);q['cases'][name]=dict(short_root=str(target),short=item);save()
   controls=a.output/('controls-'+name);q['controls'][name]=dict(root=str(controls),report=run('groundwater_water_controls.py',controls,['--profile-root',target]));save()
  q['all_selected_short_native_public_active_gates_precede_full']=True;save()
  for name,case in CASES.items():
   if not case[-1]:continue
   short=q['cases'][name]['short'];target=a.output/('full-'+name);q['cases'][name].update(full_root=str(target),full=run('groundwater_water_runtime.py',target,[*arguments(case),'--phase','full','--reuse-build',short['build_root'],'--existing-input',short['input_root']]));save()
  for implicit in (0,1):
   target=a.output/('limit-'+str(implicit));q['limits'][str(implicit)]=dict(root=str(target),report=run('groundwater_water_runtime.py',target,['--implicit',implicit,'--hysteresis',1,'--nprintday',1440,'--mode','explicit','--format',3,'--reset',1,'--phase','limit']));save()
  q['status']='SIX_SHORT_THREE_FULL_TWO_LIMIT_GROUNDWATER_WATER_PUBLIC_NATIVE_COMPOSITION_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
