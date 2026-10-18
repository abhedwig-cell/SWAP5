#!/usr/bin/env python3
"""Bounded physical retained-stock admission; immutable incumbent authority."""
from pathlib import Path
from functools import lru_cache
import argparse,base64,copy,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/MC_NUT_SOL_STATUS.json';KEY='b112_retained_stock_20261016'
BASE='5d2518abd2b285b13f9b5f7d2177918589fd7abc'
INTEGRATED='47421ae0ec4145a25cb805bf38b63a6f1d32ea3a'
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def verify_execution_inventory(name,files,result):
  """Bind required executions to unique checked builds and their raw streams.

  Combine the independent 17 October review with the chat repair. Provider
  counts follow the sealed source inventory, not a historical closure size.
  """
  from collections import Counter
  events=json.loads(files[name+'/events.json']) if name in ('small','joint') else result['events']
  require(isinstance(events,list) and bool(events),'missing execution inventory '+name)
  drivers={
   'small':{'test_b112_retained_split':1,'test_b112_retained_day':1},
   'joint':{'test_crop_soil_day':1,'test_crop_soil_joint':24,'test_reactive_joint':12,
            'test_mineral_joint':12,'test_reproductive_joint':8,'test_b111_request_day':1,
            'test_b111_reproductive_day':1,'test_b112_retained_joint':21},
   'phases':{'original_thermal':4,'test_b112_retained_thermal':2,'test_b112_retained_empty':1}}
  observed=set();compiled={};objects={};linked={};native=[]
  for e in events:
   command=e['command'];category=e['category']
   require(isinstance(command,list) and command and all(isinstance(x,str) for x in command),'invalid command')
   require(category in ('compile','provider_compile','driver_compile','link','native'),'unknown execution category')
   require(tuple(command) not in observed,'duplicate execution command '+name);observed.add(tuple(command))
   require(e['returncode']==0,'failed executed command '+name)
   for stream in ('stdout','stderr'):
    path=name+'/'+e.get(stream+'_file',e.get(stream,''))
    require(path in files,'missing executed stream '+name)
    if stream+'_sha256' in e:require(sha(files[path])==e[stream+'_sha256'],'raw science integrity')
   if category=='native':
    require(command[0] in linked,'native without preceding link '+command[0])
    native.append((command,e));continue
   require('-o' in command,'missing build output')
   output=command[command.index('-o')+1]
   opts=[opt for opt in ('O0','O2') if '/'+opt+'/' in output]
   require(len(opts)==1,'unidentified build optimization');opt=opts[0]
   require('-'+opt in command and not any('-'+other in command for other in ('O0','O1','O2','O3','Ofast') if other!=opt),'mismatched build optimization')
   require('-fcheck=all' in command,'missing runtime checks')
   require('-ffpe-trap=invalid,zero,overflow' in command,'missing IEEE traps')
   if category!='link':
    require('-c' in command,'invalid compilation record')
    source=command[command.index('-c')+1];key=(opt,source)
    require(key not in compiled and output not in objects,'duplicate compilation')
    compiled[key]=e;objects[output]=e
   else:
    require(output not in linked,'duplicate link')
    inputs=[x for x in command if x.endswith('.o')]
    require(inputs and len(set(inputs))==len(inputs),'invalid link objects')
    if name!='phases':require(all(x in objects for x in inputs),'link without compiled object')
    linked[output]=e
  require(native,'no native programs executed '+name)
  for opt in ('O0','O2'):
   selected=[(c,e) for c,e in native if '/'+opt+'/' in c[0]]
   require(Counter(Path(c[0]).name for c,e in selected)==drivers[name],'incomplete native matrix '+name+' '+opt)
   sources=result.get('input_sha256',result.get('inputs',{}))
   for path in sources:
    if path.startswith('src/') and path.endswith('.f90'):
     matches=[e for (o,source),e in compiled.items() if o==opt and source.endswith('/'+path)]
     # Phases inherit the already executed joint build, bound below by digest.
     if name!='phases':require(len(matches)==1,'missing actual provider '+opt+' '+path)
   for prog in drivers[name]:
    require(sum(o==opt and Path(source).stem==prog for o,source in compiled)==1,'missing driver compilation '+prog+' '+opt)
   if name=='joint':
    matched=[(c,e) for c,e in selected if Path(c[0]).name=='test_b112_retained_joint']
    row=result['b112_retained'][opt]
    for action,key in (('write','joint_stdout'),('resume','fresh_stdout')):
     matches=[e for c,e in matched if len(c)==4 and c[1]==action]
     require(len(matches)==1,'missing joint '+action)
     require(files[name+'/'+matches[0]['stdout_file']].decode()==row[key],'joint raw result '+action)
    expected_profiles={'absent','old-profile','legacy','wrong-return','wrong-dvsnlt','wrong-dvsnt','wrong-nfixf','wrong-fntrt'}
    require(set(row['profile_negatives'])==expected_profiles and len(row['profile_negatives'])==8,'invalid profile inventory')
    require(Counter(c[4] for c,e in matched if len(c)==5 and c[1]=='reject')==Counter({x:1 for x in expected_profiles}),'missing named configuration rejects')
    expected_decoders={'retained_N_nan','retained_N_orphan','retained_DM_negative','gross_mortality_negative','owner_profile_marker_missing','owner_envelope_size','old_native_tag','unsupported_native_tag','crc','truncated','trailing'}
    require(set(row['decoder_negatives'])==expected_decoders and len(row['decoder_negatives'])==11,'invalid decoder inventory')
    require(Counter(Path(c[2]).name for c,e in matched if len(c)==4 and c[1]=='reject')==Counter({'b112-invalid-'+x+'.bin':1 for x in expected_decoders}),'missing named decoder rejects')
   if name=='phases':
    for prog,profiles in [('original_thermal',('manual','calendar')),('test_b112_retained_thermal',('selected',))]:
     for profile in profiles:
      for action in ('write','resume'):
       require(sum(Path(c[0]).name==prog and len(c)==5 and c[1]==action and c[4]==profile for c,e in selected)==1,'missing phase '+prog+' '+profile+' '+action)
  if name=='phases':require(result['provider_result_sha256']==sha(files['joint/result.json']),'unbound reused phase providers')

