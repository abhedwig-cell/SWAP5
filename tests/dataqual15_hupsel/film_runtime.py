"""Coherent private default runtime, actual observation and strict own restart."""
import argparse,csv,hashlib,json,os,re,shutil,struct,subprocess,sys,tarfile,time,zlib
from pathlib import Path
import film_runtime_counter as counter
from film_runtime_profiles import profile4
from production_diagnostic_admission import ROOT,SCOPE,current_guard
BASE=ROOT/'integration/dataqual15_hupsel';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def inputs(out):
 record=json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text());archive=BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.tar.xz'
 assert sha(archive)==record['archive_sha256']=='7663b5e2837106e37741728c85ba1357a91952d7256048e50bf20788966d8577';out.mkdir()
 with tarfile.open(archive)as t:
  members=t.getmembers();assert set(t.getnames())==set(record['files_sha256'])and all(m.isfile()and Path(m.name).name==m.name for m in members)
  for m in members:(out/m.name).write_bytes(t.extractfile(m).read())
 assert all(sha(out/n)==pin for n,pin in record['files_sha256'].items());return out

def validate_baseline(baseline,old):
 assert old['status']=='BUILT'and old['build_mode']=='clean-source'and old['reuse_candidate']is None
 assert len(old['source_sha256'])==len(old['object_sha256'])==len(old['changed'])==236
 assert Path(list(old['source_sha256'])[-1])==ROOT/counter.MAIN
 external=[]
 for name in old['source_sha256']:
  path=Path(name)
  if path.is_relative_to(ROOT):assert path.relative_to(ROOT).as_posix().startswith(('src/','app/'))
  else:external.append(path)
 assert len(external)==1 and external[0].name=='legacy_swp_original.f90'
 assert Path(old['ttutil_archive'])==baseline/'libttutil.a'
 assert Path(old['publication_provider']['source'])==ROOT/'app/support/restart_publish.c'
 assert Path(old['publication_provider']['object'])==baseline/'restart_publish.o'

def build(baseline,out,compiler,observed=False):
 out.mkdir();old=json.loads((baseline/'BUILD.json').read_text());validate_baseline(baseline,old)
 assert subprocess.check_output([str(compiler),'--version'],text=True).splitlines()[0]==old['compiler']
 for part in ('source_sha256','object_sha256'):assert all(sha(Path(p))==pin for p,pin in old[part].items())
 provider=old['publication_provider'];assert all(sha(Path(provider[k]))==provider[k+'_sha256']for k in ('source','object'))
 assert sha(Path(old['ttutil_archive']))==old['archive_sha256']
 source=(ROOT/counter.SOURCE).read_text();body=counter.candidate.candidate(source)
 kernel=out/'waterfilm_private.f90';kernel.write_text(counter.kernel(body)if observed else body,encoding='utf-8',newline='\n')
 main=out/'main_observed.f90'
 if observed:main.write_text(counter.main((ROOT/counter.MAIN).read_text()),encoding='utf-8',newline='\n')
 flags=[x for x in old['flags']if not x.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
 events=[];objects=[];sources={};changed=[]
 def run(cmd):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=300);i=len(events)
  (out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr)
  events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,r.stderr.decode(errors='replace')[-2000:]
 for i,path in enumerate(old['source_sha256']):
  before=Path(path);relative=before.relative_to(ROOT).as_posix()if before.is_relative_to(ROOT)else None
  actual=kernel if relative==counter.SOURCE else main if observed and relative==counter.MAIN else before
  if actual!=before:changed.append(relative)
  obj=out/f'{i}.o';run([compiler,*flags,'-c',actual,'-o',obj]);objects.append(obj);sources[str(actual)]=sha(actual)
 assert set(changed)==({counter.SOURCE,counter.MAIN}if observed else{counter.SOURCE})and len(objects)==236
 exe=out/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination')
 args=['-fopenmp']+(['-Wl,--stack,16777216']if os.name=='nt'else[])+list(map(str,objects))+[provider['object'],old['ttutil_archive'],'-o',str(exe)]
 response=out/'link.args';response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n',encoding='utf-8');run([compiler,'@'+str(response)])
 result=dict(status='BUILT',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=old['compiler'],flags=flags,provider_count=236,
  source_sha256=sources,object_sha256={str(p):sha(p)for p in objects},executable_sha256=sha(exe),publication_provider=provider,ttutil_archive=old['ttutil_archive'],archive_sha256=old['archive_sha256'],
  baseline=old,interventions=changed,complete_module_closure_rebuilt=True,private_kernel_source_sha256=sha(kernel),numerical_candidate_sha256=hashlib.sha256(body.encode()).hexdigest(),
  observed=observed,production_admission=False,events=events)
 (out/'BUILD.json').write_text(json.dumps(result,indent=2)+'\n');return exe

