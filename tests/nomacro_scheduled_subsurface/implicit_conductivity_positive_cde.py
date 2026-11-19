"""Actual positive chemical stock/source/reaction under implicit conductivity."""
import argparse,json,re,subprocess,sys,time
from pathlib import Path
import implicit_conductivity_runtime as c
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True)
 p.add_argument('--reuse-head-short',type=Path);p.add_argument('--reuse-head-full',type=Path)
 a=p.parse_args();assert bool(a.reuse_head_short)==bool(a.reuse_head_full);a.output.mkdir()
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
   if name=='head' and a.reuse_head_short:
    root=a.reuse_head_short;item=json.loads((root/'RESULT.json').read_text(encoding='utf8'));previous=Path(item['input_root'])
    assert c.m.e.inventory(inputs)==c.m.e.inventory(previous),'Actual qualified head numerical inputs differ'
    project=c.m.e.load(previous,original_output=True);c.m.validate_bundle(Path(item['build_root']),a.reference_work,project)
    assert item['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS' and item['trajectory']['days']==35 and len(item['cold'])==3
    args[-1]=str(previous);q['actual_current_source_head_pair_reused']=True
   else:root=a.output/('short-'+name);item=run(root,args)
   data=c.m.rows(root/'trajectory');c.m.check(data)
   metrics=dict(initial_stock=data[0]['solute_start_mg_cm2'],maximum_stock=max(row['solute_end_mg_cm2'] for row in data),actual_source=sum(row['solute_ledger_mg_cm2'][3] for row in data),actual_decay=sum(row['solute_ledger_mg_cm2'][6] for row in data))
   assert metrics['initial_stock']>0 and metrics['actual_source']>0 and metrics['actual_decay']>0,metrics
   q['cases'][name]=dict(short_root=str(root),short=item,metrics=metrics,arguments=args);save();print(name,'ACTUAL_POSITIVE_CHEMICAL_SHORT_NATIVE_PASS',flush=True)
  q['all_new_full_runs_after_positive_short_gates']=True;save()
  for name,case in cases.items():
   if not case[-1]:continue
   old=q['cases'][name]
   if name=='head' and a.reuse_head_full:
    root=a.reuse_head_full;item=json.loads((root/'RESULT.json').read_text(encoding='utf8'))
    assert item['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_FULL_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS' and item['build_root']==old['short']['build_root'] and item['input_root']==old['short']['input_root'] and len(item['cold'])==7
    data=c.m.rows(root/'trajectory');assert len(data)==1096;c.m.check(data)
   else:root=a.output/('full-'+name);item=run(root,[*old['arguments'],'--phase','full','--reuse-build',old['short']['build_root']])
   old.update(full_root=str(root),full=item);save();print(name,'ACTUAL_POSITIVE_CHEMICAL_FULL_NATIVE_PASS',flush=True)
  q['status']='THREE_POSITIVE_CHEMICAL_SHORT_TWO_FULL_IMPLICIT_CONDUCTIVITY_NATIVE_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
