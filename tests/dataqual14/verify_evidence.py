"""Verify actual source-bound active Grassgrowth qualification without scratch dependencies."""
import csv,hashlib,io,json,struct,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda b:hashlib.sha256(b).hexdigest()
def verify():
 s=json.loads((ROOT/'integration/dataqual14/STATUS.json').read_text())
 # Closed reviewed production delta. A portable archive can verify the bound
 # capsule; current Git feedback additionally rejects any unreviewed source.
 if (ROOT/'.git').exists():
  delta=subprocess.check_output(['git','diff','--name-status',s['baseline'],'HEAD','--','src','app','reference'],cwd=ROOT,text=True).splitlines()
  assert {r.split('\t')[1]:r.split('\t')[0] for r in delta}==s['reviewed_production_delta'],'unreviewed production delta'
  assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT),'uncommitted production source'

 for p,h in s['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 b=(ROOT/'integration/dataqual14/EVIDENCE.tar.xz').read_bytes();assert sha(b)==s['evidence_sha256']
 with tarfile.open(fileobj=io.BytesIO(b),mode='r:xz')as t:
  members=t.getmembers();assert len({m.name for m in members})==len(members)
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  f={m.name:t.extractfile(m).read()for m in members}
 assert json.loads(f.pop('MANIFEST.json'))=={n:sha(b)for n,b in f.items()}
 def bound(p,h):
  if '/SWAP5-dq14/'in p:p=p.split('/SWAP5-dq14/',1)[1]
  if not Path(p).is_absolute():assert sha((ROOT/p).read_bytes())==h,p
  else:assert any(sha(b)==h for b in f.values()),p
 def result(folder):return json.loads(f[folder+'/RESULT.json'])
 def rows(n):return list(csv.DictReader(io.StringIO(f[n].decode())))
 for opt in ['O0','O2']:
  r=result('dq14-qualification-'+opt);assert r['status']=='ACTIVE_ORIGINAL_GRASS_WATER_ROOT_AND_DISK_RESTART_PASS'
  assert r['days']==68 and r['restart_payload_exact'] and r['rejected_restart_controls']==6
  assert r['maximum_water_residual_cm']<1e-10 and r['maximum_heat_accounting_residual_j_cm2']<1e-8
  for p,h in r['source_sha256'].items():bound(p,h)
  base='dq14-qualification-'+opt+'/'
  for n in ['checkpoint.bin','state.csv','endpoint.csv']:assert f[base+'full/'+n]==f[base+'suffix/'+n]
  full=rows(base+'full/budget.csv');suffix=rows(base+'suffix/budget.csv');assert full[63:]==suffix
  crop=rows(base+'full/crop.csv');assert len(crop)==68 and float(crop[-1]['rd'])==22 and float(crop[-1]['rdpot'])==22
  assert any(float(q['grrt'])>0 for q in crop[63:])
 for n in ['budget.csv','state.csv','endpoint.csv','crop.csv']:
  assert f['dq14-qualification-O0/full/'+n]==f['dq14-qualification-O2/full/'+n],n
 r=result('dq14-root-oracle');assert r['status']=='ORIGINAL_SWRD2_ACTIVE_ROOT_PASS'
 for p,h in r['source_sha256'].items():bound(p,h)
 for opt in ['O0','O2']:assert b'108'in f['dq14-root-oracle/'+opt+'/stdout']
 r=result('dq14-runtime-preservation-final');assert r['status']=='CURRENT_REFERENCE_GROUNDWATER_DEFAULT_AND_OXYGEN_PASS'
 assert len([e for e in r['events']if e['label']=='native_existing_contract'])==6
 assert all(e['returncode']==0 for e in r['events'])
 for p,h in r['source_sha256'].items():bound(p,h)
 old={int(q['day']):q for n,b in f.items()if n.startswith('inherited/')for q in rows(n)}
 current=rows('dq14-qualification-O2/full/budget.csv');assert all(current[i-1]==q for i,q in old.items())
 ref=list(csv.DictReader(l for l in f['dq14-reference/result_output.csv'].decode().splitlines()if l and not l.startswith('*')))
 c=rows('dq14-qualification-O2/full/crop.csv')
 for q in c:
  day=int(q['day'])
  for field,name in [('wrt','WRT'),('pwrt','PWRT'),('wlv','WLV'),('wst','WST'),('wso','WSO'),('rd','RD'),('rdpot','RDPOT')]:
   assert abs(float(q[field])-float(ref[day][name]))<1e-9,(day,field)
 # A restart with distinct actual/potential biomass and one with distinct
 # root depths must preserve the subsequent physical trajectories exactly.
 for a,b in [('dq14-original-year-O2','dq14-stressed-suffix-O2'),('dq14-stressed-prefix-O2','dq14-distinct-roots-suffix-O2')]:
  for n in ['checkpoint.bin','state.csv','endpoint.csv']:assert f[a+'/'+n]==f[b+'/'+n],(a,n)
 assert rows('dq14-distinct-roots-prefix-O2/crop.csv')[-1]['rd']!=rows('dq14-distinct-roots-prefix-O2/crop.csv')[-1]['rdpot']
 stressed=rows('dq14-stressed-prefix-O2/crop.csv')[-1];assert stressed['wrt']!=stressed['pwrt']
 long=result('dq14-original-year-O2');assert long['completed_days']==113 and long['returncode']==1
 assert 'time-varying original groundwater'in long['reason']
 for p,h in long['source_sha256'].items():bound(p,h)
 # Independently inspect the persisted potential owner endpoint; retained dead
 # biomass has two entries. This is no additional model route or model run.
 raw=f['dq14-original-year-O2/checkpoint.bin'];pos=8
 for i in range(6):size=struct.unpack_from('=i',raw,pos)[0];pos+=4+size
 nodes=struct.unpack_from('=i',raw,pos)[0];pos+=48+nodes*40+32
 for kind in ['actual','potential']:
  dvs,count=struct.unpack_from('=di',raw,pos);v=struct.unpack_from('=9d',raw,pos+12)
  leaves=sum(struct.unpack_from('='+str(count)+'d',raw,pos+84));pos+=164+24*count
  if kind=='potential':
   for value,name in [(v[0],'PWRT'),(v[1],'PWST'),(v[2],'PWSO'),(leaves,'PWLV')]:assert abs(value-float(ref[113][name]))<1e-9,name
 assert pos+20==len(raw)
 m=json.loads((ROOT/'integration/dataqual12/MIGRATION_MATRIX.json').read_text())
 assert m['denominator']['independent_original_projects']==3 and m['denominator']['complete_project_migrations']==0
 return dict(status='SOURCE_BOUND_ACTIVE_ORIGINAL_GRASS_PASS',water_restart_qualified_days=68,active_days=5,executed_days=113,O2_stressed_restart_exact=True,original_project_denominator=3,complete_migrations=0)
if __name__=='__main__':print(json.dumps(verify()))
