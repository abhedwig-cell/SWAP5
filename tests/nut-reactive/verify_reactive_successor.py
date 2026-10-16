#!/usr/bin/env python3
"""Exact reactive postimage, original-reference correction, and terminal proofs."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2];BASE='eb03024d99ef9256335eb6e2f3f74bccce8145f0'
PEER='9ed5efc773b28f44b16b8922730b3fd9b8892b60'
QUALIFIED_SOURCE='6839bb0ddc6be7a6be81954206ee3f7e6cc5a975'
STATUS='integration/audits/MC_NUT01_REACTIVE_DAY_STATUS.json'
CHANGED=['tests/crop-co2/verify_co2_successor.py','src/process/mod_b111_soil_n_mineral_owner.f90','src/runtime/mod_fmr_b111_mineral_route.f90','tests/nut-mineral/verify_mineral_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh']
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def verify_source():
 if (ROOT/'src/crop/mod_crop_soil_n_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-crop'))
  import verify_crop_supply_successor as crop_supply
  return crop_supply.verify_source()
 s=json.loads((ROOT/STATUS).read_text());git('merge-base','--is-ancestor',PEER,'HEAD')
 check(s['baseline']==BASE,'unknown baseline')
 check(not git('status','--porcelain','--','src','tests','tools','reference'),'dirty dependency surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',PEER,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in CHANGED})
 check(rows==expected,'foreign reactive delta');check(set(s['changed_blobs'])==set(CHANGED),'changed seam coverage')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():
  check(git('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown postimage '+p)
 check(git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference'),'global reference mutation')
 return dict(baseline=BASE,source_tree=QUALIFIED_SOURCE,current_source_tree=git('rev-parse','HEAD:src'),canonical_peer=PEER,reactive_successor=True,qualified=False,admitted=False)
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text());raw=base64.b64decode((ROOT/s['evidence']['path']).read_bytes())
 check(hashlib.sha256(raw).hexdigest()==s['evidence']['sha256'],'capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as a:
  rows=a.getmembers();check(all(r.isfile()and not r.name.startswith('/')and'..'not in Path(r.name).parts for r in rows),'unsafe archive')
  check(len({r.name for r in rows})==len(rows),'duplicate evidence')
  data={r.name:a.extractfile(r).read()for r in rows}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(manifest)==set(data),'manifest coverage')
 for p,h in manifest.items():check(hashlib.sha256(data[p]).hexdigest()==h,'member drift '+p)
 return data

def verify_qualification():
 if (ROOT/'src/crop/mod_crop_soil_n_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-crop'))
  import verify_crop_supply_successor as crop_supply
  return crop_supply.verify_qualification()
 source=verify_source()
 sys.path.insert(0,str(ROOT/'tests/crop-co2'))
 from verify_co2_successor import nonlinear_evidence
 nonlinear_evidence() # exact unchanged independently admitted matrix physics
 data=read_evidence();r=json.loads(data['result.json']);events=json.loads(data['events.json'])
 check(r['status']=='SCOPED_REACTIVE_QUALIFICATION_PASS_NOT_ADMITTED','unfinished qualification')
 check(r['source_tree']==source['source_tree'],'stale source tree')
 repair=r['reference_correction']
 record=json.loads((ROOT/'integration/audits/MC_NUT01_ORGANIC_REFERENCE_TRANSFORM_20261015.json').read_text())
 for key,value in repair.items():check(record[key]==value,'reference manifest drift '+key)
 check(repair['reference']=='MC-NUT01-R1'and repair['replacement_count']==1 and repair['global_reference_manifest_changed']is False,'unknown corrected reference')
 check(repair['preimage_sha256']=='85146e95249b41ed9b5202b507cb1647784592a313e36e75010da9bbf9a733f6','unbound original reference')
 for p,h in r['input_sha256'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'physical input drift '+p)
 s=json.loads((ROOT/STATUS).read_text());production={p for p in [*s['added_blobs'],*s['changed_blobs']]if p.startswith('src/')}
 check(production<=r['input_sha256'].keys(),'untested production')
 check(r['o0_o2_endpoint_identity']is True,'optimization endpoint mismatch')
 for opt in ['O0','O2']:
  row=r['runs'][opt]
  check('ORIGINAL_ORGANIC_REFERENCE_DEFECT_WITNESS=PASS'in row['reference']['legacy'],'original defect not demonstrated')
  check('CORRECTED_ORGANIC_REFERENCE_WHOLE_N=PASS'in row['reference']['corrected'],'B1 correction not qualified')
  reference_events=[e for e in events if e['category']=='reference_native'and '/'+opt+'/'in e['command'][0]]
  check(len(reference_events)==2,'reference qualification missing')
  for e,mode in zip(reference_events,['legacy','corrected']):
   check(e['command'][1]==mode and data[e['stdout_file']].decode()==row['reference'][mode],'reference native evidence mismatch')
  before=[i for i,e in enumerate(events)if e in reference_events]
  direct=[i for i,e in enumerate(events)if e['category']=='direct_compile'and '-'+opt in e['command']]
  check(before and direct and max(before)<min(direct),'B1 correction was not qualified before production')
  for name,h in r['authority'].items():
   if name=='wofost_soil_orgmatn.f90':continue
   check(hashlib.sha256(data[opt+'/'+name]).hexdigest()==h,'literal source drift '+name)
  old=data[opt+'/orgmatn_original.f90'];fixed=data[opt+'/wofost_soil_orgmatn.f90']
  check(hashlib.sha256(old).hexdigest()==repair['preimage_sha256']and hashlib.sha256(fixed).hexdigest()==repair['postimage_sha256'],'reference transform digest')
  a=repair['exact_preimage'].encode();b=repair['exact_postimage'].encode()
  check(old.count(a)==1 and old.replace(a,b)==fixed,'nonlocal reference repair')
  check(row['direct_production_provider_count']==13,'direct closure changed')
  check('REACTIVE_LITERAL_16_ENVIRONMENTS_TRANSPORT_OFF_MASS_IMMOBILISATION_RESTART=PASS'in row['direct_stdout'],'direct physical oracle missing')
  check('REACTIVE_ACTUAL_LITERAL_AND_NINE_CARRIER_NEGATIVES=PASS'in row['physical_stdout'],'actual carrier oracle absent')
  check('REACTIVE_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS'in row['physical_stdout'],'actual joint route absent')
  for p in ['expected.bin','fresh.bin','expected.bin.opaque']:
   check(hashlib.sha256(data[opt+'/'+p]).hexdigest()==row['fresh_endpoint_sha256'],'reactive restart endpoint drift')
  check(data[opt+'/expected.bin.off-old']==data[opt+'/expected.bin.off-new'],'off physical mismatch')
  check(row['incumbent_admitted_byte_identity']is True,'incumbent regression absent')
  for p in ['mineral-expected.bin','mineral-fresh.bin','mineral-expected.bin.opaque']:
   check(hashlib.sha256(data[opt+'/'+p]).hexdigest()==row['incumbent_endpoint_sha256'],'incumbent restart drift')
  cap=ROOT/'integration/audits/evidence/MC_NUT01_MINERAL_TRANSPORT_20261015.tar.xz.b64'
  with tarfile.open(fileobj=io.BytesIO(base64.b64decode(cap.read_bytes())),mode='r:xz')as archive:
   check(data[opt+'/mineral-expected.bin']==archive.extractfile(opt+'/expected.bin').read(),'admitted endpoint mismatch')
  for category,negatives,marker in [('physical_native',row['corruption_negatives'],'REACTIVE_INVALID_DISK=PASS'),('incumbent_native',row['incumbent_decoder_negatives'],'MINERAL_INVALID_DISK=PASS')]:
   es=[e for e in events if e['category']==category and '/'+opt+'/'in e['command'][0]]
   check(len(es)==12 and len(negatives)==10,'incomplete native/negative matrix')
   check(es[0]['command'][1]=='write'and es[1]['command'][1]=='resume','native execution ordering')
   for e in es[2:]:check(marker in data[e['stdout_file']].decode(),'decoder rejection absent')
  compiled=[e['command']for e in events if e['category']=='physical_compile'and '-'+opt in e['command']]
  for p in production:check(sum(c[c.index('-c')+1].endswith('/'+p)for c in compiled)==1,'compiled provider missing '+p)
 base_direct=json.loads(data['mineral_direct/result.json'])
 check(base_direct['status']=='DIRECT_PASS'and base_direct['source_tree']==source['source_tree'],'original small closure stale')
 for p,h in base_direct['input_sha256'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'original small input drift '+p)
 for opt in ['O0','O2']:
  row=base_direct['runs'][opt]
  check(row['direct_production_provider_count']==4,'original small closure expanded')
  check('MINERAL_FOUR_PROVIDER_LITERAL_ALL_CLASSES_OWNER_BALANCE_ROLLBACK_RESTART=PASS'in row['direct_stdout'],'original small driver missing')
 edge=json.loads(data['edges/result.json']);edge_events=json.loads(data['edges/events.json'])
 check(edge['status']=='PASS'and edge['source_tree']==source['source_tree'],'edge qualification stale')
 check(edge['primary_result_sha256']==hashlib.sha256(data['result.json']).hexdigest(),'edges bind different primary run')
 for p,h in edge['input_sha256'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'edge input drift '+p)
 for opt in ['O0','O2']:
  row=edge['runs'][opt]
  check(row['process_provider_count']==13,'edge process closure')
  check('REACTIVE_SUCCESSFUL_IMMOBILISATION_INTERNAL_NITRIFICATION_WATER_COUNTER=PASS'in row['stdout'],'edge physics absent')
  check(row['physics_configuration_negatives']==['organic_rate','reaction_temperature','enabled_mode'],'physics config negative coverage')
  es=[e for e in edge_events if e['category']=='decoder_native'and '/'+opt+'/'in e['command'][0]]
  check(len(es)==3,'physics config native coverage')
  for e in es:check('REACTIVE_INVALID_DISK=PASS'in data['edges/'+e['stdout_file']].decode(),'physics config rejection absent')
 for e in edge_events:
  check(e['returncode']==0,'failed edge event')
  for stream in ['stdout','stderr']:check(hashlib.sha256(data['edges/'+e[stream+'_file']]).hexdigest()==e[stream+'_sha256'],'edge raw event mismatch')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed qualification event')
  for stream in ['stdout','stderr']:check(hashlib.sha256(data[e[stream+'_file']]).hexdigest()==e[stream+'_sha256'],'raw event mismatch')
 return {**source,'qualified':True,'direct_providers':13,'highest':'NOT_SELECTED_POLICY'}
def incumbent(mode='qualification'):
 if (ROOT/'src/crop/mod_crop_soil_n_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-crop'))
  import verify_crop_supply_successor as crop_supply
  return crop_supply.incumbent(mode)
 verify_qualification()
 base=ROOT.parent/'nut-reactive-peer-9ed5efc7'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),PEER],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==PEER,'baseline head changed')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'dirty baseline')
 args=[sys.executable,'-B',str(base/'tests/crop-co2/verify_co2_successor.py')]
 if mode!='qualification':args.append('--source-only'if mode=='source'else'--physical-only')
 result=subprocess.run(args,cwd=base,capture_output=True,text=True,check=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return {**json.loads(result.stdout),'reactive_successor':True,'reactive_source_tree':git('rev-parse','HEAD:src'),'reactive_baseline':BASE}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent',choices=['source','physical','qualification']);a=p.parse_args()
 print(json.dumps(incumbent(a.incumbent)if a.incumbent else verify_source()if a.source_only else verify_qualification(),indent=2))
