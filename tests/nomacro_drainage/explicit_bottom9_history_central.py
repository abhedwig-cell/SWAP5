"""Fresh history9 archive bytes, actual source objects and independent science.

Explicit immutable archive locations avoid extracted multi-gigabyte copies.
No producer field, native payload, scientific value or Git view is rewritten.
"""
import argparse,hashlib,io,json,struct,sys,tarfile,zipfile
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_history_science import audit,native
from explicit_bottom9_compiled_postimage import compare as all_compiled
from initial_profile_calendar_postimage import compare as generated
from explicit_bottom9_source_inverse import git


class Provider:
 def __init__(self,store):self.store=store
 def __truediv__(self,path):
  assert path.startswith('build/') and '..' not in Path(path).parts
  return ReadView(self.store,'original-provider-build/'+path[len('build/'):])


def source_objects(store):
 index=json.loads(store.get('COMMITTED_SOURCE_INDEX_V1.json'));assert index['working_source_capture_claimed'] is False;objects=set()
 for head,rows in index['epochs'].items():
  expected={}
  for line in git('ls-tree','-r',head,'--',*index['scope']).decode().splitlines():
   meta,path=line.split('\t');mode,kind,digest=meta.split();assert kind=='blob';expected[path]=dict(git_blob=digest,mode=mode)
  assert rows==expected;objects.update(item['git_blob'] for item in rows.values())
 for digest in sorted(objects):
  raw=store.get('committed-source/blobs/'+digest);assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==digest
 return index


def actual_source_capsules(store):
 captures=[]
 def check(path,raw,item,expected):
  assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and item['git_blob']==expected[path]
  digest=lambda value:hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest()
  assert expected[path] in (digest(raw),digest(raw.replace(b'\r\n',b'\n')))
 for name in sorted(store.names):
  if name.endswith('/RESULT.json') and '-actual-working-source-' in name:
   q=json.loads(store.get(name));head=q['producer_head'];prefix=name.rsplit('/',1)[0];raw=store.get(prefix+'/'+q['archive']);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256']
   expected={line.split('\t')[1]:line.split('\t')[0].split()[2] for line in git('ls-tree','-r',head,'--',*q['surfaces']).decode().splitlines()}
   assert set(q['members'])==set(expected);absent={path for path,item in q['members'].items() if item.get('checkout')=='ABSENT'};assert all(path.startswith('reference/swap-4.3.1/') for path in absent)
   with zipfile.ZipFile(io.BytesIO(raw)) as archive:
    assert len(archive.namelist())==len(set(archive.namelist())) and set(archive.namelist())==set(expected)-absent
    for path,item in q['members'].items():
     if path in absent:assert item==dict(git_blob=expected[path],checkout='ABSENT')
     else:check(path,archive.read(path),item,expected)
   captures.append(dict(kind='actual_working_source',actual_head=head,archive_sha256=q['sha256'],members=len(q['members'])))
  elif name.endswith('.json') and '-actual-controller-source-' in name:
   q=json.loads(store.get(name));head=q['producer_head'];raw=store.get(name.rsplit('/',1)[0]+'/'+q['archive']);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256']
   expected={line.split('\t')[1]:line.split('\t')[0].split()[2] for line in git('ls-tree','-r',head,'--','tests/nomacro_drainage','tests/nomacro_scheduled_subsurface','tests/nomacro_mixtures','.github/workflows/nomacro-extended-implicit.yml').decode().splitlines()};assert set(expected)==set(q['members'])
   with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
    members=archive.getmembers();assert len(members)==len({m.name for m in members}) and {m.name for m in members}==set(expected)
    for member in members:assert member.isfile();check(member.name,archive.extractfile(member).read(),q['members'][member.name],expected)
   captures.append(dict(kind='actual_controller_source',actual_head=head,archive_sha256=q['sha256'],members=len(q['members'])))
 assert len(captures)==4
 return captures


