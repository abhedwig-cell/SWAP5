"""Full daily-receipt regression using existing validated host/checkpoint APIs.

One continuous trajectory publishes several ordinary checkpoints, avoiding a
second expensive cold trajectory solely to obtain a comparison endpoint.
"""
import argparse,contextlib,csv,hashlib,json,math,re,shutil,subprocess,sys,threading,time,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
import user_prepare
from daily_coupling import validate_bundle
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def physical(rows):return [{k:v for k,v in r.items() if k not in ('column','revision')} for r in rows]
def rows(path):return [json.loads(s) for s in (path/'daily.jsonl').read_text().splitlines()]
def csvlines(path):return [s for s in path.read_text().splitlines() if s.strip() and not s.startswith('*')]
def check(data):
 assert data and all(r['committed'] for r in data)
 for r in data:
  assert abs(r['independent_residual_cm'])<=1e-10 and abs(r['kernel_residual_cm'])<=1e-10
  if 'solute_independent_residual_mg_cm2' in r:assert abs(r['solute_independent_residual_mg_cm2'])<=1e-10
 return dict(days=len(data),max_water_cm=max(abs(r['independent_residual_cm']) for r in data),max_kernel_cm=max(abs(r['kernel_residual_cm']) for r in data),max_solute_mg_cm2=max(abs(r.get('solute_independent_residual_mg_cm2',0)) for r in data),sum_water_residual_cm=math.fsum(r['independent_residual_cm'] for r in data))
def inputs(path):
 source=ROOT/'reference/swap-4.3.1/projects/1.hupselbrook';path.mkdir()
 for p in source.iterdir():
  if p.is_file() and p.suffix.lower() in ('.swp','.met','.crp','.dra','.ini','.bbc'):shutil.copyfile(p,path/p.name)
 control=path/'swap.swp';text=control.read_text(encoding='cp1252')
 for k,v in [('SWDRA',0),('SWSP',1),('SWDC',1)]:
  text,n=re.subn(r'(?m)^([ \t]*'+k+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(v),text);assert n==1
 text,n=re.subn(r'(?m)^([ \t]*DECPOT[ \t]+FDEPTH[^\n]*\n)[ \t]*0\.0[ \t]+1\.00\n[ \t]*0\.0[ \t]+0\.65',r'\g<1>    0.001   1.00\n    0.001   0.65',text);assert n==1
 control.write_text(text,encoding='cp1252',newline='\n')
