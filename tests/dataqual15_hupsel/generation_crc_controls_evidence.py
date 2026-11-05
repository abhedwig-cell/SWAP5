"""Independent replay of actual public reader controls, bound to full native binaries."""
import argparse,hashlib,json,struct,zipfile,zlib
from pathlib import Path
import generation_crc_posix_evidence as original
ROOT=original.ROOT;BASE=original.BASE
DIGEST='4677fa75bd37fbac52d6804431c8fdc4a6d1ea81017677b1c052620451e6f2ac'
sha=original.sha

def unpack():
 p=BASE/'GENERATION_CRC_NATIVE_CONTROLS_20261105.zip';assert sha(p.read_bytes())==DIGEST
 with zipfile.ZipFile(p)as z:
  assert len(z.namelist())==len(set(z.namelist()));assert all(not Path(n).is_absolute()and'..'not in Path(n).parts for n in z.namelist());return {n:z.read(n)for n in z.namelist()if not n.endswith('/')}
def verify(files,extra):
 record=json.loads((BASE/'GENERATION_CRC_POSIX_20261105.json').read_text());r=json.loads(extra['RESULT.json']);events=json.loads(extra['EVENTS.json'])
 assert r['status']=='ACTUAL_PUBLIC_GENERATION_32_NATIVE_CONTROLS_PASS'and r['original_artifact_sha256']==record['artifact_zip_sha256']
 assert r['events']==events and len(events)==32 and len(r['rows'])==8
 assert r['production_admission']is False and r['whole_scientific_admission']is False
 root=events[0]['command'][0].rsplit('/',2)[0]
 names=set()
 for row in r['rows']:
  role=row['role'];opt=row['optimization'];family=row['family'];assert role in ('incumbent','candidate')and opt in ('O0','O2')and family in ('joint','saved')
  case=role+'-'+opt+'-'+family;assert case not in names;names.add(case)
  assert all(row[k]is True for k in ('proper_valid_resealed','zero_footer_refused','resealed_outer_bad_inner_refused','live_authority_unchanged'))
  exe_key=role+'/'+family+'/'+opt+'/'+('joint-output'if family=='joint'else'saved');assert row['executable_key']==exe_key and sha(files[exe_key])==sha(extra[case+'/decoder'])==row['executable_sha256']
  good_key=role+'/joint/'+opt+'/model.restart.generation'if family=='joint'else original.prefix(files,role,opt,'saved')+'.phase-3';raw=files[good_key];assert row['good_key']==good_key and row['good_sha256']==sha(raw)
  expected=zlib.crc32(raw[:-4]);assert row['expected_crc']==expected!=0
  assert extra[case+'/good']==extra[case+'/proper']==extra[case+'/copy']==raw
  original.valid_generation(raw)
  assert extra[case+'/zero_footer']==raw[:-4]+b'\0'*4
  bad=bytearray(raw);n=struct.unpack_from('<i',bad,8)[0];end=152+n-1 if family=='joint'else 84+n-1;bad[end]^=1;bad[-4:]=struct.pack('<I',zlib.crc32(bad[:-4]));assert extra[case+'/inner_crc_resealed_outer']==bytes(bad)
  selected=[e for e in events if e['label'].endswith('-'+case)];assert len(selected)==(3 if family=='joint'else 5)
  wanted={'proper-resealed-'+case}
  for kind in ('zero_footer','inner_crc_resealed_outer'):
   if family=='joint':wanted.add(kind+'-'+case)
   else:wanted.update({kind+'-empty-'+case,kind+'-live-'+case})
  assert {e['label']for e in selected}==wanted and len(selected)==len(wanted)
  for event in selected:
   assert event['returncode']==0 and event['command'][0]==root+'/'+case+'/decoder'
   c=event['command'];label=event['label'];stdout=extra[event['stdout']];assert event['stderr']in extra
   if label.startswith('proper-resealed-'):
    assert c[1:]==(['generation-read',root+'/'+case+'/proper',root+'/'+case+'/copy']if family=='joint'else['saved-resume',root+'/'+case+'/proper',root+'/'+case+'/copy','','roundtrip'])
    assert (b'JOINT_OUTPUT_INDEPENDENT_GENERATION_READ=PASS'if family=='joint'else b'SAVED_GENERATION_FRESH_CONTINUATION_PASS')in stdout
   else:
    kind='zero_footer'if label.startswith('zero_footer-')else'inner_crc_resealed_outer';assert c[2]==root+'/'+case+'/'+kind
    prefix=case+'/'+kind+'-live'
    if family=='joint':
     assert c[1]=='generation-reject'and c[3:]==[root+'/'+prefix,'',root+'/'+case+'/good']
     assert b'JOINT_OUTPUT_GENERATION_ATOMIC_INVALID=PASS'in stdout
     assert extra[prefix+'.before']==extra[prefix+'.after']==raw
    elif '-empty-'in label:
     assert c[1]=='saved-reject'and c[3:]==[root+'/'+case+'/unused']and b'SAVED_GENERATION_INVALID_ATOMIC_PASS'in stdout
    else:
     assert c[1]=='saved-reject-live'and c[3:]==[root+'/'+prefix]and b'SAVED_GENERATION_INVALID_LIVE_ATOMIC_PASS'in stdout
     assert extra[prefix+'.before-invalid']==extra[prefix+'.after-invalid']==extra[prefix]==raw
 return dict(native_launches=32,proper_valid_reexports=8,actual_decoder_refusals=24,exact_live_authority_preserved=True,whole_scientific_admission=False)
def controls(files,extra):
 names=['candidate-O0-joint/decoder','candidate-O2-saved/zero_footer-live.after-invalid','candidate-O0-joint/inner_crc_resealed_outer'];refused=[]
 for name in names:
  bad=dict(extra);bad[name]=bad[name]+b'X'
  try:verify(files,bad)
  except (AssertionError,KeyError,ValueError):refused.append(name)
  else:raise AssertionError('corrupt native control proof admitted: '+name)
 return refused
def qualified(files=None):
 if files is None:_,files=original.unpack();original.audit(files)
 extra=unpack();return dict(audit=verify(files,extra),controls=controls(files,extra))
def main():
 original.policy.guard();print(json.dumps(qualified()))
if __name__=='__main__':main()