def native_controls(store,role,profile,build,inputs,selected,dz):
 root=ReadView(store,role['native_controls']);q=json.loads((root/'RESULT.json').read_text());meta=json.loads((build/'BUILD.json').read_text());rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];row=rows[3]
 with zipfile.ZipFile(io.BytesIO((profile/'trajectory/accepted-column-1-day-4.zip').read_bytes())) as z:good=z.read('macro.bin')
 assert q['actual_compiler_producer']==role['producer'] and q['actual_BUILD_sha256']==SHA((build/'BUILD.json').read_bytes()) and q['accepted_model_days']==q['compiler_executions']==q['model_periods']==0
 assert q['status']=='ALL28_ACTUAL_COMPILED_HISTORY9_NATIVE_AND_IDENTICAL_PAYLOAD_INDEPENDENT_REFUSALS_PASS' and len(q['refusals'])==q['compiled_refusals']==q['independent_refusals']==28
 header=native(good,meta,row,selected,dz);domain=header['actual_domain_offset'];hydraulic=header['hydraulic_state_offset'];n=len(dz);expected={}
 def mutation(label,offset,fmt,value):
  raw=bytearray(good);struct.pack_into(fmt,raw,offset,value);expected[label]=bytes(raw)
 expected.update(parent_codec=b'S5NHS007'+good[8:],truncated=good[:-1],trailing=good+b'\0')
 for label,offset in [('domain',domain),('witness',domain+28)]:
  for i in range(7):mutation(label+'-'+str(i),offset+4*i,'<i',struct.unpack_from('<i',good,offset+4*i)[0]+1)
 for label,index,value in [('foreign-bottom',6,6),('foreign-drainage',5,1-selected['swdra']),('foreign-hysteresis',3,3-selected['swhyst'])]:
  raw=bytearray(good)
  for offset in (domain,domain+28):struct.pack_into('<i',raw,offset+4*index,value)
  expected[label]=bytes(raw)
 for label,index,value in [('head-nan',0,float('nan')),('negative-theta',n,-1.),('negative-K',2*n,-1.),('negative-Kmean',3*n+1,-1.),('negative-capacity',4*n+2,-1.),('negative-volume',5*n+3,-1.),('unbalanced-volume',5*n+3,row['stock_end_cm'][0]+1.)]:mutation(label,hydraulic+8*index,'<d',value)
 mutation('foreign-clock',12,'<d',struct.unpack_from('<d',good,12)[0]+1.)
 assert len(expected)==28 and {item['label'] for item in q['refusals']}==set(expected)
 positive=root/'positive-startup/original';assert (positive/'macro-origin.bin').read_bytes()==good and b'HYBRID_READY' in (positive/'donor.stdout').read_bytes() and b'HYBRID_DAY_RETURN' not in (positive/'donor.stdout').read_bytes() and not (positive/'donor.stderr').read_bytes()
 for item in q['refusals']:
  label=item['label'];actual=root/(label+'/original');raw=(actual/'macro-origin.bin').read_bytes();assert raw==expected[label] and SHA(raw)==item['actual_payload_sha256']
  assert (actual/'donor.stderr').read_text()==item['actual_compiled_stderr'] and 'ERROR STOP' in item['actual_compiled_stderr'] and b'HYBRID_READY' not in (actual/'donor.stdout').read_bytes() and b'HYBRID_DAY_RETURN' not in (actual/'donor.stdout').read_bytes()
  assert item['actual_native_returncode'] not in (0,100) and item['identical_payload_independent_reader_refused'] is True
  try:native(raw,meta,row,selected,dz)
  except (AssertionError,ValueError,struct.error):pass
  else:raise AssertionError('Archived malformed native payload independently accepted: '+label)
 return dict(actual_compiled_refusals=28,identical_payload_independent_refusals=28,actual_positive_startups=1,accepted_model_days=0)


