"""Real original microscopic dry lookup with the existing literal qualified completion."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time

ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();out=a.output.resolve();out.mkdir()
 sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
 import user_prepare,micro_lookup_state as correction,implicit_root_finalization
 from daily_host import NO_MACRO_FP_FLAGS,no_macro_fp_profile
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 q=dict(status='RUNNING',optimization=a.optimization,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),floating_point_profile=no_macro_fp_profile(),executions=[])
 def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def run(cmd):return subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=60)
 save()
 try:
  user_prepare.validate(a.reference_work);ref=a.reference_work/'build';objects=ref/'swap-obj';files=sorted(f for f in objects.glob('*.o') if f.name!='swap_main.o')
  fixture=Path(__file__).with_name('implicit_saturation_derivative_inputs.json');inputs=json.loads(fixture.read_text());driver=Path(__file__).with_name('implicit_dry_lookup_driver.f90');numeric=out/'actual-input.dat';numeric.write_text(' '.join(map(repr,inputs['actual_input']))+'\n')
  def symbols(flag):
   result=run(['nm','-g',flag,'--format=posix',*map(str,files)]);result.check_returncode();table={};current=None
   for line in result.stdout.splitlines():
    if line.endswith(':'):current=Path(line[:-1]);table[current]=set();continue
    if current is not None and line.strip():table[current].add(line.split()[0])
   assert set(table)==set(files);return table
  definitions=symbols('--defined-only');undefined=symbols('--undefined-only');lookup={}
  for path,values in definitions.items():
   for symbol in values:lookup.setdefault(symbol,path)
  selected={objects/'RWU_micro.o'}
  while True:
   before=set(selected)
   for path in before:selected.update(lookup[symbol] for symbol in undefined[path] if symbol in lookup)
   if selected==before:break
  original=ref/'swap-selected/RWU_micro.f90';text=original.read_text(encoding='cp1252')
  q.update(original_source_sha256=sha(original),fixture_sha256=sha(fixture),driver_sha256=sha(driver),owner_sha256=sha(Path(correction.__file__)),actual_original_input=inputs,object_count=len(selected),actual_original_object_closure=[dict(name=f.name,sha256=sha(f)) for f in sorted(selected)],closure_reason='Actual original get_MFLP_K initialization/lookup with one verification-only visibility declaration. Existing literal qualified dry-end completion plus final root helper. Actual captured constitutive vector, real original object closure; no copied physical oracle or mock. This verifies composition, not a new physical science qualification.')
  flags=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none','-finit-local-zero',*NO_MACRO_FP_FLAGS,'-I'+str(objects),'-I'+str(ref/'ttutil-obj')]
  for mode,body in [('corrected',implicit_root_finalization.source(correction.render(text)))]:
   anchor='   public :: Tol_2, myTolX, TolConv, factor, alptotal, Ntrial, iMicro, swTypeTred, swDoSatRel';assert body.count(anchor)==1
   body=body.replace(anchor,'   public :: get_MFLP_K\n'+anchor,1)
   path=out/(mode+'.f90');path.write_text(body,encoding='cp1252');obj=out/(mode+'.o');t=time.perf_counter();result=run([*flags,'-c',str(path),'-o',str(obj)]);(out/(mode+'-compile.log')).write_text(result.stdout+result.stderr);result.check_returncode();compile_seconds=time.perf_counter()-t
   exe=out/(mode+('.exe' if os.name=='nt' else ''));t=time.perf_counter();result=run([*flags,str(driver),str(obj),*map(str,sorted(selected-{objects/'RWU_micro.o'})),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)]);(out/(mode+'-link.log')).write_text(result.stdout+result.stderr);result.check_returncode();link_seconds=time.perf_counter()-t
   t=time.perf_counter();result=run([str(exe),str(numeric),mode]);q['executions'].append(dict(mode=mode,actual_source_sha256=sha(path),compile_seconds=compile_seconds,link_seconds=link_seconds,native_seconds=time.perf_counter()-t,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr));save();result.check_returncode()
   assert 'REAL_ORIGINAL_NONHISTORY_COMPLETE_DRY_ENDPOINT_FIVE_INPUTS_PASS' in result.stdout
  q['status']='REAL_ORIGINAL_NONHISTORY_COMPLETE_DRY_ENDPOINT_FIVE_INPUTS_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