def bounded(seconds,callback):
 original=h.start_process;workers=[];expired=threading.Event()
 def track(*args,**kw):
  process,log=original(*args,**kw);workers.append(process);return process,log
 def stop():
  expired.set()
  for p in workers:
   if p.poll() is None:p.kill()
 h.start_process=track;timer=threading.Timer(seconds,stop);started=time.perf_counter();timer.start()
 try:return callback(),time.perf_counter()-started
 except Exception:
  if expired.is_set():raise TimeoutError('Model wall cap '+str(seconds)+'s')
  raise
 finally:
  timer.cancel();h.start_process=original
  for p in workers:
   if p.poll() is None:p.kill()
   p.wait(timeout=5)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--suite',choices=['candidate','O0','named'],default='candidate');p.add_argument('--build-bundle',type=Path);p.add_argument('--input-dir',type=Path);p.add_argument('--model-cap',type=float,default=480)
 a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False);user_prepare.validate(a.reference_work)
 if a.suite=='named':specs=[('grass',h.GRASSGROWTH,1827,[365,367,1827]),('hupsel',h.HUPSEL,1096,[365,367,1096]),('salt',h.SALTFARM,1461,[109,111,1461])]
 else:
  source=a.input_dir
  if source is None:source=a.output/'inputs';inputs(source)
  project=e.load(source)
  specs=[('undrained',project,1096,[50,52,530,532,1096])]
 reports={};commands=[]
 (a.output/'INVOCATION.json').write_text(json.dumps(dict(argv=sys.argv,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),suite=a.suite,host_api='Validated DailyHost.step + native checkpoint publisher; no build rebinding',model_cap_seconds=a.model_cap),indent=2))
 for name,project,last,cuts in specs:
  work=a.output/name;work.mkdir();build=a.build_bundle
  try:
   if build is None:
    build=work/'build';opt='O0' if a.suite=='O0' else 'O2'
    cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--reference-work',str(a.reference_work),'--build-only','--kernel-opt',opt,'--output',str(build)]
    if project.input_directory:cmd+=['--experimental-project',project.input_directory,'--donor-opt',opt]
    else:cmd+=['--no-macro-release']
    t=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
    (work/'build.stdout').write_text(r.stdout);(work/'build.stderr').write_text(r.stderr);commands.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode));assert r.returncode==0,r.stderr
   meta,case=validate_bundle(build,a.reference_work,project);binding=meta['binding'];donor=h.executable(build,'day_donor');kernel=h.executable(build,'day_kernel')
   user_prepare.validate_build(a.reference_work,meta['identity'])
   full=work/'full';full.mkdir();(full/'BUILD.json').write_text(json.dumps(meta,indent=2))
   def trajectory():
    with contextlib.ExitStack() as stack:
     host=h.DailyHost(stack,donor,kernel,case,full,[h.ColumnStart('original',0,None,None)],checkpoint_enabled=True,runtime=True,binding=binding,model=project.model,project=project)
     with (full/'daily.jsonl').open('w') as journal:
      for day in range(1,last+1):
       row=host.step(1,checkpoint=day in cuts);journal.write(json.dumps(row)+'\n');journal.flush()
       if not row['committed']:raise ValueError('Rejected day '+str(day))
       if day%100==0:print(name,'accepted',day,flush=True)
     host.close()
   _,seconds=bounded(a.model_cap,trajectory);data=rows(full);assert len(data)==last
   budgets=check(data);parsed=list(csv.DictReader(csvlines(full/'original/result_output.csv')));assert len(parsed)==last+1
   report=dict(status='FULL_PASS',full_days=last,budgets=budgets,model_seconds=seconds,build_sha256=sha(build/'BUILD.json'),profiles=dict(kernel_flags=meta['identity']['kernel_flags'],donor_flags=meta['identity']['donor_flags']),restart_windows=[])
   for start,end in zip(cuts[::2],cuts[1::2]):
    checkpoint=full/f'accepted-column-1-day-{start}.zip';digest=sha(checkpoint);origin=work/f'verified-{start}';receipt=h.verify_checkpoint(checkpoint,start,binding,origin)
    restarted=work/f'restart-{start}-{end}';restarted.mkdir()
    def continuation():return h.run(donor,kernel,case,restarted,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=binding,model=project.model,project=project)
    result,elapsed=bounded(60,continuation);assert result['first_refusal'] is None
    actual=rows(restarted);check(actual);assert physical(actual)==physical(data[start:end])
    # CSV has a header and an initial-state row before day1.
    assert csvlines(restarted/'original/result_output.csv')[-(end-start):]==csvlines(full/'original/result_output.csv')[start+2:end+2]
    with zipfile.ZipFile(restarted/f'accepted-column-1-day-{end}.zip') as x,zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as y:
     for native in ('result.end','macro.bin'):assert x.read(native)==y.read(native)
    assert sha(checkpoint)==digest
    report['restart_windows'].append(dict(start=start,end=end,exact_physical=True,exact_csv=True,exact_native_auxiliary=True,origin_unchanged=True,seconds=elapsed))
   reports[name]=report;print(name,'FULL_AND_NATIVE_RESTART_PASS',seconds,flush=True)
  except Exception as ex:
   reports[name]=dict(status='FAILED',error=repr(ex));print(name,'FAILED',repr(ex),flush=True)
  (a.output/'RESULT.json').write_text(json.dumps(reports,indent=2));(a.output/'COMMANDS.json').write_text(json.dumps(commands,indent=2))
 if any(r['status']!='FULL_PASS' for r in reports.values()):raise SystemExit(1)
if __name__=='__main__':main()