def windows(proof):
 import re
 results=[]
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_HISTORY_WINDOWS_RAW_V1',stack);record=store.record
  provider=Archive(proof,record['original_provider_archive'],stack);assert provider.record['sha256']==record['original_provider_archive_sha256']=='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a';reference=Provider(provider)
  index=source_objects(store);assert sorted(index['epochs'])==record['actual_source_epochs'];captures=actual_source_capsules(store);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));diagnostic=json.loads(store.get('DIAGNOSTIC_COMPILED_PROJECTION_V1.json'));assert len(projection)==36 and len(diagnostic)==1
  # Every original raw member is freshly checked, including all failures and
  # complete compiled closures; nothing is extracted or cached as new data.
  for name in store.names:store.get(name)
  def build(path):
   item=projection[path];root=ReadView(store,item['archive_prefix']);assert SHA((root/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'];return root
  for role in record['roles']:
   profile=ReadView(store,role['profile']);counter=ReadView(store,role['postimage']);q=json.loads((profile/'RESULT.json').read_text());c=json.loads((counter/'RESULT.json').read_text());first,second=build(q['build_root']),build(c['build_root']);inputs=ReadView(store,role['inputs']);opposite=ReadView(store,role['counter_inputs'])
   assert q['source']==role['producer'] and q['build']['actual_completion_head']==q['source'] and c['build']['actual_completion_head']==c['source']
   assert SHA((profile/'RESULT.json').read_bytes())==c.get('primary_RESULT_sha256',c.get('initial1_RESULT_sha256'))
   for candidate,metadata in [(first,q),(second,c)]:
    compiled=json.loads((candidate/'BUILD.json').read_text())
    for digest,path in [(compiled['identity']['host'],'app/hybrid_water/daily_host.py'),(compiled['identity']['lower_boundary_receipt']['source_sha256'],'app/hybrid_water/prescribed_head_flux_boundary.py')]:
     raw=store.get('committed-source/blobs/'+index['epochs'][metadata['source']][path]['git_blob']);assert digest in (SHA(raw),SHA(raw.replace(b'\n',b'\r\n')))
   assert generated(first,second)==c['postimage'] and all_compiled(first,second)==c['all_compiled']
   a=(inputs/'swap.swp').read_bytes();b=(opposite/'swap.swp').read_bytes();pattern=rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)[12](?=[ \t!\r\n])';assert a!=b and re.sub(pattern,rb'\g<1>INITIALIZATION_SELECTOR',a)==re.sub(pattern,rb'\g<1>INITIALIZATION_SELECTOR',b)
   for name,digest in q['input_inventory']:
    if name!='swap.swp':assert (inputs/name).read_bytes()==(opposite/name).read_bytes()
   actual=audit(profile,reference,dict(inputs=inputs,build=first));assert actual==json.loads(store.get(role['independent'])) and actual['initialization']==role['primary_initial']
   text=(inputs/'swap.swp').read_text();table=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert table;dz=[]
   for line in table[1].splitlines():
    _,_,height,count=line.split();dz.extend([float(height)/int(count)]*int(count))
   selected=dict(json.loads((first/'BUILD.json').read_text())['identity']['original_output'],swdra=role['drainage']);controls=native_controls(store,role,profile,first,inputs,selected,dz)
   results.append(dict(kind=role['kind'],hysteresis=role['hysteresis'],drainage=role['drainage'],optimization=role['optimization'],primary_initial=role['primary_initial'],counterpart_initial=role['counterpart_initial'],science=actual,native_controls=controls));print('CENTRAL_ORIGINAL_HISTORY9_SOURCE_LEDGER_NATIVE_COLD_ALL_COMPILED_REFUSALS_PASS',role['kind'],role['hysteresis'],role['drainage'],role['optimization'],flush=True)
  assert len(results)==16
 return dict(status='ALL16_WINDOWS_HISTORY9_ORIGINAL_RAW_SOURCE_LEDGER_SCANNING_NATIVE_COLD_COMPILED_AND448_ACTUAL_NATIVE_REFUSALS_CENTRAL_INDEPENDENT_PASS_NOT_ADMITTED',raw_sha256=record['sha256'],contexts=results,source_epochs=sorted(index['epochs']),actual_working_and_controller_source_captures=captures,actual_native_refusals=448,identical_payload_independent_refusals=448,exact_cold_windows=48,compiler_executions=0,model_executions=0,archive_members_extracted=0,scientific_data_or_metadata_projected=False,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=windows(a.proof)
 with a.output.open('x') as f:json.dump(q,f,indent=2)
 print(q['status'])
