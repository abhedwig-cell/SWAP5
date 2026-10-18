"""Bounded HIST owner admission using current executions and immutable references."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
BASE='d4912b3c37461ad918f37c53b236fa1d62478de6'
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

def validate(h,p,reader=lambda q:(ROOT/q).read_bytes(),atmospheric=False,humus=False):
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
 require(not humus or atmospheric,'humus atmospheric dependency')
 profiles=['source-profile','rotation-profile']+(['atmospheric-profile']if atmospheric else[])+(['humus-profile']if humus else[])
 for opt in ['O0','O2']:
  for q in r['input_sha256']:
   if q.startswith('src/')and q.endswith('.f90'):require(sum('-'+opt in c and c[c.index('-c')+1].endswith('/'+q)for c in objects.values())==1,'missing HIST provider '+q)
  for profile in profiles:
   matches=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and e['command'][1]=='write'and e['command'][-1]==profile]
   require(len(matches)==1 and h['nut-hist-capacity-qualified/'+matches[0]['stdout']].decode()==r['results'][opt]['stdout'][profile],'HIST raw native result')
  prefix='nut-hist-capacity-qualified/'+opt+'/'
  for profile in profiles[1:]:
   end=h[prefix+profile+'.endpoint'];require(sha(end)==r['results'][opt]['endpoint'][profile],'HIST endpoint digest')
   for d in [1,120,121,365,366,500]:
    fresh=(profile+'-fresh-'if atmospheric else'rotation-fresh-')+str(d)
    require(end==h[prefix+fresh],'HIST fresh endpoint')
    require(sum(e['category']=='restart_native'and'/'+opt+'/'in e['command'][0]and e['command'][-2:]==[profile,str(d)]for e in events)==1,'missing HIST fresh process')
   for d in [120,366]:
    before=h[prefix+profile+'.restart.reject-before-'+str(d)]
    require(before==h[prefix+profile+'.restart.reject-after-'+str(d)],'HIST rejected state')
    if profile in ['atmospheric-profile','humus-profile']:require(before==h[prefix+profile+'.restart.clean-reject-'+str(d)],'atmospheric clean-only publication')
  require(h[prefix+'default.endpoint']==h[prefix+'default.fresh']==h[prefix+'default.endpoint.opaque'],'HIST default restart');require(h[prefix+'source-profile.endpoint']==h[prefix+'source-profile.fresh'],'HIST source restart')
 n=result(h,'nut-native-capacity-final');inputs(n);require(n['status']=='PASS'and len(n['fixtures'])==(38 if humus else 25 if atmospheric else 24) and n['outputs']['O0']==n['outputs']['O2'],'HIST parser matrix')
 ne=json.loads(h['nut-native-capacity-final/events.json']);require(sum(e['category']=='native'for e in ne)==(76 if humus else 50 if atmospheric else 48) and all(e['returncode']==0 for e in ne),'HIST parser native')
 o=result(h,'nut-ttutil-final3');require(o['status']=='ORIGINAL_TTUTIL_O0_O2_PASS'and o['results']['O0']==o['results']['O2'],'HIST TTUTIL');require(o['runner_sha256']==sha(reader('tests/nut-input/run_ttutil_native_oracle.py')),'HIST oracle drift');require(o['authority_zip_sha256']==sha(base64.b64decode(reader('integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64'))),'HIST TTUTIL authority')
 for q,d in o['fixture_sha256'].items():require(n['fixtures'][q]==d,'HIST source fixture')
 oe=json.loads(h['nut-ttutil-final3/events.json']);require(sum(e['category']=='native'for e in oe)==(20 if humus else 8),'TTUTIL actual native inventory')
 require(sum(e['category']=='negative_native'for e in oe)==2,'TTUTIL source scalar negative inventory')
 for i,e in enumerate(oe):
  stdout=h['nut-ttutil-final3/'+str(i).zfill(4)+'.stdout'].decode()
  if e['category']=='negative_native':require(e['returncode']!=0 and 'variable is scalar'in stdout,'TTUTIL source scalar rejection')
  else:require(e['returncode']==0,'TTUTIL checked execution')
  if e['category']=='native':require('ORIGINAL_TTUTIL_TYPED_ARRAY_TABLE_DATE_INTERPRETATION=PASS'in stdout,'TTUTIL raw interpretation')
  if e['category']=='native'and Path(e['command'][1]).stem.startswith('hum_'):require('ORIGINAL_TTUTIL_OPTIONAL_HUMUS_RATE_DATE=PASS'in stdout,'TTUTIL raw humus interpretation')
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
 if atmospheric:
  a=result(p,'atmospheric-audit');inputs(a)
  require(a['profile']=='atmospheric-profile'and a['status']=='HIST_OBSERVATIONAL_WATER_N_AUDIT_PASS'and a['provider_result_sha256']==sha(h['nut-hist-capacity-qualified/result.json']),'atmospheric water audit binding')
  require(a['results']['O0']==a['results']['O2'],'atmospheric water audit optimization')
  for opt in ['O0','O2']:
   require(p['atmospheric-audit/'+opt+'/endpoint']==h['nut-hist-capacity-qualified/'+opt+'/atmospheric-profile.endpoint'],'atmospheric audit changed physics')
   m=a['results'][opt]['metrics'];require(abs(m['AUDIT_WATER_CM'][-1])<=1e-10,'atmospheric water budget')
   boundary=m['AUDIT_BOUNDARY_N_KG_M2'];require(boundary[0]>0 and abs(sum(boundary)-m['AUDIT_N_KG_M2'][2])<=1e-12,'atmospheric input accounting')
  ae=json.loads(p['atmospheric-audit/events.json']);require(sum(e['category']=='native'for e in ae)==2 and all(e['returncode']==0 for e in ae),'atmospheric audit execution')
  w=result(h,'boundary-witness');require(w['status']=='ORIGINAL_BOUNDARY_B0_DEFECT_B1_SINGLE_TARGET_FIX_O0_O2_PASS'and w['results']['O0']==w['results']['O2'],'original boundary defect witness')
  require(w['runner_sha256']==sha(reader('tests/nut-input/run_boundary_source_witness.py')),'boundary witness body drift')
  ee=json.loads(h['boundary-witness/events.json']);require(sum(e['category']=='native'for e in ee)==4 and all(e['returncode']==0 for e in ee),'boundary witness execution')
  for e in [e for e in ee if e['category']=='native']:require(any(tag in h['boundary-witness/'+e['stdout']].decode()for tag in ['B0_SEEP_OVERWRITES_LATERAL_DESTINATION=CONFIRMED','B1_DISTINCT_TOP_LATERAL_BOTTOM_CONCENTRATIONS=PASS']),'boundary witness raw output')
  for name in ['mineral','reactive']:
   d=result(h,'atmospheric-'+name);inputs(d)
   require(d['status']=='DIRECT_PASS'and d['runs']['O0']==d['runs']['O2'],'atmospheric direct '+name)
   ee=json.loads(h['atmospheric-'+name+'/events.json']);require(sum(e['category']=='direct_native'for e in ee)==2 and all(e['returncode']==0 for e in ee),'atmospheric direct executions')
   marker='MINERAL_ATMOSPHERIC_LITERAL_SORPTION_EVAPORATION_PARAMETER_IDENTITY=PASS'if name=='mineral'else'REACTIVE_ATMOSPHERIC_ORIGINAL_CHEMISTRY_EVAPORATION_RESTART=PASS'
   for e in [e for e in ee if e['category']=='direct_native']:require(marker in h['atmospheric-'+name+'/'+e.get('stdout',e.get('stdout_file'))].decode(),'atmospheric direct raw output')
  with tarfile.open(fileobj=io.BytesIO(base64.b64decode(reader('integration/audits/evidence/MC_NUT01_HIST_NATIVE_ROTATION_20261018.tar.xz.b64'))))as t:
   for opt in ['O0','O2']:
    for name in ['default.endpoint','source-profile.endpoint','rotation-profile.endpoint']:
     q='nut-hist-capacity-qualified/'+opt+'/'+name
     require(h[q]==t.extractfile(q).read(),'zero-top admitted physical endpoint drift')
 if humus:
  material=result(h,'nut-material-a5');inputs(material)
  require(material['status']=='PASS'and material['runs']['O0']==material['runs']['O2'],'conservative residue material matrix')
  me=json.loads(h['nut-material-a5/events.json']);require(sum(e['category']=='native'for e in me)==2 and all(e['returncode']==0 for e in me),'residue material native inventory')
  for e in [e for e in me if e['category']=='native']:
   raw=h['nut-material-a5/'+e.get('stdout',e.get('stdout_file'))].decode()
   require('RESIDUE_ONE_TO_EIGHT_SPACING_N_COMPENSATION_ORIGINAL_EDGE_ROLLBACK=PASS'in raw,'conservative residue original-edge and unavailable-N rollback')
  c=result(h,'humus-clock');require(c['status']=='ORIGINAL_HUMUS_CALLER_ENDPOINT_CLOCK_O0_O2_PASS'and c['results']['O0']==c['results']['O2'],'humus original caller witness')
  require(c['runner_sha256']==sha(reader('tests/nut-input/run_humus_clock_witness.py')),'humus clock runner drift')
  require(c['clock_authority_sha256']==sha(base64.b64decode(reader('integration/audits/evidence/SWAP431_HUMUS_CLOCK_AUTHORITY.tar.xz.b64'))),'humus clock authority')
  ee=json.loads(h['humus-clock/events.json']);require(sum(e['category']=='native'for e in ee)==2 and all(e['returncode']==0 for e in ee),'humus clock execution')
  for e in [e for e in ee if e['category']=='native']:require('ORIGINAL_HUMUS_ENDPOINT_CLOCK_SWITCH=PASS'in h['humus-clock/'+e['stdout']].decode(),'humus raw clock witness')
  ee=json.loads(h['atmospheric-reactive/events.json'])
  for e in [e for e in ee if e['category']=='direct_native']:require('REACTIVE_ORIGINAL_HUMUS_SWITCH_THRESHOLD_18_DAYS_OPAQUE=PASS'in h['atmospheric-reactive/'+e.get('stdout',e.get('stdout_file'))].decode(),'humus original chemistry threshold proof')
  a=result(p,'humus-audit');inputs(a)
  require(a['profile']=='humus-profile'and a['status']=='HIST_OBSERVATIONAL_WATER_N_AUDIT_PASS'and a['provider_result_sha256']==sha(h['nut-hist-capacity-qualified/result.json']),'humus water audit binding')
  require(a['results']['O0']==a['results']['O2'],'humus audit optimization')
  for opt in ['O0','O2']:
   require(p['humus-audit/'+opt+'/endpoint']==h['nut-hist-capacity-qualified/'+opt+'/humus-profile.endpoint'],'humus audit changed physics')
   m=a['results'][opt]['metrics'];require(abs(m['AUDIT_WATER_CM'][-1])<=1e-10,'humus cumulative water')
   require(abs(sum(m['AUDIT_BOUNDARY_N_KG_M2'])-m['AUDIT_N_KG_M2'][2])<=1e-12,'humus boundary nitrogen')
  ee=json.loads(p['humus-audit/events.json']);require(sum(e['category']=='native'for e in ee)==2 and all(e['returncode']==0 for e in ee),'humus audit fresh execution')
  with tarfile.open(fileobj=io.BytesIO(base64.b64decode(reader('integration/audits/evidence/MC_NUT01_HIST_ATMOSPHERIC_N_20261018.tar.xz.b64'))))as t:
   for opt in ['O0','O2']:
    q='nut-hist-capacity-qualified/'+opt+'/atmospheric-profile.endpoint';require(h[q]==t.extractfile(q).read(),'old atmospheric native byte drift')
 inherited=json.loads(p['inherited.json'])
 for q,d in inherited['source_sha256'].items():require(sha(reader(q))==d,'classic inherited drift '+q)
 require(inherited['annual_source_pass']and inherited['annual_codec_bytes_pass'],'classic preservation')
 return dict(local_physical_days=730,parser_cases=38 if humus else 25 if atmospheric else 24,transition_fresh_processes=36 if humus else 24 if atmospheric else 12,atmospheric_n=atmospheric,humus_experiment=humus,rollback_days=[120,366],full_retained_matrix=True,thermal=True,tcs6_native=54)

def load():
 g=json.loads((ROOT/STATUS).read_text())['historical_guard'];require(g['baseline']==BASE,'HIST baseline')
 science=validate(archive(g['physical_evidence']),archive(g['retained_evidence']),atmospheric=g.get('atmospheric_n',False),humus=g.get('humus_experiment',False))
 for q,v in g['postimages'].items():require(sha((ROOT/q).read_bytes())==v['sha256'],'HIST postimage '+q)
 surface=['src','tests','tools','reference','.github'];require(not git('status','--porcelain','--',*surface),'dirty HIST science')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*surface).splitlines()}
 require(rows=={q:v['status']for q,v in g['postimages'].items()},'foreign HIST delta')
 require(not git('diff',BASE,'--','reference'),'HIST reference mutation')
 coexist=g.get('surface_age_coexistence')
 if coexist:
  require(coexist['admitted_canonical']==BASE,'unregistered age coexistence baseline')
  age_status=ROOT/coexist['status_path'];require(sha(age_status.read_bytes())==coexist['status_sha256'],'age admission record drift')
  import sys
  sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_surface_age_successor as age
  shared=set(coexist['shared_dispatch_paths'])
  require(shared=={'tests/nut-crop/verify_hist_native_successor.py','tests/nut-sol/verify_surface_age_successor.py'},'age coexistence dispatch surface')
  for q,v in age.record()['postimages'].items():
   if q in shared:require(q in g['postimages'],'unbound shared owner dispatch')
   else:require(sha((ROOT/q).read_bytes())==v['sha256'],'age owner postimage drift '+q)
  age.validate(age.evidence())
  science['surface_age_preserved']=True
 return science

def verify_source(git_reader=None):
 require(git_reader is None,'unregistered HIST projection');return {**load(),'historical_native_successor':True,'b112_retained_successor':True,'full_capability':False,'qualified':False,'current_source_tree':git('rev-parse','HEAD:src')}
def verify_qualification():return {**load(),'historical_native_successor':True,'b112_retained_successor':True,'qualified':True,'full_capability':False,'current_source_tree':git('rev-parse','HEAD:src'),'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY','mastercoverage_promotion':False}
def main():
 a=argparse.ArgumentParser();a.add_argument('--self-test',action='store_true');args=a.parse_args()
 if not args.self_test:print(json.dumps(verify_qualification(),indent=2));return
 g=json.loads((ROOT/STATUS).read_text())['historical_guard'];h=archive(g['physical_evidence']);p=archive(g['retained_evidence']);atmospheric=g.get('atmospheric_n',False);humus=g.get('humus_experiment',False);validate(h,p,atmospheric=atmospheric,humus=humus);controls=[]
 def reject(label,hh,pp,reader=lambda q:(ROOT/q).read_bytes()):
  try:validate(hh,pp,reader,atmospheric=atmospheric,humus=humus)
  except(ValueError,KeyError,IndexError):controls.append(label);return
  raise AssertionError('accepted '+label)
 hh=dict(h);hh['nut-hist-capacity-qualified/O2/'+('atmospheric-profile-fresh-365'if atmospheric else'rotation-fresh-365')]+=b'x';reject('transition payload',hh,p)
 hh=dict(h);hh['nut-hist-capacity-qualified/O0/rotation-profile.restart.reject-after-120']+=b'x';reject('rejected state',hh,p)
 hh=dict(h);e=json.loads(hh['nut-hist-capacity-qualified/events.json']);hh['nut-hist-capacity-qualified/events.json']=json.dumps([x for x in e if x['category']!='restart_native']).encode();reject('missing fresh process',hh,p)
 hh=dict(h);e=json.loads(hh['nut-hist-capacity-qualified/events.json']);e[0]['command'].remove('-fcheck=all');hh['nut-hist-capacity-qualified/events.json']=json.dumps(e).encode();reject('unchecked provider',hh,p)
 pp=dict(p);e=json.loads(pp['joint/events.json']);pp['joint/events.json']=json.dumps([x for x in e if x['category']!='native']).encode();reject('missing retained native',h,pp)
 pp=dict(p);r=json.loads(pp['phases/result.json']);r['events']=[e for e in r['events']if e['category']!='native'];pp['phases/result.json']=json.dumps(r).encode();reject('missing thermal native',h,pp)
 pp=dict(p);r=json.loads(pp['tcs6/result.json']);r['runs']=r['runs'][:-1];pp['tcs6/result.json']=json.dumps(r).encode();reject('missing TCS6',h,pp)
 q='src/process/mod_b111_soil_n_mineral_owner.f90';reject('body drift',h,p,lambda x:(ROOT/x).read_bytes()+(b'!'if x==q else b''))
 if atmospheric:
  hh=dict(h);hh['nut-hist-capacity-qualified/O0/atmospheric-profile.restart.clean-reject-120']+=b'x';reject('clean-only state leak',hh,p)
  hh=dict(h);e=json.loads(hh['nut-hist-capacity-qualified/events.json']);hh['nut-hist-capacity-qualified/events.json']=json.dumps([x for x in e if 'atmospheric-profile'not in x['command']]).encode();reject('missing atmospheric execution',hh,p)
  pp=dict(p);a=json.loads(pp['atmospheric-audit/result.json']);a['results']['O0']['metrics']['AUDIT_BOUNDARY_N_KG_M2'][0]=0;pp['atmospheric-audit/result.json']=json.dumps(a).encode();reject('missing atmospheric input',h,pp)
  hh=dict(h);w=json.loads(hh['boundary-witness/result.json']);w['status']='PASS';hh['boundary-witness/result.json']=json.dumps(w).encode();reject('unqualified source correction',hh,p)
 if humus:
  hh=dict(h);hh['nut-hist-capacity-qualified/O2/humus-profile-fresh-366']+=b'x';reject('humus transition drift',hh,p)
  hh=dict(h);e=json.loads(hh['humus-clock/events.json']);hh['humus-clock/events.json']=json.dumps([x for x in e if x['category']!='native']).encode();reject('missing original clock execution',hh,p)
  hh=dict(h);e=json.loads(hh['nut-ttutil-final3/events.json']);hh['nut-ttutil-final3/events.json']=json.dumps([x for x in e if not(x['category']=='native'and Path(x['command'][1]).stem.startswith('hum_'))]).encode();reject('missing original humus input execution',hh,p)
  pp=dict(p);pp['humus-audit/O0/endpoint']+=b'x';reject('humus observational state drift',h,pp)
 if humus:
  hh=dict(h);e=json.loads(hh['nut-material-a5/events.json']);hh['nut-material-a5/events.json']=json.dumps([x for x in e if x['category']!='native']).encode();reject('missing residue correction execution',hh,p)
  hh=dict(h);e=json.loads(hh['nut-material-a5/events.json']);row=next(x for x in e if x['category']=='native');q='nut-material-a5/'+row.get('stdout',row.get('stdout_file'));hh[q]=b'PASS';reject('missing conservative residue proof',hh,p)
 print(json.dumps({'HIST_GUARD_NEGATIVE_CONTROLS':controls,'count':len(controls)}))
if __name__=='__main__':main()
