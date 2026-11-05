"""Remeasure actual complete POSIX generations and execute independent native controls."""
import argparse,hashlib,io,json,os,struct,subprocess,tarfile,time,zipfile,zlib
from pathlib import Path
import generation_crc_runtime as policy
ROOT=policy.ROOT;BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda b:hashlib.sha256(b).hexdigest()
normal=lambda b:b.replace(b'\r\n',b'\n')
STEPS={'accepted':'ACTUAL_TWO_DAY_ACCEPTED_OUTPUT_O0_O2_FRESH_CONTINUATION_PASS','csv':'ACTUAL_ACCEPTED_CSV_O0_O2_FRESH_PASS','joint':'JOINT_OUTPUT_AUTOMATIC_ATOMIC_GENERATION_O0_O2_PASS','cold':'NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS','saved':'SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS'}
def valid_generation(raw):
 assert len(raw)>=88 and struct.unpack('<I',raw[-4:])[0]==zlib.crc32(raw[:-4]),'generation CRC'
 n=struct.unpack_from('<i',raw,8)[0]
 if raw[:8]==b'S5NS0001':
  assert len(raw)==84+n+4 and n>0;valid_generation(raw[84:84+n])
 else:
  assert raw[:8]==b'S5NO0001' and n>0
  nr=struct.unpack_from('<i',raw,12)[0];assert 0<=nr<=100000 and len(raw)==152+n+74*nr+4
  physical=raw[152:152+n];assert physical[:4]==b'S5NC'and struct.unpack('<I',physical[-4:])[0]==zlib.crc32(physical[:-4]),'nested physical CRC'
def prefix(files,role,opt,suffix):
 base=role+'/saved/'+opt+'/endpoint';candidates=[base+'.stages.'+suffix,base+'.'+suffix]
 found=[p for p in candidates if p+'.phase-3'in files];assert len(found)==1;return found[0]
def audit(files):
 r=json.loads(files['RESULT.json']);assert r['status']=='COMPLETE_GENERATION_POSIX_O0_O2_NATIVE_FULL_POSTIMAGE_PASS'
 assert all(r[k]is False for k in ('production_source_changed','production_admission','whole_scientific_admission'))
 events=json.loads(files['EVENTS.json']);assert events==r['events'];assert len(events)==10 and all(e['returncode']==0 for e in events)
 for e in events:
  for stream in ('stdout','stderr'):assert e[stream]in files
  assert e['label'].split('-',1)[1]in STEPS
  script=next(p for p in e['command']if p.endswith('.py'));name=script.rsplit('/',1)[-1]
  expected=dict(accepted='run_accepted_output.py',csv='run_accepted_output_csv.py',joint='run_joint_output_generation.py',cold='run_native_output_project.py',saved='run_saved_output.py')[e['label'].split('-',1)[1]];assert name==expected
 native={};compiles={};root=events[0]['command'][-1].removesuffix('/incumbent/accepted')
 for role in ('incumbent','candidate'):
  for n,p in policy.SOURCES.items():
   expected=policy.postimage(policy.before(p).decode())if role=='candidate'else policy.before(p).decode();raw=files[role+'/'+n+'.f90'];assert normal(raw).decode()==expected and r['roles'][role]['sources'][p]==sha(normal(raw))
  for step,status in STEPS.items():
   report=json.loads(files[role+'/'+step+'/result.json']);assert report==r['roles'][role]['results'][step]and report['status']==status
   for key in ('input_sha256','physical_input_sha256','cold_input_sha256'):
    for p,h in report.get(key,{}).items():
     expected=policy.before(p)if p in policy.SOURCES.values()else(ROOT/p).read_bytes()
     if role=='candidate'and p in policy.SOURCES.values():expected=policy.postimage(policy.before(p).decode()).encode()
     assert sha(normal(expected))==h,(role,step,p)
   assert sha(files[role+'/'+step+'/driver.f90'])==report['generated_driver_sha256']
   for key in ('pinned_object_sha256','pinned_artifacts'):
    for path,h in report.get(key,{}).items():
     assert path.startswith(root+'/');name=path[len(root)+1:];assert sha(files[name])==h,('coherent original object or module changed',name)
   ev=json.loads(files[role+'/'+step+'/events.json']);assert all(e['returncode']==0 for e in ev)
   compiles[role+'/'+step]=len([e for e in ev if '-c'in e['command']and any(str(v).endswith('.f90')for v in e['command'])])
   for e in ev:
    for stream in ('stdout','stderr'):assert role+'/'+step+'/'+e[stream]in files
    if '-c'in e['command']and any(str(v).endswith('.f90')for v in e['command']):
     assert all(f in e['command']for f in ('-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fopenmp'))
   assert report['results']['O0']==report['results']['O2'],(role,step,'optimization drift')
   assert report['results']==r['roles']['incumbent']['results'][step]['results'],(role,step,'postimage drift')
  for opt in ('O0','O2'):
   report=r['roles'][role]['results']['joint']['results'][opt]
   for suffix,key in [('', 'physical'),('.generation','generation'),('.csv','csv')]:assert sha(files[role+'/joint/'+opt+'/model.endpoint'+suffix])==report[key]
   for path in ('model.restart.generation','model.endpoint.generation'):
    name=role+'/joint/'+opt+'/'+path;valid_generation(files[name]);native[name]=sha(files[name])
   assert report['invalids']==14
   for stage in ('joint','saved'):
    c=r['roles'][role]['results'][stage]['results'][opt]['crashes'];assert set(c)=={'before','after'} and all(v['returncode']==-9 and v['complete']is True for v in c.values())
   for suffix in ('saved','deferred'):
    p=prefix(files,role,opt,suffix)
    for phase in (1,2,3):valid_generation(files[p+'.phase-'+str(phase)]);native[p+'.phase-'+str(phase)]=sha(files[p+'.phase-'+str(phase)])
    for day in (3,4):
     name=p+'.day-'+str(day);valid_generation(files[name]);native[name]=sha(files[name]);assert native[name]==r['roles'][role]['results']['saved']['results'][opt]['generations'][suffix][str(day)]
 for name,h in native.items():
  other=name.replace('candidate/','incumbent/',1);assert native[other]==h
  assert native[name.replace('/O2/','/O0/')]==h
 return dict(native_positive_files=native,full_compile_events=compiles,original_negative_and_kill_assertions=True,production_admission=False,whole_scientific_admission=False)
