"""Small real original TimeControl(5), with measured actual object closure."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time

ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();q=dict(status='RUNNING',optimization=a.optimization)
 def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
 def run(cmd):return subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=60)
 try:
  sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
  import user_prepare,implicit_conductivity_retry as retry
  from daily_host import NO_MACRO_FP_FLAGS,no_macro_fp_profile
  user_prepare.validate(a.reference_work);ref=a.reference_work/'build';objects=ref/'swap-obj';files=sorted(f for f in objects.glob('*.o') if f.name!='swap_main.o')
  def symbols(flag):
   r=run(['nm','-g',flag,'--format=posix',*map(str,files)]);r.check_returncode();table={};current=None
   for line in r.stdout.splitlines():
    if line.endswith(':'):current=Path(line[:-1]);table[current]=set();continue
    if current is not None and line.strip():table[current].add(line.split()[0])
   assert set(table)==set(files);return table
  definitions=symbols('--defined-only');undefined=symbols('--undefined-only');lookup={}
  for path,values in definitions.items():
   for symbol in values:lookup.setdefault(symbol,path)
  selected={objects/'timecontrol.o'}
  while True:
   before=set(selected)
   for path in before:selected.update(lookup[symbol] for symbol in undefined[path] if symbol in lookup)
   if before==selected:break
  original=ref/'swap-selected/timecontrol.f90';source=out/'actual_original_retry_timecontrol.f90';source.write_text(retry.time_source(original.read_text(encoding='cp1252')),encoding='cp1252');driver=Path(__file__).with_name('implicit_conductivity_retry_driver.f90')
  q.update(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),numerical_owner_sha256=sha(Path(retry.__file__)),original_timecontrol_sha256=sha(original),actual_generated_source_sha256=sha(source),driver_sha256=sha(driver),floating_point_profile=no_macro_fp_profile(),actual_real_original_object_closure=[dict(name=f.name,sha256=sha(f)) for f in sorted(selected)],object_count=len(selected),closure_reason='Original public TimeControl shares original timer, irrigation, meteo and diagnostic modules. Resolve and link actual original providers; no stand-ins or copied physical equations.')
  flags=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none',*NO_MACRO_FP_FLAGS,'-I'+str(objects),'-I'+str(ref/'ttutil-obj')]
  t=time.perf_counter();r=run([*flags,'-c',str(source),'-o',str(out/'retry.o')]);(out/'compile-original.log').write_text(r.stdout+r.stderr,encoding='utf8');r.check_returncode();q['compile_original_seconds']=time.perf_counter()-t
  exe=out/('retry.exe' if os.name=='nt' else 'retry');t=time.perf_counter();r=run([*flags,str(driver),str(out/'retry.o'),*map(str,sorted(selected-{objects/'timecontrol.o'})),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)]);(out/'compile-link.log').write_text(r.stdout+r.stderr,encoding='utf8');r.check_returncode();q['compile_link_seconds']=time.perf_counter()-t
  t=time.perf_counter();r=run([str(exe)]);r.check_returncode();assert 'REAL_ORIGINAL_IMPLICIT_RETRY_PASS 5' in r.stdout;q.update(native_seconds=time.perf_counter()-t,stdout=r.stdout,stderr=r.stderr,refusals=[])
  for mode,expected in [('clock-stop','Implicit original retry reached clock resolution'),('nan-stop','Invalid implicit original trial clock'),('zero-stop','Invalid implicit original trial clock')]:
   t=time.perf_counter();r=run([str(exe),mode]);assert r.returncode!=0 and expected in r.stderr,(mode,r.returncode,r.stderr)
   q['refusals'].append(dict(mode=mode,returncode=r.returncode,seconds=time.perf_counter()-t,stdout=r.stdout,stderr=r.stderr))
  q['status']='REAL_ORIGINAL_IMPLICIT_RETRY_FIVE_CONTRACTS_THREE_REFUSALS_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')


if __name__=='__main__':main()
