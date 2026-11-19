"""Actual positive chemical stock/source/reaction under implicit conductivity."""
import argparse,json,re,subprocess,sys,time
from pathlib import Path
import implicit_conductivity_runtime as c
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),optimization=a.optimization,cases={},selection='Main CDE numerical/state prototypes have zero initial/source chemical stock. They are execution/native observations, not active chemical proof. Select real positive0.1initial concentration, actual fixed20concentration source, existing original sorption and0.001decomposition at head/air/GW. Three35day/native gates precede two1096day source/reaction full periods. Unchanged chemical component qualification is not reissued as fresh PASS.')
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 def run(target,extra):
  cmd=[sys.executable,'-B',str(Path(__file__).with_name('implicit_conductivity_runtime.py')),'--reference-work',str(a.reference_work),'--output',str(target),'--optimization',a.optimization,*extra]
  t=time.perf_counter();r=subprocess.run(cmd,cwd=c.ROOT,capture_output=True,text=True,timeout=600);(a.output/(target.name+'.stdout')).write_text(r.stdout,encoding='utf8');(a.output/(target.name+'.stderr')).write_text(r.stderr,encoding='utf8');q.setdefault('executions',[]).append(dict(command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t));save();r.check_returncode();return json.loads((target/'RESULT.json').read_text(encoding='utf8'))
 save()
 try:
  cases={'head':(0,5,3,True,'explicit',True),'air-history':(1,8,2,False,'explicit',False),'groundwater-history':(2,1,4,False,'daily',True)}
  for name,(hys,bot,k,step,mode,full) in cases.items():
   inputs=a.output/('input-'+name);c.fixture(inputs,1,hys,bot,step,k,mode,3,0 if bot==1 else 1)
   path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
   for key in ('SWSP','SWDC'):text=assignment(text,key,1)
   for pattern,rows in [(r'(?mi)^([ \t]*CMLTB[ \t]*=[ \t]*\n).*?^\* End of table',' -10.0 0.1\n -95.0 0.1\n'),(r'(?mi)^([ \t]*DECPOT[ \t]+FDEPTH[^\r\n]*\n).*?^\* End of Table','0.001 1.0\n0.001 0.65\n')]:
    text,count=re.subn(pattern,lambda m:m[1]+rows+'* End of table',text,count=1,flags=re.S);assert count==1
   path.write_text(text,encoding='cp1252');path=inputs/'fixed-irrigation.irg';text=path.read_text(encoding='cp1252');assert text.count('24.0 0.0')==1;path.write_text(text.replace('24.0 0.0','24.0 20.0'),encoding='cp1252')
   args=['--solute','1','--hysteresis',str(hys),'--bottom',str(bot),'--kmean',str(k),'--mode',mode,'--reset','0' if bot==1 else '1',*(['--perstep'] if step else []),'--existing-input',str(inputs)]
   root=a.output/('short-'+name);item=run(root,args);data=c.m.rows(root/'trajectory')
   metrics=dict(initial_stock=data[0]['solute_start_mg_cm2'],maximum_stock=max(row['solute_end_mg_cm2'] for row in data),actual_source=sum(row['solute_ledger_mg_cm2'][3] for row in data),actual_decay=sum(row['solute_ledger_mg_cm2'][6] for row in data))
   assert metrics['initial_stock']>0 and metrics['actual_source']>0 and metrics['actual_decay']>0,metrics
   q['cases'][name]=dict(short_root=str(root),short=item,metrics=metrics,arguments=args);save();print(name,'ACTUAL_POSITIVE_CHEMICAL_SHORT_NATIVE_PASS',flush=True)
  q['all_positive_short_native_before_full']=True;save()
  for name,case in cases.items():
   if not case[-1]:continue
   old=q['cases'][name];root=a.output/('full-'+name);item=run(root,[*old['arguments'],'--phase','full','--reuse-build',old['short']['build_root']]);old.update(full_root=str(root),full=item);save();print(name,'ACTUAL_POSITIVE_CHEMICAL_FULL_NATIVE_PASS',flush=True)
  q['status']='THREE_POSITIVE_CHEMICAL_SHORT_TWO_FULL_IMPLICIT_CONDUCTIVITY_NATIVE_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
