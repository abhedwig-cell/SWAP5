"""Real original microscopic API with exported actual initialized input carry."""
from pathlib import Path
import argparse,base64,hashlib,json,os,subprocess,sys,time

ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();out=a.output.resolve();out.mkdir()
 sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
 import user_prepare,micro_lookup_state,implicit_root_finalization as correction
 from daily_host import NO_MACRO_FP_FLAGS,no_macro_fp_profile
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 q=dict(status='RUNNING',optimization=a.optimization,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),floating_point_profile=no_macro_fp_profile(),executions=[])
 def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 def run(cmd):return subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=60)
 save()
 try:
  user_prepare.validate(a.reference_work);ref=a.reference_work/'build';objects=ref/'swap-obj';files=sorted(f for f in objects.glob('*.o') if f.name!='swap_main.o')
  fixture=Path(__file__).with_name('implicit_root_finalization_inputs.json');driver=Path(__file__).with_name('implicit_root_finalization_driver.f90');inputs=json.loads(fixture.read_text(encoding='utf8'));data=inputs['fields']
  crop=out/'grass.crp';crop.write_bytes(base64.b64decode(inputs['actual_crop_raw_base64'],validate=True));assert sha(crop)==inputs['actual_crop_sha256']
  numeric=out/'actual-input.dat';lines=[]
  for tag in ('META','LAYER','FIRST','DZ','COFGEN','INDEX','FHYST','LRV','ALPTOT','H','M','K'):
   values=data[tag]
   if tag in ('LAYER','FIRST','INDEX'):line=' '.join(str(int(v)) for v in values)
   elif tag=='META':line=' '.join(str(int(v)) if i in (0,1,2,4,5,6,7) else repr(v) for i,v in enumerate(values))
   else:line=' '.join(map(repr,values))
   lines.append(line)
  numeric.write_text('\n'.join(lines)+'\n',encoding='ascii')
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
  original=ref/'swap-selected/RWU_micro.f90';baseline=micro_lookup_state.render(original.read_text(encoding='cp1252'))
  actual=Path(inputs['raw_original_stdout']).parents[2]/'build/RWU_micro.f90'
  if actual.exists():assert actual.read_text(encoding='cp1252')==baseline and sha(actual)==inputs['actual_generated_micro_sha256']
  q.update(original_source_sha256=sha(original),fixture_sha256=sha(fixture),crop_sha256=sha(crop),driver_sha256=sha(driver),numerical_owner_sha256=sha(Path(correction.__file__)),original_lookup_owner_sha256=sha(Path(micro_lookup_state.__file__)),original_input_provenance=inputs|{'fields':{'actual_clock':data['META'][-1]}},object_count=len(selected),actual_original_object_closure=[dict(name=f.name,sha256=sha(f)) for f in sorted(selected)],closure_reason='Actual original public do_RWU_micro initialization and rate calls, original reader and original constitutive/table providers; restore exported initialized carry as explicit API input. No mock or copied physical equation.')
  flags=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none','-finit-local-zero',*NO_MACRO_FP_FLAGS,'-I'+str(objects),'-I'+str(ref/'ttutil-obj')]
  for mode,source in [('original',baseline),('corrected',correction.source(baseline))]:
   source_path=out/(mode+'.f90');source_path.write_text(source,encoding='cp1252');obj=out/(mode+'.o');t=time.perf_counter();result=run([*flags,'-c',str(source_path),'-o',str(obj)]);(out/(mode+'-compile.log')).write_text(result.stdout+result.stderr,encoding='utf8');result.check_returncode();compile_seconds=time.perf_counter()-t
   exe=out/(mode+('.exe' if os.name=='nt' else ''));t=time.perf_counter();result=run([*flags,str(driver),str(obj),*map(str,sorted(selected-{objects/'RWU_micro.o'})),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)]);(out/(mode+'-link.log')).write_text(result.stdout+result.stderr,encoding='utf8');result.check_returncode();link_seconds=time.perf_counter()-t
   t=time.perf_counter();result=run([str(exe),str(numeric),mode]);q['executions'].append(dict(mode=mode,actual_source_sha256=sha(source_path),compile_seconds=compile_seconds,link_seconds=link_seconds,native_seconds=time.perf_counter()-t,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr));save();result.check_returncode()
   assert ('REAL_ORIGINAL_MICRO_DISCONTINUITY_REPRODUCED' if mode=='original' else 'REAL_ORIGINAL_MICRO_FINALIZATION_PASS') in result.stdout
  q['status']='REAL_ORIGINAL_MICRO_DISCONTINUITY_AND_CORRECTED_FINALIZATION_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
