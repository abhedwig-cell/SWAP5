"""Target only the sixteen existing-process paired9/history contexts."""
import argparse,hashlib,json,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_history_science import audit
from explicit_bottom9_history_source_inverse import complete_inverse
from analytical_hydraulic_archives import SHA


def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=('O0','O2'),required=True)
 for key in ('proof','build-root','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();complete_inverse();proof=ROOT/'integration/f-ci/nomacro-complete01';manifest=json.loads((proof/'EXPLICIT_BOTTOM9_HISTORY_INPUTS_RAW_V2.json').read_text());archive=proof/manifest['archive'];raw=archive.read_bytes();assert len(raw)==manifest['bytes'] and SHA(raw)==manifest['sha256'];inputs=a.proof/'inputs';inputs.mkdir()
 with zipfile.ZipFile(archive) as z:
  assert set(z.namelist())==set(manifest['members'])
  for name in z.namelist():
   data=z.read(name);item=manifest['members'][name];assert len(data)==item['bytes'] and SHA(data)==item['sha256']
   target=inputs/name;assert target.resolve().is_relative_to(inputs.resolve());target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
 actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();q=dict(status='RUNNING',actual_source=actual,optimization=a.optimization,profiles=[],canonical_admission=False,model_periods_repeated=0)
 def save():(a.proof/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def run(name,script,args,timeout):
  target=a.proof/'logs';target.mkdir(exist_ok=True);command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage'/script),*map(str,args)]
  with (target/(name+'.stdout')).open('x') as out,(target/(name+'.stderr')).open('x') as err:r=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=timeout)
  assert r.returncode==0,(name,r.returncode)
 save()
 try:
  for drainage in (0,1):
   for kind in ('water','cde'):
    for mode in (1,2):
     name='history9-'+kind+'-hys'+str(mode)+'-dra'+str(drainage)+'-'+a.optimization;prefix='drainage' if drainage else 'undrained';primary_initial=2 if drainage and kind=='cde' else 1;primary_input=inputs/prefix/(kind+'-hys'+str(mode)+'-initial'+str(primary_initial));counterpart_input=primary_input.with_name(kind+'-hys'+str(mode)+'-initial'+str(3-primary_initial));profile=a.proof/'profiles'/name;profile.parent.mkdir(exist_ok=True)
     run(name,'explicit_bottom9_history_runtime.py',['--input',primary_input,'--reference-work',a.reference_work,'--build-root',a.build_root/name,'--output',profile,'--optimization',a.optimization],1200)
     science=a.proof/'science';science.mkdir(exist_ok=True);result=audit(profile,a.reference_work);(science/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n')
     native=a.proof/'native-controls'/name;native.parent.mkdir(exist_ok=True);run(name+'-native','explicit_bottom9_history_native_controls.py',['--profile',profile,'--output',native],300)
     counter=a.proof/'postimages'/name;counter.parent.mkdir(exist_ok=True);run(name+'-counterpart','explicit_bottom9_history_postimage.py',['--profile',profile,'--input',counterpart_input,'--reference-work',a.reference_work,'--build-root',a.build_root/(name+'-counterpart'),'--output',counter],600)
     q['profiles'].append(dict(kind=kind,hysteresis=mode,drainage=drainage,optimization=a.optimization,primary_initial=primary_initial,counterpart_initial=3-primary_initial,profile=profile.relative_to(a.proof).as_posix(),science='science/'+name+'.json',native_controls=native.relative_to(a.proof).as_posix(),initialization_postimage=counter.relative_to(a.proof).as_posix(),primary_input=primary_input.relative_to(a.proof).as_posix(),counterpart_input=counterpart_input.relative_to(a.proof).as_posix()));save();print(name,'ORIGINAL_LEDGER_SCANNING_NATIVE7_COLD3_BINARY_INITIALIZATION_COUNTERPART_AND_NATIVE28_PASS',flush=True)
  assert len(q['profiles'])==8
  q.update(status='ALL8_OPT_CONTEXTS_ORIGINAL_HISTORY9_LEDGER_NATIVE_COLD_COMPILED_AND224_NATIVE_REFUSALS_PASS_NOT_ADMITTED',contexts=8,native_checkpoints=56,exact_cold_windows=24,compiled_initialization_counterparts=8,native_refusals=224,identical_payload_independent_refusals=224);save()
 except Exception as error:q.update(status='FAILED',error=repr(error));save();raise


if __name__=='__main__':main()
