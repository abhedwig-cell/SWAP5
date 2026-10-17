#!/usr/bin/env python3
"""Bounded physical retained-stock admission; immutable incumbent authority."""
from pathlib import Path
from functools import lru_cache
import argparse,base64,copy,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/MC_NUT_SOL_STATUS.json';KEY='b112_retained_stock_20261016'
BASE='5d2518abd2b285b13f9b5f7d2177918589fd7abc'
INTEGRATED='40c6fe4252cb80bc2adbeee2731f76199f6a7c48'
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def verify_execution_inventory(name,files,result):
  """Fail closed when stored endpoints are not backed by executed native commands."""
  events=json.loads(files[name+'/events.json']) if name in ('small','joint') else result['events']
  require(isinstance(events,list) and bool(events),'missing execution inventory '+name)
  observed=set()
  native=[]
  compiled=set()
  for e in events:
   command=e['command']
   require(isinstance(command,list) and all(isinstance(x,str) for x in command) and command,'invalid command')
   signature=tuple(command)
   require(signature not in observed,'duplicate execution command '+name)
   observed.add(signature)
   require(e['returncode']==0,'failed executed command '+name)
   if e['category'] in ('compile','provider_compile','driver_compile'):
    require('-c' in command and '-o' in command,'invalid compilation record')
    source=command[command.index('-c')+1]
    build_group=next((opt for opt in ('O0','O2') if any('/'+opt+'/' in x for x in command)),None)
    require(build_group is not None,'unidentified compilation optimization')
    key=(build_group,source)
    require(key not in compiled,'duplicate compilation')
    compiled.add(key)
    require(any(x in command for x in ('-fcheck=all','-fcheck=bounds')),'missing runtime bounds checks')
    require(any(x.startswith('-ffpe-trap=') and all(y in x for y in ('invalid','zero','overflow')) for x in command),'missing IEEE traps')
   if e['category']=='native':
    native.append(command)
    require('stdout' in e and 'stderr' in e,'unrecorded native output')
    for stream in ('stdout','stderr'):
     require(name+'/'+e[stream] in files,'missing executed stream '+name)
  require(native,'no native programs executed '+name)
  for opt in ('O0','O2'):
   selected=[c for c in native if any('/'+opt+'/' in x for x in c)]
   require(selected,'missing native optimization '+name+':'+opt)
   if name=='small':
    expected={'test_b112_retained_split','test_b112_retained_day'}
    require({Path(c[0]).name for c in selected}==expected,'incomplete small native matrix')
    require(len(selected)==len(expected),'missing/duplicated small programs')
   elif name=='joint':
    matched=[c for c in selected if Path(c[0]).name=='test_b112_retained_joint']
    require(any(len(c)>1 and c[1]=='write' for c in matched),'missing joint write')
    require(any(len(c)>1 and c[1]=='resume' for c in matched),'missing joint restart')
    seen_reject={c[4] for c in matched if len(c)>4 and c[1]=='reject'}
    require(seen_reject=={'absent','old-profile','legacy','wrong-return','wrong-dvsnlt','wrong-dvsnt','wrong-nfixf','wrong-fntrt'},'missing named configuration rejects')
    require(sum(len(c)>1 and c[1]=='reject' and len(c)==4 for c in matched)==11,'missing decoder negatives')
   elif name=='phases':
    names={Path(c[0]).name for c in selected}
    require(names=={'original_thermal','test_b112_retained_thermal','test_b112_retained_empty'},'missing phase native drivers')
    require(sum(Path(c[0]).name=='test_b112_retained_empty' for c in selected)==1,'missing empty phase')
    for prog,profiles in [('original_thermal',('manual','calendar')),('test_b112_retained_thermal',('selected',))]:
     for profile in profiles:
      for action in ('write','resume'):
       require(sum(Path(c[0]).name==prog and len(c)>4 and c[1]==action and c[4]==profile for c in selected)==1,'missing phase '+prog+' '+profile+' '+action)

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
  if name in ['small','joint']:
   events=json.loads(files[name+'/events.json'])
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
 p=json.loads((ROOT/STATUS).read_text())[KEY];e=p['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
 require(sha(raw)==e['sha256'],'archive integrity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:files={m.name:t.extractfile(m).read()for m in t if m.isfile()}
 verify(p,files)
 rows={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',INTEGRATED,'--','src','tests','tools','reference','.github'],cwd=ROOT,text=True).splitlines()}
 require(rows=={k:v['status']for k,v in p['successor_postimages'].items()},'foreign retained successor')
 for path,v in p['successor_postimages'].items():
  b=(ROOT/path).read_bytes();require(hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==v['blob'],'unqualified successor '+path)
 require(subprocess.check_output(['git','diff',BASE,'--','reference'],cwd=ROOT)==b'','reference changed in production unit')
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
 require(git_reader is None,'unregistered projected reader');load_verified();old=incumbent(True)
 return {**old,'b112_retained_successor':True,'qualified':False,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()}
def verify_qualification():
 load_verified();old=incumbent(False)
 return {**old,'incumbent':old,'b112_retained_successor':True,'qualified':True,'current_source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
def main():
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
  print('B112_RETAINED_EVIDENCE_CORRUPTION_CONTROLS='+str(len(controls)))
 verify_qualification();print('B112_RETAINED_SOURCE_EVIDENCE=PASS')
if __name__=='__main__':main()
