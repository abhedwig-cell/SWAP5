"""Bounded HIST owner admission using current executions and immutable references."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
BASE='4a274c4650ec7f52324b8604838a8d27dd39edb3'
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def archive(d):
 raw=base64.b64decode((ROOT/d['path']).read_bytes());require(sha(raw)==d['decoded_sha256'],'HIST capsule integrity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();require(len(ms)==len({m.name for m in ms}),'duplicate HIST member');require(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe HIST member');f={m.name:t.extractfile(m).read()for m in ms}
 m=json.loads(f['MANIFEST.json']);m=m.get('files',m);require(set(m)==set(f)-{'MANIFEST.json'},'HIST inventory')
 for p,h in m.items():require(sha(f[p])==(h['sha256']if isinstance(h,dict)else h),'HIST raw drift '+p)
 return f

def validate(h,p,reader=lambda q:(ROOT/q).read_bytes()):
 import verify_b112_retained_successor as retained
 result=lambda f,n:json.loads(f[n+'/result.json'])
 def inputs(r):
  for q,d in r.get('input_sha256',r.get('inputs',{})).items():require(sha(reader(q))==d,'HIST input drift '+q)
 r=result(h,'nut-hist-capacity-qualified');inputs(r);require(r['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'and r['results']['O0']==r['results']['O2'],'HIST physical optimization')
 events=json.loads(h['nut-hist-capacity-qualified/events.json']);objects={};links={};seen=set()
 for i,e in enumerate(events):
  c=e['command'];require(e['returncode']==0 and tuple(c)not in seen,'failed/duplicate HIST event');seen.add(tuple(c))
  for stream in ['stdout','stderr']:require('nut-hist-capacity-qualified/'+e[stream]in h,'missing HIST stream')
  if e['category']=='compiler':continue
  if e['category']in ['native','restart_native']:require(c[0]in links,'HIST native without link');continue
  require(('-O0'in c or '-O2'in c)and '-fcheck=all'in c and '-ffpe-trap=invalid,zero,overflow'in c,'HIST build flags')
  out=c[c.index('-o')+1]
  if e['category']=='compile':require(out not in objects,'duplicate HIST object');objects[out]=c
  elif e['category']=='link':
   oo=[x for x in c if x.endswith('.o')];require(oo and len(set(oo))==len(oo)and all(x in objects for x in oo),'HIST uncompiled link');links[out]=c
  else:raise ValueError('unknown HIST event')
 for opt in ['O0','O2']:
  for q in r['input_sha256']:
   if q.startswith('src/')and q.endswith('.f90'):require(sum('-'+opt in c and c[c.index('-c')+1].endswith('/'+q)for c in objects.values())==1,'missing HIST provider '+q)
  for profile in ['source-profile','rotation-profile']:
   matches=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and e['command'][1]=='write'and e['command'][-1]==profile]
   require(len(matches)==1 and h['nut-hist-capacity-qualified/'+matches[0]['stdout']].decode()==r['results'][opt]['stdout'][profile],'HIST raw native result')
  prefix='nut-hist-capacity-qualified/'+opt+'/';end=h[prefix+'rotation-profile.endpoint'];require(sha(end)==r['results'][opt]['endpoint']['rotation-profile'],'HIST endpoint digest')
  for d in [1,120,121,365,366,500]:
   require(end==h[prefix+'rotation-fresh-'+str(d)],'HIST fresh endpoint')
   require(sum(e['category']=='restart_native'and'/'+opt+'/'in e['command'][0]and e['command'][-2:]==['rotation-profile',str(d)]for e in events)==1,'missing HIST fresh process')
  for d in [120,366]:require(h[prefix+'rotation-profile.restart.reject-before-'+str(d)]==h[prefix+'rotation-profile.restart.reject-after-'+str(d)],'HIST rejected state')
  require(h[prefix+'default.endpoint']==h[prefix+'default.fresh']==h[prefix+'default.endpoint.opaque'],'HIST default restart');require(h[prefix+'source-profile.endpoint']==h[prefix+'source-profile.fresh'],'HIST source restart')
 n=result(h,'nut-native-capacity-final');inputs(n);require(n['status']=='PASS'and len(n['fixtures'])==24 and n['outputs']['O0']==n['outputs']['O2'],'HIST parser matrix')
 ne=json.loads(h['nut-native-capacity-final/events.json']);require(sum(e['category']=='native'for e in ne)==48 and all(e['returncode']==0 for e in ne),'HIST parser native')
 o=result(h,'nut-ttutil-final3');require(o['status']=='ORIGINAL_TTUTIL_O0_O2_PASS'and o['results']['O0']==o['results']['O2'],'HIST TTUTIL');require(o['runner_sha256']==sha(reader('tests/nut-input/run_ttutil_native_oracle.py')),'HIST oracle drift');require(o['authority_zip_sha256']==sha(base64.b64decode(reader('integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64'))),'HIST TTUTIL authority')
 for q,d in o['fixture_sha256'].items():require(n['fixtures'][q]==d,'HIST source fixture')
 small=result(h,'nut-focused-a5');joint=result(p,'joint');phases=result(p,'phases');tcs=result(p,'tcs6')
 for x in [small,joint,phases,tcs]:inputs(x)
 sf={k.replace('nut-focused-a5/','small/',1):v for k,v in h.items()if k.startswith('nut-focused-a5/')};retained.verify_execution_inventory('small',sf,small)
 jf=dict(p);ee=json.loads(jf['joint/events.json']);extra=[e for e in ee if e['category']=='source_native'];require(len(extra)==4 and all(e['returncode']==0 for e in extra),'retained source-profile executions');jf['joint/events.json']=json.dumps([e for e in ee if e['category']!='source_native']).encode();retained.verify_execution_inventory('joint',jf,joint);retained.verify_execution_inventory('phases',p,phases)
 require(joint['status']=='B112_RETAINED_JOINT_PHYSICAL_PASS_NOT_ADMITTED'and joint['b112_retained']['O0']==joint['b112_retained']['O2'],'retained optimization');require(phases['status']=='B112_THERMAL_PHASES_AND_ORIGINAL_BYTES_PASS'and phases['runs']['O0']==phases['runs']['O2'],'thermal optimization');require(tcs['status']=='B112_CURRENT_TCS6_54_NATIVE_AND_ENDPOINT_BYTES_PASS'and len(tcs['runs'])==54,'TCS6 boundary')
 require(len([e for e in tcs['events']if e['category']=='native'])==54 and all(e['returncode']==0 for e in tcs['events']),'TCS6 executions')
 for row in tcs['runs']:
  matches=[e for e in tcs['events']if e['category']=='native'and '/o'+str(row['opt'])+'/'in e['command'][0]and Path(e['command'][0]).name=='test-'+row['driver']and e['command'][-2:]==[row['mode'],row['phase']]]
  require(len(matches)==1 and sha(p['tcs6/'+matches[0]['stdout']])==row['stdout_sha256'],'TCS6 raw result')
 for opt in ['O0','O2']:
  q='joint/'+opt+'/';require(p[q+'b112-expected.bin']==p[q+'b112-fresh.bin']==p[q+'b112-expected.bin.opaque'],'retained endpoint')
  for profile in ['manual','calendar']:
   q='phases/'+opt+'/original_thermal-'+profile+'-';require(p[q+'expected.bin']==p[q+'fresh.bin']==p[q+'expected.bin.opaque'],'thermal endpoint')
 # Independent immutable byte comparisons, beyond recorded PASS booleans.
 for archive_name,old_prefix,names in [
  ('MC_NUT01_REPRODUCTIVE_PROCESS_SCIENCE_20261016.tar.xz.b64','final/',['b111-expected.bin','b111-restart.bin','test_crop_soil_joint-expected.bin','test_crop_soil_joint-restart.bin','reproductive-expected.bin','reproductive-restart.bin']),
  ('MC_NUT01_ACCEPTED_THERMAL_20261015.tar.xz.b64','joint/',[])]:
  with tarfile.open(fileobj=io.BytesIO(base64.b64decode(reader('integration/audits/evidence/'+archive_name))))as t:old={m.name:t.extractfile(m).read()for m in t if m.isfile()}
  for opt in ['O0','O2']:
   for name in names:require(p['joint/'+opt+'/'+name]==old[old_prefix+opt+'/'+name],'old native byte drift')
   if not names:
    for profile in ['manual','calendar']:
     for suffix in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque']:require(p['phases/'+opt+'/original_thermal-'+profile+'-'+suffix]==old['joint/'+opt+'/thermal-'+profile+'-'+suffix],'old thermal byte drift')
 for opt in ['O0','O2']:
  require('B112_PHYSICAL_PARTITION_CASES=20'in small['runs'][opt]['test_b112_retained_split'],'retained partition matrix')
  require('B112_ACTUAL_DAILY_PARTIAL_HARVEST_CASES=54'in small['runs'][opt]['test_b112_retained_day']and 'B112_REAL_INVALID_STORAGE_RESIDUE_REJECTIONS=27'in small['runs'][opt]['test_b112_retained_day'],'retained daily/invalid matrix')
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(reader('integration/audits/evidence/MC_IRR01_TCS6_SCIENCE_20261016.tar.xz.b64'))))as t:
  for m in t:
   if m.isfile()and m.name.startswith(('physical/o0/','physical/o2/'))and m.name.endswith(('.full','.opaque','.resumed','.active.resumed')):require(p['tcs6/'+m.name.removeprefix('physical/')]==t.extractfile(m).read(),'old TCS6 byte drift')
 audit=result(p,'water-audit');inputs(audit)
 require(audit['status']=='HIST_OBSERVATIONAL_WATER_N_AUDIT_PASS'and audit['provider_result_sha256']==sha(h['nut-hist-capacity-qualified/result.json']),'HIST water audit binding')
 require(audit['results']['O0']==audit['results']['O2'],'HIST water audit optimization')
 for opt in ['O0','O2']:
  require(p['water-audit/'+opt+'/endpoint']==h['nut-hist-capacity-qualified/'+opt+'/rotation-profile.endpoint'],'audit changed physics')
  metrics=audit['results'][opt]['metrics'];require(abs(metrics['AUDIT_WATER_CM'][-1])<=1e-10,'HIST cumulative water')
 ae=json.loads(p['water-audit/events.json']);require(len([e for e in ae if e['category']=='native'])==2 and all(e['returncode']==0 for e in ae),'HIST water audit native')
 inherited=json.loads(p['inherited.json'])
 for q,d in inherited['source_sha256'].items():require(sha(reader(q))==d,'classic inherited drift '+q)
 require(inherited['annual_source_pass']and inherited['annual_codec_bytes_pass'],'classic preservation')
 return dict(local_physical_days=730,parser_cases=24,transition_fresh_processes=12,rollback_days=[120,366],full_retained_matrix=True,thermal=True,tcs6_native=54)

def load():
 # A separately qualified additive age successor may change only its recorded
 # surface. All original HIST scientific payload/input checks still execute.
 age_surface=(ROOT/'integration/audits/MC_SOL01_SURFACE_AGE01_STATUS.json').exists()
 if age_surface:
  import sys
  sys.path.insert(0,str(ROOT/'tests/nut-sol'))
  import verify_surface_age_successor as age
  age.verify_qualification()
 g=json.loads((ROOT/STATUS).read_text())['historical_guard'];require(g['baseline']==BASE,'HIST baseline');science=validate(archive(g['physical_evidence']),archive(g['retained_evidence']))
 for q,v in g['postimages'].items():
  if age_surface and q in ('tests/nut-crop/verify_hist_native_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'):continue
  require(sha((ROOT/q).read_bytes())==v['sha256'],'HIST postimage '+q)
 surface=['src','tests','tools','reference','.github'];require(not git('status','--porcelain','--',*surface),'dirty HIST science');rows={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*surface).splitlines()};require(age_surface or rows=={q:v['status']for q,v in g['postimages'].items()},'foreign HIST delta');require(not git('diff',BASE,'--','reference'),'HIST reference mutation');return science

def verify_source(git_reader=None):
 require(git_reader is None,'unregistered HIST projection');return {**load(),'historical_native_successor':True,'b112_retained_successor':True,'full_capability':False,'qualified':False,'current_source_tree':git('rev-parse','HEAD:src')}
def verify_qualification():return {**load(),'historical_native_successor':True,'b112_retained_successor':True,'qualified':True,'full_capability':False,'current_source_tree':git('rev-parse','HEAD:src'),'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY','mastercoverage_promotion':False}
def main():
 a=argparse.ArgumentParser();a.add_argument('--self-test',action='store_true');args=a.parse_args()
 if not args.self_test:print(json.dumps(verify_qualification(),indent=2));return
 g=json.loads((ROOT/STATUS).read_text())['historical_guard'];h=archive(g['physical_evidence']);p=archive(g['retained_evidence']);validate(h,p);controls=[]
 def reject(label,hh,pp,reader=lambda q:(ROOT/q).read_bytes()):
  try:validate(hh,pp,reader)
  except(ValueError,KeyError,IndexError):controls.append(label);return
  raise AssertionError('accepted '+label)
 hh=dict(h);hh['nut-hist-capacity-qualified/O2/rotation-fresh-365']+=b'x';reject('transition payload',hh,p)
 hh=dict(h);hh['nut-hist-capacity-qualified/O0/rotation-profile.restart.reject-after-120']+=b'x';reject('rejected state',hh,p)
 hh=dict(h);e=json.loads(hh['nut-hist-capacity-qualified/events.json']);hh['nut-hist-capacity-qualified/events.json']=json.dumps([x for x in e if x['category']!='restart_native']).encode();reject('missing fresh process',hh,p)
 hh=dict(h);e=json.loads(hh['nut-hist-capacity-qualified/events.json']);e[0]['command'].remove('-fcheck=all');hh['nut-hist-capacity-qualified/events.json']=json.dumps(e).encode();reject('unchecked provider',hh,p)
 pp=dict(p);e=json.loads(pp['joint/events.json']);pp['joint/events.json']=json.dumps([x for x in e if x['category']!='native']).encode();reject('missing retained native',h,pp)
 pp=dict(p);r=json.loads(pp['phases/result.json']);r['events']=[e for e in r['events']if e['category']!='native'];pp['phases/result.json']=json.dumps(r).encode();reject('missing thermal native',h,pp)
 pp=dict(p);r=json.loads(pp['tcs6/result.json']);r['runs']=r['runs'][:-1];pp['tcs6/result.json']=json.dumps(r).encode();reject('missing TCS6',h,pp)
 q='src/process/mod_b111_soil_n_mineral_owner.f90';reject('body drift',h,p,lambda x:(ROOT/x).read_bytes()+(b'!'if x==q else b''))
 print(json.dumps({'HIST_GUARD_NEGATIVE_CONTROLS':controls,'count':len(controls)}))
if __name__=='__main__':main()
