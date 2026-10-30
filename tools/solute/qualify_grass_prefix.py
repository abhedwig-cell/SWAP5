#!/usr/bin/env python3
"""Qualify one original Grassgrowth prefix with same-build disk continuation.

Real production application only. Original inputs remain byte-exact. Historical
state differences are measured, never promoted to a full4.3.1 equivalence PASS.
"""
import argparse,csv,hashlib,json,math,shutil,struct,subprocess,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--days',type=int,default=5);p.add_argument('--prefix-days',type=int,default=2)
p.add_argument('--timeout-seconds',type=float,default=120);p.add_argument('--reference-csv',type=Path)
a=p.parse_args();assert 0<a.prefix_days<a.days<=30
base=a.bundle.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
build=json.loads((base/'BUILD.json').read_text());exe=base/'swap5_grass_startup'
assert sha(exe)==build['executable_sha256']
assert all(sha(Path(s))==h for s,h in build['source_sha256'].items()),'stale build source'
inputs=base/'original-interval';events=[]
def checkpoint(path):
 b=path.read_bytes();assert b[:8] in (b'S5GRS001',b'S5GRS002')
 assert zlib.crc32(b[:-4])==struct.unpack('=I',b[-4:])[0]
 pos=8
 for i in range(6):
  n=struct.unpack_from('=i',b,pos)[0];assert 0<n<=2097152;pos+=4+n
 nodes,clock=struct.unpack_from('=id',b,pos)
 assert nodes==113 and clock==int(clock)
 return b,pos,clock

def case(label,end,restart=None,corruption=None):
 folder=out/label;folder.mkdir()
 for name,h in build['original_inputs_sha256'].items():
  assert sha(inputs/name)==h;shutil.copyfile(inputs/name,folder/name)
 shutil.copyfile(inputs/'application.binding',folder/'application.binding')
 if corruption=='source':
  q=folder/'input.swp';q.write_bytes(b'* source-binding rejection control\n'+q.read_bytes())
 args=[str(exe),str(end),'retain-step','100000']+([str(restart)]if restart else[])
 t=time.perf_counter()
 with(folder/'stdout').open('wb')as so,(folder/'stderr').open('wb')as se:
  try:r=subprocess.run(args,cwd=folder,stdin=subprocess.DEVNULL,stdout=so,stderr=se,timeout=a.timeout_seconds);rc=r.returncode
  except subprocess.TimeoutExpired:rc=None
 event=dict(case=label,command=args,returncode=rc,seconds=time.perf_counter()-t,files={f.name:sha(f)for f in folder.iterdir()if f.is_file()})
 events.append(event);(out/'EVENTS.json').write_text(json.dumps(events,indent=2))
 if corruption:
  assert rc is not None and rc!=0,(label,'invalid restart accepted/censored')
  assert not(folder/'checkpoint.bin').exists()and not(folder/'budget.csv').exists(),label
  assert b'bound grass prefix restart rejected'in(folder/'stdout').read_bytes(),label
  event['expected_rejection']=True;return folder
 assert rc==0,(label,rc)
 rows=list(csv.DictReader((folder/'budget.csv').open()));assert rows and float(rows[-1]['t1'])==end
 for row in rows:
  assert all(math.isfinite(float(v))for v in row.values())
  assert abs(float(row['residual_cm']))<=1e-10
  assert abs(float(row['water_end_cm'])-float(row['water_start_cm'])-float(row['input_cm'])+float(row['output_cm']))<=1e-10
  assert abs(float(row['potential_cm'])-float(row['uptake_cm'])-float(row['drought_cm'])-float(row['oxygen_cm']))<=1e-10
 profile=list(csv.DictReader((folder/'state.csv').open()));assert len(profile)==113
 assert all(all(math.isfinite(float(v))for v in row.values())and 0<=float(row['water_content'])<=1 for row in profile)
 b,pos,clock=checkpoint(folder/'checkpoint.bin');assert clock==end
 event.update(completed_days=end,water_max_abs_cm=max(abs(float(r['residual_cm']))for r in rows),
  heat_max_abs_j_cm2=max(abs(float(r['heat_residual_j_cm2']))for r in rows))
 print(label,'PASS',round(event['seconds'],3),flush=True)
 return folder

full=case('full',a.days);prefix=case('prefix',a.prefix_days)
original_checkpoint_sha=sha(prefix/'checkpoint.bin')
suffix=case('suffix',a.days,prefix/'checkpoint.bin')
for name in ['state.csv','endpoint.csv','checkpoint.bin']:
 assert(full/name).read_bytes()==(suffix/name).read_bytes(),('restart mismatch',name)
whole=list(csv.DictReader((full/'budget.csv').open()));part=list(csv.DictReader((suffix/'budget.csv').open()))
assert whole[a.prefix_days:]==part,'accepted daily budget restart mismatch'
raw,offset,clock=checkpoint(prefix/'checkpoint.bin')
corrupt=out/'corrupt';corrupt.mkdir()
for kind in ['crc','truncated','layout','clock','source']:
 b=bytearray(raw)
 if kind=='crc':b[offset+16]^=1
 elif kind=='truncated':b=b[:-7]
 elif kind=='layout':struct.pack_into('=i',b,offset,112)
 elif kind=='clock':struct.pack_into('=d',b,offset+4,clock+.5)
 if kind in ['layout','clock']:struct.pack_into('=I',b,len(b)-4,zlib.crc32(b[:-4]))
 f=corrupt/(kind+'.bin');f.write_bytes(b)
 case('reject-'+kind,a.days,f,kind)
assert sha(prefix/'checkpoint.bin')==original_checkpoint_sha,'source restart was modified'
comparison=[]
if a.reference_csv:
 reference=list(csv.DictReader(l for l in a.reference_csv.read_text().splitlines()if l.strip()and not l.startswith('*')))
 assert len(reference)>a.days
 for row in whole:
  day=int(row['day']);old=reference[day]
  comparison.append(dict(day=day,date=old['DATE'],water_swap5_cm=float(row['water_end_cm']),water_reference_cm=float(old['WTOT']),
   water_difference_cm=float(row['water_end_cm'])-float(old['WTOT']),
   potential_transpiration_difference_cm=float(row['potential_cm'])-float(old['TPOT']),
   actual_transpiration_difference_cm=float(row['uptake_cm'])-float(old['TACT'])))
report=dict(status='BOUNDED_ORIGINAL_GRASS_WATER_AND_DISK_RESTART_PASS',days=a.days,original_project='2.grassgrowth',
 original_inputs_sha256=build['original_inputs_sha256'],executable_sha256=sha(exe),source_sha256=build['source_sha256'],
 compiler=build['compiler'],flags=build['flags'],events=events,restart_payload_exact=True,rejected_restart_controls=5,
 maximum_water_residual_cm=max(e.get('water_max_abs_cm',0)for e in events),
 maximum_heat_accounting_residual_j_cm2=max(e.get('heat_max_abs_j_cm2',0)for e in events),
 reference_comparison=comparison,complete_project_migration=False,
 scope='Natural source grass dormancy before200-degree temperature start; physical Bartholomeus, PM/SWRAIN2, Boesten, numeric heat and DRAMET3 retained; groundwater clamped before first measurement. No harvest, active-growth root lifecycle, varying groundwater or full-period equivalence claim.')
assert all(sha(Path(s))==h for s,h in build['source_sha256'].items()),'source changed during qualification'
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'],flush=True)
