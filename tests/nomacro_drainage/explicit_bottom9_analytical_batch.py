"""Target representative unchanged analytical process composition on one platform."""
import argparse,hashlib,json,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_analytical_source_inverse import complete_inverse,git
from original_output_baseline import assignment
from analytical_hydraulic_archives import SHA
INPUT_ARCHIVE='EXPLICIT_BOTTOM9_ANALYTICAL_INPUTS_V1'
INPUT_SHA='1fdc2776c7f729c2f0355f047a8a20fb8599fa3b63a92bdd7385c41133f60440'

def prepare(proof):
 folder=ROOT/'integration/f-ci/nomacro-complete01';raw=(folder/(INPUT_ARCHIVE+'.zip')).read_bytes();record=json.loads((folder/(INPUT_ARCHIVE+'.json')).read_text())
 assert len(raw)==record['bytes'] and SHA(raw)==record['sha256']==INPUT_SHA and len(record['members'])==60
 # Preserve exact admitted input bytes in the original CI artifact as well.
 (proof/(INPUT_ARCHIVE+'.zip')).write_bytes(raw);(proof/(INPUT_ARCHIVE+'.json')).write_bytes((folder/(INPUT_ARCHIVE+'.json')).read_bytes())
 with zipfile.ZipFile(folder/(INPUT_ARCHIVE+'.zip')) as archive:
  assert len(archive.namelist())==len(set(archive.namelist()))==60 and set(archive.namelist())==set(record['members'])
  for name,item in record['members'].items():
   path=proof/'inputs'/name;assert path.resolve().is_relative_to((proof/'inputs').resolve());value=archive.read(name);assert len(value)==item['bytes'] and SHA(value)==item['sha256'];path.parent.mkdir(parents=True,exist_ok=True)
   with path.open('xb') as out:out.write(value)
 for model in (3,7,11):
  for kind in ('water','cde'):
   first=proof/'inputs'/('model'+str(model)+'-'+kind+'-initial1');second=first.with_name(first.name.replace('initial1','initial2'));second.mkdir()
   for path in first.iterdir():
    assert path.is_file();value=path.read_bytes()
    if path.name=='swap.swp':value=assignment(value.decode('cp1252'),'SWINCO',2).encode('cp1252')
    with (second/path.name).open('xb') as out:out.write(value)
 return record

def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','proof','build-root'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();complete_inverse();a.proof.mkdir(parents=True,exist_ok=True);head=git('rev-parse','HEAD').decode().strip();record=prepare(a.proof)
 q=dict(status='RUNNING',source=head,optimization=a.optimization,input_archive_sha256=INPUT_SHA,contexts=[],canonical_admission=False)
 output=a.proof/('ANALYTICAL-'+a.optimization+'-BATCH.json')
 def save():output.write_text(json.dumps(q,indent=2)+'\n')
 def run(args,label):
  assert git('rev-parse','HEAD').decode().strip()==head
  with (a.proof/(label+'.stdout.txt')).open('x') as stdout,(a.proof/(label+'.stderr.txt')).open('x') as stderr:
   result=subprocess.run([sys.executable,'-B',*map(str,args)],cwd=ROOT,stdout=stdout,stderr=stderr,timeout=1200)
  assert result.returncode==0,dict(label=label,returncode=result.returncode)
 component=None
 save()
 try:
  for model in (3,7,11):
   for kind in ('water','cde'):
    case='model'+str(model)+'-'+kind+'-nonlinear-steady';label='analytical-'+case+'-'+a.optimization;profile=a.proof/label;post=a.proof/(label+'-initial2-postimage');inputs=a.proof/'inputs'/('model'+str(model)+'-'+kind+'-initial1');counter_inputs=inputs.with_name(inputs.name.replace('initial1','initial2'));science=a.proof/(label+'-INDEPENDENT.json')
    q['active']=dict(model=model,kind=kind,profile=str(profile));save()
    run(['tests/nomacro_drainage/explicit_bottom9_analytical_runtime.py','--input',inputs,'--reference-work',a.reference_work,'--build-root',a.build_root/label,'--output',profile,'--case',case,'--optimization',a.optimization],label+'-runtime')
    run(['tests/nomacro_drainage/explicit_bottom9_analytical_postimage.py','--profile',profile,'--input',counter_inputs,'--reference-work',a.reference_work,'--build-root',a.build_root/(label+'-initial2-postimage'),'--output',post],label+'-counter')
    sample=a.proof/(label+'-original-samples');component_args=['--reuse-component',component] if component else ['--build-root',a.build_root/('original-sampled-component-'+a.optimization)]
    run(['tests/nomacro_drainage/explicit_bottom9_analytical_reference_samples.py','--profile',profile,'--reference-work',a.reference_work,'--output',sample,*component_args],label+'-original-samples')
    if component is None:component=sample
    run(['tests/nomacro_drainage/explicit_bottom9_analytical_science.py','--profile',profile,'--postimage',post,'--reference-work',a.reference_work,'--output',science,'--reference-samples',sample],label+'-reader')
    result=json.loads(science.read_text());q['contexts'].append(dict(model=model,kind=kind,optimization=a.optimization,profile=str(profile),postimage=str(post),independent=str(science),independent_sha256=SHA(science.read_bytes()),original_samples=str(sample),status=result['status']));save();print('TARGETED_NONLINEAR_ORIGINAL_POINT_NATIVE_COLD_COMPILED_PASS',model,kind,a.optimization,flush=True)
  q.update(status='ALL6_REPRESENTATIVE_NONLINEAR_CONTEXTS_INDEPENDENT_PASS_NOT_ADMITTED',native_checkpoints=42,exact_cold_windows=18,actual_initial2_compiled_counterparts=6);q.pop('active',None);save()
 except Exception as error:q.update(status='FAILED',error=repr(error));save();raise
 print(q['status'],a.optimization,flush=True)

if __name__=='__main__':main()