def verify(p,files,reader=lambda path:(ROOT/path).read_bytes()):
 require(p['baseline']==BASE and p['qualified']is True,'unqualified retained profile')
 require(p['ledger_promotion']==[],'unqualified denominator promotion')
 require(p['aquifer']=='EXCLUDED','aquifer expansion')
 for path,digest in p['qualification_inputs_sha256'].items():require(sha(reader(path))==digest,'input drift '+path)
 results={name:json.loads(files[name+'/result.json'])for name in ['small','joint','phases','annual-source','annual-codec']}
 require(results['small']['status']=='B112_SMALL_PRODUCTION_PASS_NOT_ADMITTED','small production')
 for opt in ['O0','O2']:
  row=results['small']['runs'][opt]
  require('B112_PHYSICAL_PARTITION_CASES=20'in row['test_b112_retained_split'],'partition matrix')
  require('B112_ACTUAL_DAILY_PARTIAL_HARVEST_CASES=54'in row['test_b112_retained_day'],'daily harvest matrix')
  require('B112_REAL_INVALID_STORAGE_RESIDUE_REJECTIONS=27'in row['test_b112_retained_day'],'chemistry rejection matrix')
 require(results['small']['runs']['O0']==results['small']['runs']['O2'],'small optimization identity')
 joint=results['joint'];require(joint['status']=='B112_RETAINED_JOINT_PHYSICAL_PASS_NOT_ADMITTED','actual joint gate')
 require(joint['b112_retained']['O0']==joint['b112_retained']['O2'],'joint optimization identity')
 phases=results['phases'];require(phases['status']=='B112_THERMAL_PHASES_AND_ORIGINAL_BYTES_PASS','thermal phases')
 require(phases['runs']['O0']==phases['runs']['O2'],'thermal optimization identity')
 for name in ('small','joint','phases'):verify_execution_inventory(name,files,results[name])
 for name,r in results.items():
  for path,h in r.get('input_sha256',r.get('inputs',{})).items():require(sha(reader(path))==h,'executed source drift '+path)
  if name in ['small','joint','phases']:
   events=results['phases']['events'] if name=='phases' else json.loads(files[name+'/events.json'])
   require(all(e['returncode']==0 for e in events),'failed current science')
   for e in events:
    for stream in ['stdout','stderr']:
     raw=files[name+'/'+e.get(stream+'_file',e.get(stream))]
     if stream+'_sha256'in e:require(sha(raw)==e[stream+'_sha256'],'raw science integrity')
    if name=='small'and e['category']=='native':
     opt='O0'if'/O0/'in e['command'][0]else'O2';driver=Path(e['command'][0]).name
     require(files[name+'/'+e['stdout']].decode()==r['runs'][opt][driver],'small raw results')
  if name=='phases':
   require(all(e['returncode']==0 for e in r['events']),'failed thermal science')
 require(results['annual-source']['living_source_probe_pass']and results['annual-source']['O0_O2_stdout_identity'],'classic source preservation')
 require(results['annual-codec']['zero_counter_codec1_bytes_identical'],'classic codec preservation')
 # Re-executed classic preservation is evidence, not two unverified booleans.
 annual=results['annual-source']
 require({x['optimization'] for x in annual['runs']}=={0,2} and len(annual['runs'])==2,'classic optimization inventory')
 for path,h in annual['compiled_inputs'].items():
  if Path(path).is_absolute():
   require(Path(path).name=='oracle.f90' and sha(files['annual-source/oracle.f90'])==h,'classic generated oracle')
  else:require(sha(reader(path))==h,'classic executed input drift '+path)
 for row in annual['runs']:
  opt=row['optimization'];prefix='annual-source/o'+str(opt)+'/'
  require(row['compile_exit']==row['native_exit']==0,'failed classic source execution')
  require(all(f in row['command'] for f in ['-O'+str(opt),'-fcheck=all','-ffpe-trap=invalid,zero,overflow']),'unchecked classic source')
  require(sha(files[prefix+'native.stdout'])==row['stdout_sha256'],'classic raw native')
  require(prefix+'compile.stderr' in files and prefix+'compile.stdout' in files,'missing classic compilation')
 require(files['annual-source/o0/native.stdout']==files['annual-source/o2/native.stdout'],'classic native optimization drift')
 codec=results['annual-codec'];require(len(codec['runs'])==4 and {(x['opt'],x['profile']) for x in codec['runs']}=={(o,n) for o in (0,2) for n in ('baseline','current')},'classic codec inventory')
 for row in codec['runs']:
  require(row['compile_exit']==row['native_exit']==0,'failed classic codec')
  require(all(f in row['command'] for f in ['-O'+str(row['opt']),'-fcheck=all','-ffpe-trap=invalid,zero,overflow']),'unchecked classic codec')
  prefix='annual-codec/o'+str(row['opt'])+'-'+row['profile']+'/'
  for stream in ('compile.stdout','compile.stderr','stdout','stderr'):require(prefix+stream in files,'missing classic codec execution')
  require(sha(files[prefix+'zero.restart'])==codec['artifact_sha256'],'classic codec bytes drift')
 if p.get('reconciled_upstream')==INTEGRATED:
  tcs=json.loads(files['tcs6/result.json']);require(tcs['status']=='B112_CURRENT_TCS6_54_NATIVE_AND_ENDPOINT_BYTES_PASS','current TCS6 boundary')
  for path,h in tcs['input_sha256'].items():require(sha(reader(path))==h,'TCS6 executed source drift '+path)
  native=[e for e in tcs['events'] if e['category']=='native']
  require(len(native)==54 and len({tuple(e['command']) for e in native})==54 and len(tcs['runs'])==54,'TCS6 execution inventory')
  for e in tcs['events']:
   require(e['returncode']==0,'failed current TCS6')
   for stream in ('stdout','stderr'):require('tcs6/'+e[stream] in files,'missing current TCS6 stream')
  for row in tcs['runs']:
   matches=[e for e in native if '/o'+str(row['opt'])+'/' in e['command'][0] and Path(e['command'][0]).name=='test-'+row['driver'] and e['command'][-2:]==[row['mode'],row['phase']]]
   require(len(matches)==1 and sha(files['tcs6/'+matches[0]['stdout']])==row['stdout_sha256'],'unexecuted TCS6 result')

 for opt in ['O0','O2']:
  r=joint['b112_retained'][opt]
  require(len(r['profile_negatives'])==8 and len(r['decoder_negatives'])==11,'missing native rejection')
  expected=files['joint/'+opt+'/b112-expected.bin']
  require(expected==files['joint/'+opt+'/b112-fresh.bin']==files['joint/'+opt+'/b112-expected.bin.opaque'],'new native continuation')
  require(sha(expected)==r['endpoint_sha256'],'recorded new endpoint')
  require(files['joint/'+opt+'/b112-restart.bin'][:8]==b'S5NC0010','explicit retained live version')
  for suffix,tag in [('.harvest-pending',14),('.consumed',13)]:
   require(files['joint/'+opt+'/b112-expected.bin.stages'+suffix][:8]==f'S5NC{tag:04d}'.encode(),'explicit harvest version')
  require(files['phases/'+opt+'/empty.bin'][:8]==b'S5NC0009','live empty version')
  prefix='phases/'+opt+'/test_b112_retained_thermal-selected-'
  end=files[prefix+'expected.bin'];require(end==files[prefix+'fresh.bin']==files[prefix+'expected.bin.opaque'],'thermal fresh continuation')
  for suffix,tag in [('expected.bin.initial',11),('restart.bin',12),('expected.bin.stages.harvest-pending',16),('expected.bin.stages.consumed',15)]:
   require(files[prefix+suffix][:8]==f'S5NC{tag:04d}'.encode(),'thermal phase version')
 # Independent immutable comparisons, never a claimed archived PASS.
 for archive,prefix,names in [
  ('MC_NUT01_REPRODUCTIVE_PROCESS_SCIENCE_20261016.tar.xz.b64','final/', ['b111-expected.bin','b111-restart.bin','test_crop_soil_joint-expected.bin','test_crop_soil_joint-restart.bin','reproductive-expected.bin','reproductive-restart.bin']),
  ('MC_NUT01_ACCEPTED_THERMAL_20261015.tar.xz.b64','joint/',[])]:
  with tarfile.open(fileobj=io.BytesIO(base64.b64decode(reader('integration/audits/evidence/'+archive))))as t:
   old={m.name:t.extractfile(m).read()for m in t if m.isfile()}
  for opt in ['O0','O2']:
   for n in names:require(files['joint/'+opt+'/'+n]==old[prefix+opt+'/'+n],'incumbent native bytes '+n)
   if not names:
    for profile in ['manual','calendar']:
     for suffix in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque']:
      require(files['phases/'+opt+'/original_thermal-'+profile+'-'+suffix]==old['joint/'+opt+'/thermal-'+profile+'-'+suffix],'original thermal bytes')
 return results