def unpack():
 r=json.loads((BASE/'GENERATION_CRC_POSIX_20261105.json').read_text());parts=r['member_capsule']['parts'];raw=b''.join((BASE/p['path']).read_bytes()for p in parts);assert sha(raw)==r['member_capsule']['sha256'] and len(raw)==r['member_capsule']['bytes']
 for part in parts:assert sha((BASE/part['path']).read_bytes())==part['sha256'] and (BASE/part['path']).stat().st_size==part['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers();assert len(members)==len(set(m.name for m in members));assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members);files={m.name:t.extractfile(m).read()for m in members}
 assert {n:sha(b)for n,b in files.items()}==r['original_zip_members_sha256'],'retained member content differs from exact original GitHub ZIP'
 return r,files
def replay():
 record,files=unpack();assert audit(files)==record['report'];print('COMPLETE_GENERATION_POSIX_RAW_FULL_MODULE_NATIVE_PROOF_REMEASURED');return files
def controls(files):
 targets=['candidate/output.f90','candidate/joint/O0/model.endpoint.generation'];refused=[]
 for name in targets:
  bad=dict(files);bad[name]=bad[name]+b'X'
  try:audit(bad)
  except (AssertionError,KeyError,ValueError):refused.append(name)
  else:raise AssertionError('corrupt generation proof admitted')
 # Repair every repeated result digest after corrupting the nested physical
 # CRC and resealing the outer envelope. The independent nested CRC must still
 # refuse the forged proof, rather than relying only on its inventory hashes.
 bad=dict(files);r=json.loads(bad['RESULT.json'])
 for role in ('incumbent','candidate'):
  for opt in ('O0','O2'):
   name=role+'/joint/'+opt+'/model.endpoint.generation';raw=bytearray(bad[name]);n=struct.unpack_from('<i',raw,8)[0];raw[152+n-1]^=1;raw[-4:]=struct.pack('<I',zlib.crc32(raw[:-4]));bad[name]=bytes(raw)
   report=json.loads(bad[role+'/joint/result.json']);report['results'][opt]['generation']=sha(raw);bad[role+'/joint/result.json']=json.dumps(report).encode();r['roles'][role]['results']['joint']=report
 bad['RESULT.json']=json.dumps(r).encode()
 try:audit(bad)
 except (AssertionError,ValueError,KeyError):refused.append('resealed_outer_and_result_digests_bad_nested_physical_crc')
 else:raise AssertionError('nested CRC ignored after repaired outer proof')
 return refused
def main():
 policy.guard();files=replay();print(json.dumps(dict(data_refusals=controls(files))))
if __name__=='__main__':main()