def execute(exe,source,out,end,seed=None,capture=()):
 out.mkdir();files={}
 for p in source.iterdir():
  if p.suffix.lower()in ('.swp','.crp','.dra','.met','.nml'):shutil.copyfile(p,out/p.name);files[p.name]=sha(p)
 ends=[float(x)for x in re.search(r'^ends_day=(.*)$',(out/'input.nml').read_text(),re.M)[1].split(',')if x.strip()];stop=next(i+1 for i,x in enumerate(ends)if x==end)
 env=dict(os.environ,OMP_NUM_THREADS='1');env.pop('SWAP5_DIAG_PREDECESSOR',None)
 cmd=[str(exe),'input.nml',str(seed)if seed else'-',str(stop),'swap.swp','maize.crp']
 record=dict(scope='STRICT_OWN_BUILD_RESTART'if seed else'ORIGINAL_INPUT_INITIALIZATION',command=cmd,executable_sha256=sha(exe),restart_sha256=sha(seed)if seed else None,inputs=files,diagnostic_override=False,production_admission=False)
 (out/'START.json').write_text(json.dumps(record,indent=2)+'\n');start=time.monotonic();captured=[]
 with (out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
  p=subprocess.Popen(cmd,cwd=out,env=env,stdout=so,stderr=se)
  while p.poll()is None:
   if time.monotonic()-start>7200:p.kill();p.wait();raise TimeoutError(str(out))
   if len(captured)<len(capture):
    try:
     raw=(out/'checkpoint.bin').read_bytes();assert raw[:8]==b'S5HR0004'and zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
     day=struct.unpack_from('=d',raw,8)[0]
     if day in capture and day not in captured:(out/f'checkpoint-{int(day)}.bin').write_bytes(raw);captured.append(day)
    except(OSError,AssertionError,struct.error):pass
   time.sleep(.01)
 record.update(returncode=p.returncode,seconds=time.monotonic()-start,captured=captured)
 (out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');assert p.returncode==0,(out,(out/'stderr').read_text(errors='replace')[-2000:])
 final=(out/'checkpoint.bin').read_bytes();assert profile4(final)['day']==end
 if end in capture and end not in captured:(out/f'checkpoint-{end}.bin').write_bytes(final)
 return out

def restart(exe,case,out):
 seed=case/'checkpoint-583.bin'
 if not seed.exists():
  extra=execute(exe,case,out.parent/'recovered-own583',583);seed=extra/'checkpoint.bin'
  (out.parent/'CAPTURE_RECOVERY.json').write_text(json.dumps(dict(reason='accepted583 poll not observed',actual_own_prefix_reexecuted=True,checkpoint_sha256=sha(seed)))+'\n')
 result=execute(exe,case,out,584,seed=seed);assert (result/'checkpoint.bin').read_bytes()==(case/'checkpoint.bin').read_bytes()
 for name in ('budget.csv','crop.csv'):
  before=list(csv.DictReader((case/name).open()));after=list(csv.DictReader((out/name).open()));assert after
  key=next(iter(after[0]));bytime={r[key]:r for r in before};assert all(r==bytime[r[key]]for r in after),name
 return dict(status='STRICT_OWN583_TO584_ENDPOINT_AND_SUFFIX_EXACT',seed_sha256=sha(seed),endpoint_sha256=sha(out/'checkpoint.bin'))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--baseline',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();compiler=a.compiler.resolve();os.environ.pop('SWAP5_DIAG_PREDECESSOR',None);os.environ['OMP_NUM_THREADS']='1'
 scope=json.loads((ROOT/SCOPE).read_text());current_guard(scope);case_inputs=inputs(out/'inputs')
 baseline_record=json.loads((a.baseline.resolve()/'BUILD.json').read_text());assert '-'+a.optimization in baseline_record['flags']
 plain=out/'build';exe=build(a.baseline.resolve(),plain,compiler);observed_exe=None
 if a.optimization=='O2':observed_exe=build(a.baseline.resolve(),out/'build-observed',compiler,True)
 first=execute(exe,case_inputs,out/'unobserved584',584,capture=(525,583));strict=restart(exe,first,out/'strict584')
 if observed_exe:
  observed=execute(observed_exe,case_inputs,out/'observed584',584,capture=(525,583))
  for name in ('checkpoint.bin','budget.csv','crop.csv','state.csv'):assert (first/name).read_bytes()==(observed/name).read_bytes(),('observer changed physical output',name)
  receipts=list(csv.DictReader((observed/'film_runtime_receipts.csv').open()));last=receipts[-1]
  assert float(last['time_day'])==584 and int(last['calls'])>0 and int(last['max_level'])<=24 and int(last['refinements'])<=23*int(last['calls'])
  assert all(int(b['calls'])>=int(a['calls'])for a,b in zip(receipts,receipts[1:]))
 from production_diagnostic_native import writer_build,measure,app_refusals
 from production_diagnostic_guards import qualify
 probe=writer_build(plain,out/'writer-build',compiler,windows=False);measure(exe,probe,case_inputs,out/'writer-qualification')
 app_refusals(exe,first,out/'app-refusals');qualify(plain,first,first/'checkpoint.bin',out/'owner-controls')
 current_guard(scope)
 (out/'EXECUTED.json').write_text(json.dumps(dict(status='ACTUAL_PRIVATE_DEFAULT584_EXECUTIONS_AND_CONTROLS_COMPLETE_AUDIT_PENDING',optimization=a.optimization,strict_restart=strict,observed_scope='FULL_O2_FROM_INITIALIZATION_EXACT'if observed_exe else'NOT_SELECTED_O0_OBSERVER',production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
 print('ACTUAL_DEFAULT584_EXECUTION_AND_STRICT_OWN_RESTART_CONTROLS_COMPLETE',a.optimization)
if __name__=='__main__':main()
