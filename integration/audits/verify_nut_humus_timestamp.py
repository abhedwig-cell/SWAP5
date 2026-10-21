"""Source-bound humus timestamp successor; exact predecessor remains frozen."""
from pathlib import Path
import base64,hashlib,io,json,re,runpy,struct,subprocess,sys,tarfile,zipfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
KEY='humus_timestamp_20261021'
BASE='bcf7a497d131d858b61e9ebbb7ec6dbc23fa6c8b'
SCIENCE=['src','tests','tools','reference','.github','app','examples','integration/audits','integration/performance','integration/diagnostics']
PRODUCTION={'src/process/mod_b111_soil_n_reactive_owner.f90','src/process/mod_soil_n_historical_activation.f90','src/process/mod_soil_n_historical_named_input.f90'}
OWNED=PRODUCTION|{'tests/nut-reactive/test_reactive_owner.f90','tests/nut-input/test_humus_timestamp.f90',
 'integration/audits/run_nut_humus_timestamp.py','integration/audits/run_nut_humus_joint.py',
 'integration/audits/verify_nut_humus_timestamp.py','integration/audits/package_nut_humus_timestamp.py','integration/audits/verify_swp_reader.py'}
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())[KEY]
def hook(fn):
 return " if 'evidence' in json.loads((ROOT/'"+STATUS+"').read_text()).get('"+KEY+"',{}):\n  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_humus_timestamp.py'))['"+fn+"']("+('reader,changed' if fn=='source' else '')+")\n"
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=record();require(s['baseline']==BASE,'clock baseline');git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty clock source')
 if changed is None:changed={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 idx=ROOT/s['evidence']['index'];index=json.loads(idx.read_text());allowed={str(idx.relative_to(ROOT)),*[str((idx.parent/p).relative_to(ROOT))for p in index['parts']]}
 require(all(changed.get(p)=='A'for p in allowed),'missing exact capsule additions')
 metadata=s.get('canonical_metadata',{})
 require(set(metadata)=={'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json','integration/audits/MC_SOL01_SWP_READER_HOSTED_20261021.json'},'canonical metadata scope')
 for p,v in metadata.items():require(changed.get(p)==v['status']and sha(reader(p))==v['sha256'],'canonical metadata identity '+p)
 actual={p:v for p,v in changed.items()if p not in allowed and p not in metadata}
 require(s['postimages'].keys()==OWNED,'clock owning set')
 require(actual=={p:v['status']for p,v in s['postimages'].items()},'foreign clock delta')
 for p,v in s['postimages'].items():require(sha(reader(p))==v['sha256'],'clock source identity '+p)
 for p,line in [('src/process/mod_soil_n_historical_activation.f90','   if(abs(source%hum_exp_start_day-anint(source%hum_exp_start_day))>0d0)return\n'),('src/process/mod_b111_soil_n_reactive_owner.f90','   if(abs(p%hum_exp_start_day-anint(p%hum_exp_start_day))>0d0)return\n')]:
  old=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True);require(old.count(line)==1 and reader(p).decode()==old.replace(line,''),'old-domain process body changed '+p)
 p='src/process/mod_soil_n_historical_named_input.f90';text=reader(p).decode();a=text.index(' pure subroutine parse_humus_timestamp(');b=text.index(' end subroutine\n',a)+len(' end subroutine\n')
 projected=(text[:a]+text[b:]).replace('only:real32,real64,','only:real64,',1).replace('call parse_humus_timestamp(trim(token),x,ios)','call parse_soil_n_date(trim(token),x,ios)',1)
 require(projected==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True),'old native reader body changed')
 p='integration/audits/verify_swp_reader.py';expected=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True)
 for fn in ['source','verify_qualification','self_test']:
  start=expected.index('\ndef '+fn)+1;end=expected.index('\n',start)+1;expected=expected[:end]+hook(fn)+expected[end:]
 require(reader(p).decode()==expected,'incumbent owner mutated')
 return s
