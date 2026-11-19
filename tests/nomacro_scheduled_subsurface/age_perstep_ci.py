"""Selected original AGE perstep short/native/1440 gates before full periods."""
import argparse,json,subprocess,sys,zipfile
from pathlib import Path
import age_perstep_runtime as c

ROOT=c.ROOT
# mode,hysteresis,format,reset,nprintday,source,ET,full
CASES={
 'ordinary-explicit-h0-binary':('explicit',0,3,1,1,'point',0,True),
 'history-monthly-h2-vector':('monthly',2,2,0,3,'interval',0,True),
 'ordinary-periodic-h0-ascii':('periodic',0,1,0,2,'surface',0,True),
 'history-explicit-h1-binary':('explicit',1,3,1,3,'sprinkler',0,True),
 'history-terminal-h2-ascii':('terminal',2,1,1,1,'interval',1,True),
 'history-periodic-h1-vector':('periodic',1,2,0,2,'point',0,True),
 'ordinary-explicit-h0-none':('explicit',0,0,1,1,'point',0,False),
 'history-monthly-h2-none':('monthly',2,0,0,3,'interval',0,False),
}
CONTROLS={'ordinary-explicit-h0-binary','history-monthly-h2-vector','history-explicit-h1-binary'}
LIMITS={
 'ordinary':('explicit',0,3,1,1440,'point',0,False),
 'history':('periodic',2,2,0,1440,'interval',0,False),
}


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--pilot-root',type=Path);p.add_argument('--limit-root',type=Path);p.add_argument('--control-root',type=Path)
 a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,cases={},controls={},limits={})
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 def run(script,target,arguments):
  command=[sys.executable,'-B',str(Path(__file__).with_name(script)),'--reference-work',str(a.reference_work),'--output',str(target),*map(str,arguments)]
  result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=600);(a.output/(target.name+'.stdout')).write_text(result.stdout,encoding='utf8');(a.output/(target.name+'.stderr')).write_text(result.stderr,encoding='utf8');result.check_returncode()
  return json.loads((target/'RESULT.json').read_text(encoding='utf8'))
 def arguments(case):
  mode,hys,fmt,reset,npd,source,et,_=case
  return ['--mode',mode,'--hysteresis',hys,'--format',fmt,'--reset',reset,'--nprintday',npd,'--source',source,'--et',et,'--optimization',a.optimization]
 def reused(path,case,phase):
  report=json.loads((path/'RESULT.json').read_text(encoding='utf8'));assert report['status']=='ACTUAL_AGE_PERSTEP_'+phase.upper()+'_SOURCE_NATIVE_OUTPUT_PASS'
  params=report['parameters'];assert tuple(params[k] for k in ('mode','hysteresis','format','reset','nprintday','source','optimization'))==tuple(case[:6])+(a.optimization,)
  assert params.get('et',0)==case[6]
  project=c.m.e.load(path/'input',original_output=True);c.m.validate_bundle(path/'build',a.reference_work,project)
  return report
 save()
 try:
  for key,case in CASES.items():
   family={'ordinary-explicit-h0-binary':'ordinary','history-monthly-h2-vector':'history'}.get(key)
   short=a.pilot_root/f'age-perstep-{family}-{a.optimization}-v4' if a.pilot_root and family else a.output/('short-'+key)
   report=reused(short,case,'short') if a.pilot_root and family else run('age_perstep_runtime.py',short,arguments(case))
   q['cases'][key]=dict(short_root=str(short),input_root=report.get('input_root',str(short/'input')),build_root=report.get('build_root',str(short/'build')),short=report);save();print(key,'SHORT_PASS',flush=True)
  for key in CONTROLS:
   family={'ordinary-explicit-h0-binary':'ordinary','history-monthly-h2-vector':'history'}.get(key)
   target=a.control_root/f'age-perstep-controls-{family}-{a.optimization}-v2' if a.control_root and family else a.output/('control-'+key)
   report=json.loads((target/'RESULT.json').read_text(encoding='utf8')) if a.control_root and family else run('age_perstep_controls.py',target,['--profile-root',q['cases'][key]['short_root']])
   assert report['status']=='AGE_PERSTEP_NATIVE_PRIVATE_ACTIVE_POLICY_PROVIDER_PASS';q['controls'][key]=dict(root=str(target),report=report);save()
  for key,case in LIMITS.items():
   target=a.limit_root/f'age-perstep-limit-{key}-{a.optimization}-v2' if a.limit_root else a.output/('limit-'+key)
   report=reused(target,case,'limit') if a.limit_root else run('age_perstep_runtime.py',target,arguments(case)+['--phase','limit'])
   q['limits'][key]=dict(root=str(target),report=report);save()
  q['format_independence']={}
  for fullkey,nonekey in [('ordinary-explicit-h0-binary','ordinary-explicit-h0-none'),('history-monthly-h2-vector','history-monthly-h2-none')]:
   aroot=Path(q['cases'][fullkey]['short_root'])/'trajectory';broot=Path(q['cases'][nonekey]['short_root'])/'trajectory'
   assert c.m.physical(c.m.rows(aroot))==c.m.physical(c.m.rows(broot))
   for day in (2,4,8,35):
    with zipfile.ZipFile(aroot/f'accepted-column-1-day-{day}.zip') as az,zipfile.ZipFile(broot/f'accepted-column-1-day-{day}.zip') as bz:
     assert all(az.read(n)==bz.read(n) for n in ('result.end','macro.bin'))
   q['format_independence'][fullkey]=dict(all35_physical_days_exact=True,four_complete_native_payloads_exact=True)
  q['all_short_native_limit_gates_precede_full']=True;save()
  for key,case in CASES.items():
   if not case[-1]:continue
   item=q['cases'][key];target=a.output/('full-'+key)
   item['full']=run('age_perstep_runtime.py',target,arguments(case)+['--phase','full','--reuse-build',item['build_root'],'--existing-input',item['input_root']]);item['full_root']=str(target);save();print(key,'FULL_PASS',flush=True)
  q['status']='EIGHT_AGE_PERSTEP_SHORT_SIX_FULL_THREE_NATIVE_TWO_LIMIT_CONTEXTS_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
