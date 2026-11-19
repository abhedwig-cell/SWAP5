"""Small real original conductivity/derivative API and measured original closure."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time

ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();ref=a.reference_work/'build';objects=ref/'swap-obj';q=dict(status='RUNNING',optimization=a.optimization)
 def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
 def run(cmd):return subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=60)
 try:
  sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
  import user_prepare
  user_prepare.validate(a.reference_work)
  files=sorted(p for p in objects.glob('*.o') if p.name!='swap_main.o');assert files
  def symbols(flag):
   result=run(['nm','-g',flag,'--format=posix',*map(str,files)]);result.check_returncode();table={};current=None
   for line in result.stdout.splitlines():
    if line.endswith(':'):current=Path(line[:-1]);table[current]=set();continue
    if current is not None and line.strip():table[current].add(line.split()[0])
   assert set(table)==set(files);return table
  definitions=symbols('--defined-only');undefined=symbols('--undefined-only');lookup={}
  for path,values in definitions.items():
   for symbol in values:lookup.setdefault(symbol,path)
  selected={objects/'MOD_MvG_functions.o'}
  while True:
   previous=set(selected)
   for path in previous:
    selected.update(lookup[symbol] for symbol in undefined[path] if symbol in lookup)
   if selected==previous:break
  source=ref/'swap-selected/MOD_MvG_functions.f90';driver=Path(__file__).with_name('implicit_conductivity_derivative_driver.f90');q.update(actual_original_source_sha256=sha(source),driver_sha256=sha(driver),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),actual_real_original_object_closure=[dict(name=f.name,sha256=sha(f)) for f in sorted(selected)],object_count=len(selected),no_mock_or_copied_physical_equation=True,closure_reason='The real original MOD_MvG public derivative shares initialized original module state and diagnostic/PDI dependencies. Resolve actual original object symbols; no stand-in modules or copied formulas.')
  flags=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none','-I'+str(objects),'-I'+str(ref/'ttutil-obj')]
  t=time.perf_counter();compiled=run([*flags,'-c',str(source),'-o',str(out/'original_mvg.o')]);(out/'compile-original.log').write_text(compiled.stdout+compiled.stderr,encoding='utf8');compiled.check_returncode();q['compile_original_seconds']=time.perf_counter()-t
  exe=out/('derivative.exe' if os.name=='nt' else 'derivative');t=time.perf_counter();linked=run([*flags,str(driver),str(out/'original_mvg.o'),*map(str,sorted(selected-{objects/'MOD_MvG_functions.o'})),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)]);(out/'compile-link.log').write_text(linked.stdout+linked.stderr,encoding='utf8');linked.check_returncode();q['compile_link_driver_seconds']=time.perf_counter()-t
  t=time.perf_counter();result=run([str(exe)]);q.update(native_seconds=time.perf_counter()-t,stdout=result.stdout,stderr=result.stderr);result.check_returncode();assert 'REAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_DERIVATIVE_PASS' in result.stdout
  q['status']='REAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_DERIVATIVE_INTERFACE_PASS';print(json.dumps(q),flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')


if __name__=='__main__':main()
