"""Compile current actual RIA12 source, read genuine prior native, test zero-day controls."""
import argparse,json,re,struct,subprocess,sys,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2];sys.path[:0]=[str(R/'tests/nomacro_scheduled_subsurface'),str(R/'tests/nomacro_drainage'),str(R/'app/hybrid_water')]
import implicit_conductivity_runtime as original
from analytical_hydraulic_archives import SHA
p=argparse.ArgumentParser()
for key in ('profile','reference-work','model1-origin','legacy-ria-origin','other-kind-origin','foreign-context-origin','primary-origin','reference-samples','output'):p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--build-root',type=Path)
a=p.parse_args()
from ria12_thermal_source import complete_inverse
complete_inverse()
git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
head=git('rev-parse','HEAD').decode().strip()
profile=a.profile;q=json.loads((profile/'RESULT.json').read_text())
assert q['status']=='ACTUAL_RIA12_THERMAL_FULL35_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' or (q['status']=='FAILED_RIA12_THERMAL_FULL35_NOT_QUALIFIED' and q.get('error')=="AssertionError('No meaningful active bottom exchange')" and q['source']=='978c7e7d6048141db84d50e250142a4ee101d6d2')
bundle=Path(q['build_root']);reference=a.reference_work
oldmeta=meta=json.loads((bundle/'BUILD.json').read_text())
assert SHA((bundle/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
project=original.m.e.load(q['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
oldbundle=bundle
postimage=None
if a.build_root:
 bundle=a.build_root/'bundle'
 command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',q['input_root'],'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(reference),'--build-only','--donor-opt',q['optimization'],'--kernel-opt',q['optimization'],'--output',str(bundle)]
 a.output.mkdir()
 with (a.output/'build.stdout').open('xb') as out,(a.output/'build.stderr').open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
 r.check_returncode()
 meta=json.loads((bundle/'BUILD.json').read_text())
 from snow58_compiled_postimage import compare
 postimage=compare(oldbundle,bundle)
 assert meta['inputs']==oldmeta['inputs']
original.m.validate_bundle(bundle,reference,project)
codec=meta['identity']['original_output']['native_codec'].encode()
assert meta['identity']['original_output']['native_codec']==codec.decode()
a.output.mkdir(exist_ok=True)
own=profile/'trajectory/accepted-column-1-day-2.zip';ownsha=SHA(own.read_bytes())
with zipfile.ZipFile(own) as z:good=z.read('macro.bin')
with zipfile.ZipFile(a.model1_origin) as z:model1=z.read('macro.bin')
with zipfile.ZipFile(a.legacy_ria_origin) as z:legacy=z.read('macro.bin')
with zipfile.ZipFile(a.other_kind_origin) as z:other=z.read('macro.bin')
with zipfile.ZipFile(a.foreign_context_origin) as z:foreign=z.read('macro.bin')
with zipfile.ZipFile(a.primary_origin) as z:primary=z.read('macro.bin')
expected=(1,project.nodes,2,int(q['kind']=='cde'),6,1,1,2,q['snow'],16,12,12);footer=8*len(expected);parameter_size=11*2*16;at=len(good)-footer-2*parameter_size;parameters=good[at:at+parameter_size]
from ria12_thermal_native import native
row=original.m.rows(profile/'trajectory')[1]
original_parameters=(a.reference_samples/'original-parameters.bin').read_bytes()
def typed(raw):
 native(raw,row,meta,original_parameters)
 assert raw[:8]==codec and len(raw)==len(good)
 assert struct.unpack_from('<i',raw,8)[0]==project.nodes
 assert struct.unpack_from('<'+str(2*len(expected))+'i',raw,len(raw)-footer)==expected+expected
 actual=raw[at:at+parameter_size];assert actual==raw[at+parameter_size:at+2*parameter_size]==parameters
 assert all((int.from_bytes(actual[i:i+16],'little')>>112)&32767!=32767 for i in range(0,parameter_size,16))
typed(good);attacks=[('genuine-other-Snow-context-ria12-native',foreign),('genuine-primary-ria12-native',primary),('genuine-other-kind-ria12-native',other),('genuine-model1-native',model1),('genuine-legacy-ria12-native',legacy),('legacy-ria12-forged-new-codec',good[:8]+legacy[8:]),('legacy-codec-new-body',legacy[:8]+good[8:]),('missing-ria12-domain',good[:at]),('truncated',good[:-1]),('trailing',good+b'X')]
for both in (False,True):
 for index,value in enumerate(expected):
  raw=bytearray(good);struct.pack_into('<i',raw,len(raw)-footer+4*index,value+1)
  if both:struct.pack_into('<i',raw,len(raw)-footer+4*len(expected)+4*index,value+1)
  attacks.append((('both-' if both else 'header-')+str(index),bytes(raw)))
for index in (0,3,8,19):
 for both in (False,True):
  raw=bytearray(good);raw[at+16*index]^=1
  if both:raw[at+parameter_size+16*index]^=1
  attacks.append((f'parameter-{index}-'+('both' if both else 'header'),bytes(raw)))
raw=bytearray(good);nan=(1|32767<<112).to_bytes(16,'little');raw[at:at+16]=nan;raw[at+parameter_size:at+parameter_size+16]=nan;attacks.append(('nonfinite-parameter-both',bytes(raw)))
if q['snow']:
 layout=native(good,row,meta,original_parameters)
 for label,offset,value in [('thermal-heacon-nan',layout['thermal_history_offset'],float('nan')),('thermal-heacap-negative',layout['thermal_history_offset']+8*project.nodes,-1.),('thermal-boundary-nan',layout['thermal_history_offset']+16*project.nodes,float('nan')),('top-negative-conductivity',layout['top_offset']+12+24,-1.),('top-clock',layout['top_offset']+4,0.),('micro-clock',layout['microscopic_offset']+32,0.)]:
  raw=bytearray(good);struct.pack_into('<d',raw,offset,value);attacks.append((label,bytes(raw)))
record=dict(status='RUNNING',actual_observer_source=head,actual_compiler_source=head if a.build_root else q.get('actual_compiler_source',q['source']),actual_compiled_postimage=postimage,genuine_checkpoint_producer=q['source'],genuine_checkpoint_sha256=ownsha,actual_BUILD_sha256=SHA((bundle/'BUILD.json').read_bytes()),actual_current_build_root=str(bundle),kind=q['kind'],optimization=q['optimization'],compiled_refusals=[],private_input_refusals=[],compiler_executions=int(a.build_root is not None),model_periods=0,accepted_model_days=0,original_checkpoint_metadata_or_binding_rewritten=False,canonical_admission=False)
def save():(a.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
def run(label,raw,change=None):
 root=a.output/label;root.mkdir();origin=root/'origin';receipt=original.m.h.verify_checkpoint(own,2,oldmeta['binding'],origin);(origin/'macro.bin').write_bytes(raw);directory=root/'original';original.m.h.prepare_column(Path(q['input_root']),directory,original.m.h.ColumnStart('original',2,origin,receipt),True,True,project)
 if change:
  path=directory/'swap.swp';before=path.read_bytes();key,value=change;after,count=re.subn(rb'(?mi)^([ \t]*'+key.encode()+rb'[ \t]*=[ \t]*)[^!\r\n]*',lambda m:m[1]+value.encode(),before);assert count==1;path.write_bytes(after)
 result=subprocess.run([str(original.m.h.executable(bundle,'day_donor')),'./swap.swp'],cwd=directory,input=b'0 0\n',capture_output=True,timeout=20);(root/'donor.stdout').write_bytes(result.stdout);(root/'donor.stderr').write_bytes(result.stderr);assert b'HYBRID_DAY_RETURN' not in result.stdout and SHA(own.read_bytes())==ownsha;return result
save()
try:
 r=run('genuine-own-native-positive',good);assert r.returncode in (0,100) and b'HYBRID_READY' in r.stdout and not r.stderr;record['own_positive_ready']=True;save()
 for label,raw in attacks:
  r=run(label,raw);assert r.returncode not in (0,100) and b'HYBRID_READY' not in r.stdout and b'ERROR STOP' in r.stderr,(label,r.returncode,r.stderr)
  try:typed(raw)
  except (AssertionError,ValueError,struct.error):pass
  else:raise AssertionError('Typed domain reader accepted malformed native '+label)
  record['compiled_refusals'].append(dict(attack=label,actual_raw_sha256=SHA(raw),returncode=r.returncode,diagnostic=r.stderr.decode('utf8',errors='replace'),identical_raw_typed_domain_refusal=True));save()
 for label,change in [('private-HeatOn',('HeatOn','.TRUE.')),('private-VaporCond',('VaporCond','.TRUE.')),('private-constitutive-ksat',('RIA_UHCC_ksat','11.0 5.0'))]:
  r=run(label,good,change);assert r.returncode not in (0,100) and b'HYBRID_READY' not in r.stdout and b'ERROR STOP' in r.stderr,(label,r.returncode,r.stderr);record['private_input_refusals'].append(dict(attack=label,actual_untouched_native_sha256=SHA(good),returncode=r.returncode,diagnostic=r.stderr.decode('utf8',errors='replace')));save()
 assert git('rev-parse','HEAD').decode().strip()==head;record['status']='ACTUAL_RIA12_CURRENT_COMPILED_MODEL_PARAMETER_NATIVE_REFUSALS_AND_OWN_POSITIVE_PASS_NO_MODEL_DAYS'
finally:save()
print(record['status'],q['kind'],q['optimization'],len(attacks),len(record['private_input_refusals']))
