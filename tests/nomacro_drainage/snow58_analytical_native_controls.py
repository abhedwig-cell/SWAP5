"""Actual compiled original Snow/model7 native startup and 17 malformed domains."""
import argparse,hashlib,json,struct,subprocess,sys,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2];P=R/'integration/f-ci/nomacro-complete01'
p=argparse.ArgumentParser()
for key in ('profile','output'):p.add_argument('--'+key,type=Path,required=True)
a=p.parse_args()
sys.path[:0]=[str(R/'tests/nomacro_scheduled_subsurface'),str(R/'tests/nomacro_drainage'),str(R/'app/hybrid_water')]
import implicit_conductivity_runtime as original
from snow_undrained_state import validate_native
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
profile=a.profile;qprofile=json.loads((profile/'RESULT.json').read_text())
assert qprofile['layer_models'] and len(qprofile['layer_models'])==2 and qprofile['days'] in (2,35) and qprofile['status'].endswith('PASS_NOT_ADMITTED')
build=Path(qprofile['build_root']);meta=json.loads((build/'BUILD.json').read_text());project=original.m.e.load(qprofile['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1');case=Path(project.input_directory);selected=meta['identity']['original_output']
assert selected['analytical_snow_models']==qprofile['layer_models'] and selected['native_codec'].startswith('S5A')
assert SHA((build/'BUILD.json').read_bytes())==qprofile['actual_BUILD_sha256']
for name,digest in meta['inputs'].items():assert original.m.sha(case/name)==digest
for name,digest in meta['identity']['donor_generated'].items():assert original.m.sha(build/name)==digest
for role in ('donor','kernel'):assert original.m.sha(original.m.h.executable(build,'day_'+role))==meta['executable_sha256'][role]
own=profile/'trajectory/accepted-column-1-day-2.zip';ownsha=SHA(own.read_bytes())
with zipfile.ZipFile(own) as z:good=z.read('macro.bin')
archive=P/'EXPLICIT_BOTTOM9_SNOW_WINDOWS_RAW_V1.zip';record=json.loads(archive.with_suffix('.json').read_text());assert SHA(archive.read_bytes())==record['sha256']
with zipfile.ZipFile(archive) as z:
 nested=z.read('profiles/explicit-bottom9-snow-water-O0-v2-model-observe-v2/trajectory/accepted-column-1-day-2.zip')
import io
with zipfile.ZipFile(io.BytesIO(nested)) as z:foreign=z.read('macro.bin')
out=a.output;out.mkdir()
domain=(1,project.nodes,2,int(project.solute),*qprofile['layer_models']);count=len(domain);size=count*4;at=len(good)-96-2*size
assert struct.unpack_from('<'+str(2*count)+'i',good,at)==domain+domain
attacks=[('genuine-model1-native',foreign),('original-model1-codec',b'S5UWI000'+good[8:]),('missing-model-domain',good[:at]+good[at+2*size:]),('truncated',good[:-1]),('trailing',good+b'X')]
for both in (False,True):
 for index in range(count):
  raw=bytearray(good);value=domain[index]+1
  struct.pack_into('<i',raw,at+4*index,value)
  if both:struct.pack_into('<i',raw,at+size+4*index,value)
  attacks.append((('both-' if both else 'header-')+str(index),bytes(raw)))
assert len(attacks)==17
with ExitStack() as stack:
 if (qprofile['layer_models'][0],qprofile['kind'])==(11,'water'):
  archive_name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_NO_VAPOR_PROTOTYPES535_RAW_V1'
  member='actual-current-bridge-O0/trajectory/accepted-column-1-day-2.zip'
 else:
  archive_name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_CURRENT_GUARD_WINDOWS_RAW_V1'
  label='model'+str(qprofile['layer_models'][0])+'-'+qprofile['kind']+'-O0'
  member='profiles/sna-guard-Windows-O0-v1/'+label+'/trajectory/accepted-column-1-day-2.zip'
 store=Archive(P,archive_name,stack)
 original9=store.get(member);foreign9_archive_sha256=store.record['sha256']
with zipfile.ZipFile(io.BytesIO(original9)) as z:foreign9=z.read('macro.bin')
attacks.append(('genuine-same-model-kind-original-bottom9-native',foreign9))
assert len(attacks)==18
q=dict(status='RUNNING',actual_compiler_producer=qprofile['source'],actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),original_checkpoint_sha256=ownsha,original_model1_native_sha256=SHA(foreign),compiled_refusals=[],compiler_executions=0,model_periods=0,accepted_model_days=0,canonical_admission=False,expected_actual_compiled_refusals=len(attacks),genuine_foreign9_checkpoint_sha256=SHA(original9),genuine_foreign9_archive_sha256=foreign9_archive_sha256,genuine_foreign9_archive=archive_name,genuine_foreign9_member=member)
def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
def run(label,raw):
 target=out/label;target.mkdir();origin=target/'origin';receipt=original.m.h.verify_checkpoint(own,2,meta['binding'],origin)
 (origin/'macro.bin').write_bytes(raw)
 directory=target/'original';original.m.h.prepare_column(case,directory,original.m.h.ColumnStart('original',2,origin,receipt),True,True,project)
 r=subprocess.run([str(original.m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,input=b'0 0\n',capture_output=True,timeout=20)
 (target/'donor.stdout').write_bytes(r.stdout);(target/'donor.stderr').write_bytes(r.stderr)
 assert b'HYBRID_DAY_RETURN' not in r.stdout and SHA(own.read_bytes())==ownsha
 return r
save()
try:
 goodrun=run('genuine-own-positive',good);assert goodrun.returncode in (0,100) and not goodrun.stderr and b'HYBRID_READY' in goodrun.stdout
 validate_native(good,selected,project.nodes);q['positive_actual_compiled_ready']=True;save()
 for label,raw in attacks:
  result=run(label,raw);diagnostic=result.stderr.decode('utf8',errors='replace')
  assert result.returncode not in (0,100) and 'ERROR STOP' in diagnostic and b'HYBRID_READY' not in result.stdout,(label,result.returncode,diagnostic)
  try:validate_native(raw,selected,project.nodes)
  except (ValueError,struct.error):pass
  else:raise AssertionError('Typed reader accepted actual malformed domain '+label)
  q['compiled_refusals'].append(dict(attack=label,returncode=result.returncode,diagnostic=diagnostic,actual_raw_sha256=SHA(raw),identical_raw_typed_refusal=True,accepted_model_days=0));save()
 q['status']='ACTUAL_COMPILED_ANALYTICAL_SNOW_MODEL_NATIVE_18_REFUSALS_AND_OWN_POSITIVE_PASS'
finally:save()
print(q['status'],len(q['compiled_refusals']))