def load_verified():
 p=json.loads((ROOT/STATUS).read_text())[KEY];require(p['reconciled_upstream']==INTEGRATED,'unreconciled retained admission');e=p['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
 require(sha(raw)==e['sha256'],'archive integrity')
 require(len(raw)==e['bytes'],'archive size')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers()
  require(len(members)==e['members'] and len({m.name for m in members})==len(members),'archive member inventory')
  require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe archive member')
  files={m.name:t.extractfile(m).read()for m in members}
 manifest=json.loads(files['MANIFEST.json']);require(set(manifest)==set(files)-{'MANIFEST.json'},'archive manifest inventory')
 for path,h in manifest.items():require(sha(files[path])==h,'archive member integrity '+path)
 verify(p,files)
 dirty=subprocess.check_output(['git','status','--porcelain','--untracked-files=all','--','src','tests','tools','reference','.github'],cwd=ROOT,text=True).strip()
 require(not dirty,'dirty retained scientific surface')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',INTEGRATED,'--','src','tests','tools','reference','.github'],cwd=ROOT,text=True).splitlines()}
 require(rows=={k:v['status']for k,v in p['successor_postimages'].items()},'foreign retained successor')
 for path,v in p['successor_postimages'].items():
  b=(ROOT/path).read_bytes();require(hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==v['blob'],'unqualified successor '+path)
 require(subprocess.check_output(['git','diff',INTEGRATED,'--','reference'],cwd=ROOT)==b'','reference changed in production unit')
 return p,files
@lru_cache(None)
def incumbent(source_only=False):
 root=ROOT.parent/('b112-retained-incumbent-'+INTEGRATED[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),INTEGRATED],cwd=ROOT,check=True,capture_output=True)
 require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==INTEGRATED,'incumbent moved')
 code='import sys,json;sys.path.insert(0,"tests/mc-irr01");import verify_tcs6_successor as v;print(json.dumps(v.'+('verify_source'if source_only else'verify_qualification')+'()))'
 cp=subprocess.run([sys.executable,'-B','-c',code],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 require(cp.returncode==0,'incumbent owner rejected '+cp.stderr[-2500:]);r=json.loads(cp.stdout)
 if not source_only:require(r['qualified']and r['tcs6_successor']and r['multilevel_divdra_successor']and r['reference_leaf_successor']and r['classic_annual_successor'],'incumbent authorities')
 return r
def verify_source(git_reader=None):
 if (ROOT/'tests/nut-crop/verify_hist_native_successor.py').is_file():
  import verify_hist_native_successor as historical
  return historical.verify_source(git_reader)
 require(git_reader is None,'unregistered projected reader');p,files=load_verified();old=incumbent(True)
 return {**old,'b112_retained_successor':True,'full_capability':False,'admitted':p['production_admitted'],'qualified':False,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()}
def verify_qualification():
 if (ROOT/'tests/nut-crop/verify_hist_native_successor.py').is_file():
  import verify_hist_native_successor as historical
  return historical.verify_qualification()
 p,files=load_verified();old=incumbent(False)
 return {**old,'incumbent':old,'b112_retained_successor':True,'full_capability':False,'admitted':p['production_admitted'],'qualified':True,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
def main():
 if (ROOT/'tests/nut-crop/verify_hist_native_successor.py').is_file():
  import verify_hist_native_successor as historical
  return historical.main()
 ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args();p,files=load_verified()
 if a.self_test:
  controls=[]
  def reject(label,p,files,reader=lambda path:(ROOT/path).read_bytes()):
   try:verify(p,files,reader)
   except(ValueError,KeyError):controls.append(label);return
   raise AssertionError('accepted '+label)
  q=copy.deepcopy(p);q['qualified']=False;reject('unqualified',q,files)
  q=copy.deepcopy(p);q['ledger_promotion']=['MC-NUT01'];reject('count expansion',q,files)
  q=copy.deepcopy(p);q['aquifer']='included';reject('aquifer',q,files)
  f=dict(files);r=json.loads(f['small/result.json']);del r['runs']['O2'];f['small/result.json']=json.dumps(r).encode();reject('missing O2',p,f)
  f=dict(files);f['joint/O0/b112-fresh.bin']+=b'corrupt';reject('fresh endpoint',p,f)
  f=dict(files);f['joint/O0/b112-restart.bin']=b'S5NC0002'+f['joint/O0/b112-restart.bin'][8:];reject('old native tag',p,f)
  f=dict(files);f['phases/O2/test_b112_retained_thermal-selected-fresh.bin']+=b'corrupt';reject('thermal endpoint',p,f)
  path=next(k for k in p['qualification_inputs_sha256']if k.startswith('src/'));reject('scientific body drift',p,files,lambda k:(ROOT/k).read_bytes()+(b'!corrupt'if k==path else b''))
  for owner in ('small','joint'):
   raw=json.loads(files[owner+'/events.json'])
   f=dict(files)
   f[owner+'/events.json']=json.dumps([e for e in raw if e['category']!='native']).encode()
   reject(owner+' missing native',p,f)
   f=dict(files)
   f[owner+'/events.json']=json.dumps(raw+[copy.deepcopy(next(e for e in raw if e['category']=='native'))]).encode()
   reject(owner+' duplicate native',p,f)
  f=dict(files)
  r=copy.deepcopy(json.loads(files['phases/result.json']))
  r['events']=[e for e in r['events'] if e['category']!='native']
  f['phases/result.json']=json.dumps(r).encode()
  reject('missing phase native',p,f)
  # Independent review controls plus same-count and named decoder mutations.
  for owner,category in [('joint','compile'),('joint','driver_compile'),('small','compile')]:
   rows=json.loads(files[owner+'/events.json']);f=dict(files)
   if category=='compile' and owner=='joint':rows=[e for e in rows if e['category']!=category]
   else:next(e for e in rows if e['category']==category)['command'].remove('-ffpe-trap=invalid,zero,overflow')
   f[owner+'/events.json']=json.dumps(rows).encode();reject(owner+' unchecked '+category,p,f)
  for label in ('duplicate provider same count','wrong native optimization','unexecuted profile','unexecuted decoder','missing link','wrong compiler optimization'):
   rows=json.loads(files['joint/events.json']);f=dict(files)
   if label=='duplicate provider same count':
    indices=[i for i,e in enumerate(rows) if e['category']=='compile'];rows[indices[1]]=copy.deepcopy(rows[indices[0]])
   elif label=='wrong native optimization':
    e=next(e for e in rows if e['category']=='native');e['command'][0]=e['command'][0].replace('/O0/','/O2/')
   elif label=='unexecuted profile':
    e=next(e for e in rows if e['category']=='native' and e['command'][0].endswith('test_b112_retained_joint') and e['command'][-1]=='wrong-return');e['command'][-1]='unqualified-case'
   elif label=='unexecuted decoder':
    e=next(e for e in rows if e['category']=='native' and e['command'][0].endswith('test_b112_retained_joint') and 'b112-invalid-crc.bin' in e['command'][2]);e['command'][2]=e['command'][2].replace('invalid-crc','invalid-unqualified')
   elif label=='missing link':rows=[e for e in rows if not(e['category']=='link' and e['command'][-1].endswith('test_b112_retained_joint'))]
   else:
    e=next(e for e in rows if e['category']=='compile');e['command'][e['command'].index('-O0')]='-O2'
   f['joint/events.json']=json.dumps(rows).encode();reject(label,p,f)
  f=dict(files);r=json.loads(f['phases/result.json']);r['provider_result_sha256']='0'*64;f['phases/result.json']=json.dumps(r).encode();reject('unbound thermal provider',p,f)
  print('B112_RETAINED_EVIDENCE_CORRUPTION_CONTROLS='+str(len(controls)))
 verify_qualification();print('B112_RETAINED_SOURCE_EVIDENCE=PASS')
if __name__=='__main__':main()
