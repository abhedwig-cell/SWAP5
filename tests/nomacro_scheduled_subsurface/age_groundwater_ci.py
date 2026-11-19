"""Selected real AGE groundwater short/state/limit gates before full periods."""
import argparse,json,subprocess,sys,time,zipfile
from pathlib import Path
import age_groundwater_runtime as c

ROOT=c.ROOT
# hys,perstep,mode,format,reset,nprint,source,ET,level,drainage,external BBC,full
CASES={
 'ordinary-periodic-crossing-binary':(0,False,'periodic',3,0,1,'point',0,'crossing',1,False,True),
 'history-periodic-crossing-binary':(2,False,'periodic',3,0,1,'point',0,'crossing',1,False,True),
 'history-explicit-perstep-binary':(1,True,'explicit',3,1,3,'point',0,'crossing',1,False,True),
 'ordinary-monthly-below-vector':(0,False,'monthly',2,0,2,'interval',1,'below',0,True,True),
 'history-terminal-within-ascii':(2,False,'terminal',1,1,1,'surface',0,'within',1,False,True),
 'history-explicit-crossing-vector':(1,False,'explicit',2,1,1,'sprinkler',1,'crossing',0,False,True),
 'ordinary-periodic-crossing-none':(0,False,'periodic',0,0,1,'point',0,'crossing',1,False,False),
 'history-periodic-crossing-none':(2,False,'periodic',0,0,1,'point',0,'crossing',1,False,False),
}
PILOTS={'ordinary-periodic-crossing-binary':'ordinary','history-periodic-crossing-binary':'history','history-explicit-perstep-binary':'perstep'}
LIMITS={'ordinary':(0,True,'explicit',3,1,1440,'point',0,'crossing',1,False,False),'history':(2,True,'periodic',3,0,1440,'point',0,'crossing',1,False,False)}


def arguments(case):
 hys,step,mode,fmt,reset,npd,source,et,level,drain,bbc,_=case
 return ['--hysteresis',str(hys),*(['--perstep'] if step else []),'--mode',mode,'--format',str(fmt),'--reset',str(reset),'--nprintday',str(npd),'--source',source,'--et',str(et),'--level-kind',level,'--drainage',str(drain),*(['--boundary-file'] if bbc else [])]


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--pilot-root',type=Path);a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,cases={},controls={},limits={})
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 def run(script,target,args):
  cmd=[sys.executable,'-B',str(Path(__file__).with_name(script)),'--reference-work',str(a.reference_work),'--output',str(target),*args]
  t=time.perf_counter();p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=600);(a.output/(target.name+'.stdout')).write_text(p.stdout,encoding='utf8');(a.output/(target.name+'.stderr')).write_text(p.stderr,encoding='utf8');p.check_returncode()
  result=json.loads((target/'RESULT.json').read_text(encoding='utf8'));return result,time.perf_counter()-t
 def reused(root,phase):
  item=json.loads((root/'RESULT.json').read_text(encoding='utf8'));assert item['status']=='ACTUAL_ORIGINAL_AGE_GROUNDWATER_'+phase+'_PHYSICAL_NATIVE_OUTPUT_PASS'
  build=Path(item.get('build_root',root/'build'));inputs=Path(item.get('input_root',root/'input'));project=c.m.e.load(inputs,original_output=True);meta,_=c.m.validate_bundle(build,a.reference_work,project)
  assert meta['identity']['original_output']==item['original_output'];return item
 save()
 try:
  for key,case in CASES.items():
   family=PILOTS.get(key);root=a.pilot_root/f'age-groundwater-{family}-{a.optimization}-current-v1' if a.pilot_root and family else a.output/('short-'+key)
   item=reused(root,'SHORT') if a.pilot_root and family else run('age_groundwater_runtime.py',root,arguments(case)+['--optimization',a.optimization])[0]
   q['cases'][key]=dict(short_root=str(root),short=item,input_root=item.get('input_root',str(root/'input')),build_root=item.get('build_root',str(root/'build')));save();print(key,'SHORT_PASS',flush=True)
  for key in PILOTS:
   old=a.pilot_root/f'age-groundwater-controls-{PILOTS[key]}-{a.optimization}-current-v1' if a.pilot_root else None
   if old and (old/'RESULT.json').exists():
    root=old;item=json.loads((root/'RESULT.json').read_text(encoding='utf8'));assert item['status']=='AGE_GROUNDWATER_NATIVE_PRIVATE_ACTIVE_POLICY_PROVIDER_PASS' and item['build_sha256']==c.m.sha(Path(q['cases'][key]['build_root'])/'BUILD.json');seconds=None
   else:root=a.output/('control-'+key);item,seconds=run('age_groundwater_controls.py',root,['--profile-root',q['cases'][key]['short_root']])
   assert item['status']=='AGE_GROUNDWATER_NATIVE_PRIVATE_ACTIVE_POLICY_PROVIDER_PASS';q['controls'][key]=dict(root=str(root),report=item,seconds=seconds,actual_prior_current_source_gate_reused=bool(old and root==old));save()
  for key,case in LIMITS.items():
   root=a.pilot_root/f'age-groundwater-limit-{key}-{a.optimization}-current-v1' if a.pilot_root else a.output/('limit-'+key)
   item=reused(root,'LIMIT') if a.pilot_root else run('age_groundwater_runtime.py',root,arguments(case)+['--optimization',a.optimization,'--phase','limit'])[0]
   assert abs(item['actual_fixed_input_cm']-2.4)<=1e-10;q['limits'][key]=dict(root=str(root),report=item);save()
  q['format_independence']={}
  for fullkey,nonekey in [('ordinary-periodic-crossing-binary','ordinary-periodic-crossing-none'),('history-periodic-crossing-binary','history-periodic-crossing-none')]:
   ar=Path(q['cases'][fullkey]['short_root'])/'trajectory';br=Path(q['cases'][nonekey]['short_root'])/'trajectory';assert c.m.physical(c.m.rows(ar))==c.m.physical(c.m.rows(br))
   for day in (2,4,9,35):
    with zipfile.ZipFile(ar/f'accepted-column-1-day-{day}.zip') as az,zipfile.ZipFile(br/f'accepted-column-1-day-{day}.zip') as bz:assert all(az.read(name)==bz.read(name) for name in ('result.end','macro.bin'))
   q['format_independence'][fullkey]=dict(all35_physical_days_exact=True,four_complete_native_payloads_exact=True)
  q['all_short_native_limit_gates_precede_full']=True;save()
  for key,case in CASES.items():
   if not case[-1]:continue
   item=q['cases'][key];target=a.output/('full-'+key);item['full'],item['full_seconds']=run('age_groundwater_runtime.py',target,arguments(case)+['--optimization',a.optimization,'--phase','full','--existing-input',item['input_root'],'--reuse-build',item['build_root']]);item['full_root']=str(target);save();print(key,'FULL_PASS',flush=True)
  q['status']='EIGHT_AGE_GROUNDWATER_SHORT_SIX_FULL_THREE_NATIVE_TWO_LIMIT_CONTEXTS_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
