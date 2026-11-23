"""One bounded water/CDE Snow9 coupling batch; no inherited model replays."""
import argparse,json,subprocess,sys
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_snow_source_inverse import complete_inverse,git
INPUT='EXPLICIT_BOTTOM9_SNOW_INPUTS_V1'
INPUT_SHA='cb78947e988ddfc8fc8e5000cc54438912d00bc55588ea5f5683fcd24706a1b1'


def main():
 p=argparse.ArgumentParser()
 for name in ('reference-work','proof','build-root'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();complete_inverse();a.proof.mkdir(parents=True,exist_ok=True);head=git('rev-parse','HEAD').decode().strip()
 folder=ROOT/'integration/f-ci/nomacro-complete01'
 with ExitStack() as stack:
  store=Archive(folder,INPUT,stack);assert store.record['sha256']==INPUT_SHA and len(store.names)==42
  for name in store.names:
   raw=store.get(name)
   if not any(name.startswith(role+'/') for role in store.record['roles']):continue
   path=a.proof/'inputs'/name;assert path.resolve().is_relative_to((a.proof/'inputs').resolve());path.parent.mkdir(parents=True,exist_ok=True)
   with path.open('xb') as f:f.write(raw)
 for suffix in ('.zip','.json'):(a.proof/(INPUT+suffix)).write_bytes((folder/(INPUT+suffix)).read_bytes())
 q=dict(status='RUNNING',source=head,optimization=a.optimization,input_archive_sha256=INPUT_SHA,contexts=[],inherited_model_periods_replayed=False,canonical_admission=False)
 def save():(a.proof/('SNOW-'+a.optimization+'-BATCH.json')).write_text(json.dumps(q,indent=2)+'\n')
 def run(args,label):
  assert git('rev-parse','HEAD').decode().strip()==head
  with (a.proof/(label+'.stdout.txt')).open('x') as out,(a.proof/(label+'.stderr.txt')).open('x') as err:done=subprocess.run([sys.executable,'-B',*map(str,args)],cwd=ROOT,stdout=out,stderr=err,timeout=1200)
  assert done.returncode==0,dict(label=label,returncode=done.returncode)
 save()
 try:
  for kind in ('water','cde'):
   label='snow9-'+kind+'-'+a.optimization;profile=a.proof/label;post=a.proof/(label+'-initial2-postimage');science=a.proof/(label+'-INDEPENDENT.json');q['active']=kind;save()
   run(['tests/nomacro_drainage/explicit_bottom9_snow_runtime.py','--input',a.proof/'inputs'/(kind+'-initial1'),'--reference-work',a.reference_work,'--build-root',a.build_root/label,'--output',profile,'--optimization',a.optimization],label+'-runtime')
   run(['tests/nomacro_drainage/explicit_bottom9_snow_postimage.py','--profile',profile,'--input',a.proof/'inputs'/(kind+'-initial2'),'--reference-work',a.reference_work,'--build-root',a.build_root/(label+'-initial2-postimage'),'--output',post],label+'-counter')
   run(['tests/nomacro_drainage/explicit_bottom9_snow_science.py','--profile',profile,'--output',science],label+'-reader')
   value=json.loads(science.read_text());q['contexts'].append(dict(kind=kind,optimization=a.optimization,profile=str(profile),postimage=str(post),independent=str(science),independent_sha256=SHA(science.read_bytes()),status=value['status']));save();print('ACTUAL_ACTIVE_SNOW9_MELT_NATIVE_COLD_WHOLE_COMPILED_PASS',kind,a.optimization,flush=True)
  q.update(status='BOTH_WATER_CDE_ACTIVE_SNOW9_ORIGINAL_LEDGER_NATIVE_COLD_COMPILED_PASS_NOT_ADMITTED',native_checkpoints=14,exact_cold_windows=6,actual_initial2_compiled_counterparts=2);q.pop('active',None);save()
 except Exception as error:q.update(status='FAILED',error=repr(error));save();raise
 print(q['status'],a.optimization,flush=True)


if __name__=='__main__':main()