def capsule():
 e=record()['evidence'];path=ROOT/e['index'];idx=json.loads(path.read_text());raw=base64.b64decode(b''.join((path.parent/p).read_bytes()for p in idx['parts']),validate=True)
 require(sha(raw)==e['sha256']==idx['decoded_sha256'],'clock capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  mm=t.getmembers();require(all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in mm),'unsafe capsule');require(len(mm)==len({m.name for m in mm}),'duplicate capsule member');f={m.name:t.extractfile(m).read()for m in mm}
 manifest=json.loads(f.pop('MEMBERS.json'));require(f.keys()==manifest.keys()and all(sha(f[p])==h for p,h in manifest.items()),'clock member bytes');return f
def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 js=lambda p:json.loads(f[p])
 helper=runpy.run_path(str(ROOT/'tests/nut-crop/verify_historical_gross.py'))
 for label in ['native','legacy_native','reactive','physical','joint']:
  r=js(label+'/result.json');helper['inputs'](r,reader)
  events=js(label+'/events.json')
  for e in events:
   require(e['returncode']==0 or label=='native'and e['category']=='original_native','native failure '+label)
   for stream in ['stdout','stderr']:
    name=e.get(stream,e.get(stream+'_file'))
    if name:
     require(label+'/'+name in f,'missing command stream')
     if stream+'_sha256'in e:require(sha(f[label+'/'+name])==e[stream+'_sha256'],'raw event hash')
 n=js('native/result.json');require(n['valid']==12 and n['invalid']==9,'original clock matrix')
 raw=base64.b64decode(reader('integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64'))
 require(sha(raw)==n['original_zip_sha256']=='ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193','original TTUTIL authority')
 with zipfile.ZipFile(io.BytesIO(raw))as z:
  for name in z.namelist():
   if not name.endswith('/'):require(f['native/tt/'+name]==z.read(name),'original TTUTIL member '+name)
 require(n['status']=='ORIGINAL_TTUTIL_AND_NATIVE_HUMUS_TIMESTAMP_O0_O2_PASS'and n['results']['O0']==n['results']['O2'],'clock source comparison')
 for row in n['results']['O0'].values():
  if isinstance(row,dict):require(row['original']==row['current'],'original timestamp arithmetic not exact')
 require(n['results']['O0']['1901-01-01_24:00']['current']==366,'original normalized hour')
 legacy=js('legacy_native/result.json');require(legacy['status']=='PASS'and len(legacy['fixtures'])==38 and legacy['outputs']['O0']==legacy['outputs']['O2'],'legacy native matrix')
 physical=js('physical/result.json');require(physical['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and physical['results']['O0']==physical['results']['O2'],'complete physical preservation')
 objects=set(helper['executions'](f,'physical',js('physical/events.json')))
 reactive=js('reactive/result.json');require(reactive['status']=='DIRECT_PASS'and reactive['o0_o2_endpoint_identity'],'original fractional reaction comparison')
 helper['executions'](f,'reactive',js('reactive/events.json'))
 old_nut=runpy.run_path(str(ROOT/'integration/audits/verify_nut_negative.py'))['capsule']()
 for opt in ['O0','O2']:
  for name in ['default',*physical['results'][opt]['endpoint']]:
   require(f['physical/'+opt+'/'+name+'.endpoint']==old_nut['production/physical/'+opt+'/'+name+'.endpoint'],'incumbent physical endpoint drift '+name)
 joint=js('joint/result.json');require(joint['status']=='FRACTIONAL_NATIVE_ACTUAL_RICHARDS_CROP_FALLOW_N_RESTART_PASS','fractional coupled missing')
 require(joint['physical_result_sha256']==sha(f['physical/result.json']),'unbound production build')
 require(joint['generated_driver_sha256']==sha(f['joint/driver.f90'])and joint['generated_include_sha256']==sha(f['joint/timestamp_joint.inc']),'generated composition source identity')
 ee=js('joint/events.json');counts={k:sum(e['category']==k for e in ee)for k in ['native','restart','clock_control']}
 require(counts==dict(native=4,restart=8,clock_control=8),'coupled actual process inventory')
 links=set()
 for e in ee:
  c=e['command']
  if '-c'in c:
   require('-fcheck=all'in c and'-ffpe-trap=invalid,zero,overflow'in c,'unchecked joint driver');objects.add(c[c.index('-o')+1])
  elif '-o'in c:
   require(all(o in objects for o in c if o.endswith('.o')),'joint link missing current object');links.add(c[c.index('-o')+1])
  else:require(c[0]in links,'joint native has no current link')
 max_abs=max_rel=0.
 for opt in ['O0','O2']:
  for name in ['negative-low','negative-high']:
   root='joint/'+opt+'/'+name;end=f[root+'.end'];ledger=f[root+'.end.ledger']
   for day in [1,6]:require(end==f[root+'.fresh-'+str(day)]and ledger==f[root+'.fresh-'+str(day)+'.ledger'],'fractional fresh restart drift')
   for day in [3,7]:require(f[root+'.restart.before-'+str(day)]==f[root+'.restart.water-reject-'+str(day)]==f[root+'.restart.chemical-reject-'+str(day)],'fractional rejection published candidate')
   require(ledger==f[root+'.ceil.ledger']and ledger!=f[root+'.floor.ledger'],'fractional endpoint predicate lost')
   require(end==f['joint/O0/'+name+'.end']and ledger==f['joint/O0/'+name+'.end.ledger'],'fractional optimization drift')
   v=struct.unpack('15d',ledger);require(v[6]>0 and v[13]<=1e-12 and v[14]<=1e-10,'fractional process/balance')
   text=joint['results'][opt+'/'+name]['stdout'];require('BOUND_FRACTIONAL_CLOCK'in text and len(re.findall(r'NEGATIVE_DAY',text))==12,'real native coupled steps')
   budget=list(map(float,next(l for l in text.splitlines()if'NEGATIVE_BUDGET'in l).split()[1:]));require(abs(budget[0]+budget[1]-budget[2]-budget[3])<=1e-10,'whole N book');max_abs=max(max_abs,abs(budget[4]));max_rel=max(max_rel,budget[5])
 # Current SOL/PERF application providers are independent of the three NUT
 # providers. Preserve their executed evidence, without invoking strict old
 # source-delta ownership on a later registered successor.
 old=runpy.run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))
 require(old['validate'](old['capsule'](),reader)['qualified'],'current SOL predecessor science')
 # Concurrent PR1353 added the original FSI35 native replay and transaction
 # registry. Its compiled historical providers are unchanged by this input work.
 sol=json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text())['swp_reader_successor']
 native=sol['fsi35_reconciliation']['native_evidence']
 require(sha(reader(native['path']))==native['sha256']and sha(reader('tests/fci/run_fci93_non_m1_fixed_k_qualification.sh'))==native['script_sha256'],'FSI35 replay/script changed')
 for p in ['src/transaction/mod_transaction_reference.f90','src/legacy/b1_10_port/headcalc.f90']:
  require(reader(p)==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'FSI35 provider changed')
 require(helper['unchanged_ci_closure']()==3,'changed original core CI provider footprint')
 predecessor=js('predecessor.json');require(predecessor['qualified']and predecessor['source_tree']==git('rev-parse',BASE+':src'),'frozen predecessor owner')
 return dict(qualified=True,status='HUMUS_TIMESTAMP_ORIGINAL_NATIVE_AND_CURRENT_COUPLED_QUALIFIED',source_tree=git('rev-parse','HEAD:src'),full_capability=False,full_migration_qualified=False,clock_valid=12,clock_invalid=9,legacy_native=38,fresh_restarts=8,current_coupled_cases=4,max_abs_N_residual=max_abs,max_relative_N_residual=max_rel,old_domain_bodies_exact=True,full_fci='NOT_SELECTED_IMPACT_NUT_INPUT_CLOCK')
def verify_qualification():source();return validate(capsule())
def self_test():
 source();f=capsule();validate(f);controls=[]
 def reject(name,action):
  try:action()
  except (ValueError,KeyError,AssertionError,StopIteration):controls.append(name);return
  raise ValueError('corruption accepted '+name)
 for p in PRODUCTION|set(record()['canonical_metadata']):reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 for p in ['native/result.json','legacy_native/result.json','reactive/result.json','physical/result.json','joint/O2/negative-high.fresh-6','joint/O0/negative-low.floor.ledger','predecessor.json']:
  broken=dict(f);broken.pop(p);reject('missing '+p,lambda broken=broken:validate(broken))
 broken=dict(f);p='joint/O0/negative-low.fresh-1';broken[p]+=b'!';reject('restart byte drift',lambda:validate(broken))
 return dict(count=len(controls),negative_controls=controls)
if __name__=='__main__':print(json.dumps(self_test()if'--self-test'in sys.argv else verify_qualification(),indent=2))
