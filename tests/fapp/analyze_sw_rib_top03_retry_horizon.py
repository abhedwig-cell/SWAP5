#!/usr/bin/env python3
"""Full-horizon progress and flux characterization of source-preserving retry packets."""
import csv,hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[2];out=root/'integration/sw-rib-top03/evidence/retry_horizon';out.mkdir(parents=True,exist_ok=True)
def key(r):return tuple(r[k] for k in ('geometry','bottom_mode','profile','history','steps'))
def stable(r):return {k:(v.strip() if k=='solver_route' else float(v)) for k,v in r.items() if k!='cpu_seconds'}
baseline={};records=[];count_records=[];hashes={}
names=['geometry','bottom_mode','profile','history','steps','packets','successful_packets','failed_packets','retry_attempts','retry_rejected']
for g in (2,3):
 baseline.update({key(r):r for r in csv.DictReader((root/f'integration/sw-rib-top03/evidence/terminal_trace/strict_geometry{g}_O0.csv').open())})
 log=Path(f'/tmp/top03-retry-horizon-g{g}.log');hashes[log.name]=hashlib.sha256(log.read_bytes()).hexdigest()
 blocks=[];counts=[];header=None
 for l in log.read_text().splitlines():
  if l.startswith('geometry,'):header=l.split(',');blocks.append([]);counts.append([])
  elif l.startswith('ADAPT_COUNTS,'):counts[-1].append(dict(zip(names,l.split(',')[1:])))
  elif header and l.startswith(f'{g},'):
   v=next(csv.reader([l]));assert len(v)==len(header);blocks[-1].append(dict(zip(header,v)))
 assert len(blocks)==2 and all(len(b)==28 for b in blocks) and [stable(r) for r in blocks[0]]==[stable(r) for r in blocks[1]]
 assert len(counts[0])==28 and counts[0]==counts[1]
 for opt,b in zip((0,2),blocks):
  with (out/f'geometry{g}_O{opt}.csv').open('w') as f:
   w=csv.DictWriter(f,fieldnames=header);w.writeheader();w.writerows(b)
 with (out/f'geometry{g}_counts_O0.csv').open('w') as f:
  w=csv.DictWriter(f,fieldnames=names);w.writeheader();w.writerows(counts[0])
 records.extend(blocks[0]);count_records.extend(counts[0])
count_map={key(r):r for r in count_records}
repaired=[];retained=[];new=[];unchanged=0;differences=[]
for r in records:
 b=baseline[key(r)];c=count_map[key(r)];ok=r['stop_code']=='0';oldok=b['stop_code']=='0'
 assert abs(float(r['ledger_residual_cm']))<=1e-10 and abs(float(r['max_step_soil_residual_cm']))<=1e-10
 assert int(c['packets'])==int(c['successful_packets'])+int(c['failed_packets'])
 if int(c['packets'])==0:
  assert {k:v for k,v in stable(r).items() if k not in ('water_l1_diff_cm','head_inf_diff_cm')}=={k:v for k,v in stable(b).items() if k not in ('water_l1_diff_cm','head_inf_diff_cm')}
  unchanged+=1
 if ok and not oldok:repaired.append(key(r))
 elif not ok and oldok:new.append(key(r))
 elif not ok:retained.append(key(r))
 if ok and oldok:differences.append(abs(float(r['transfer_cm'])-float(b['transfer_cm'])))
series=[]
for g in ('2','3'):
 for profile in ('1','2'):
  for history in ('1','3'):
   sequence=[r for r in records if r['geometry']==g and r['profile']==profile and r['history']==history]
   fine=sequence[-2:]
   item={'geometry':g,'profile':profile,'history':history,'sequence':[{k:r[k] for k in ('steps','completed','stop_code','transfer_cm','bottom_cm','storage_change_cm','water_l1_diff_cm','head_inf_diff_cm')} for r in sequence]}
   item['finest_pair_complete']=all(r['stop_code']=='0' for r in fine)
   if item['finest_pair_complete']:
    item['finest_top_difference_cm']=abs(float(fine[1]['transfer_cm'])-float(fine[0]['transfer_cm']))
    item['finest_bottom_difference_cm']=abs(float(fine[1]['bottom_cm'])-float(fine[0]['bottom_cm']))
    item['finest_top_relative_difference']=item['finest_top_difference_cm']/abs(float(fine[1]['transfer_cm']))
   series.append(item)
result={'scope':'isolated full-horizon packet-retry research; no BASE acceptance or participant commit',
 'source_checkpoint':'8f09cecac2d26d10a80fe6f4004d981545c99ee7','O0_O2_identity':True,'production_qualified':False,
 'trajectories_per_build':len(records),'complete':sum(r['stop_code']=='0' for r in records),
 'baseline_failures':sum(baseline[key(r)]['stop_code']!='0' for r in records),'failures':len(retained)+len(new),
 'repaired_count':len(repaired),'new_failures':new,'retained_count':len(retained),'repaired':repaired,
 'nominal_no_retry_identity_count':unchanged,'max_both_complete_top_difference_cm':max(differences,default=0),
 'max_ledger_cm':max(abs(float(r['ledger_residual_cm'])) for r in records),
 'packets':sum(int(c['packets']) for c in count_records),'successful_packets':sum(int(c['successful_packets']) for c in count_records),
 'retry_attempts':sum(int(c['retry_attempts']) for c in count_records),'retry_rejected':sum(int(c['retry_rejected']) for c in count_records),
 'iterations_total':sum(int(r['iterations']) for r in records),'series':series,'log_sha256':hashes,
 'source_sha256':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['tests/fapp/make_top03_retry_horizon_probe.py','tests/fapp/top03_retry_research.inc','tests/fapp/top03_retry_packet.inc','tests/fapp/run_sw_rib_top03_retry_horizon.sh','tests/fapp/analyze_sw_rib_top03_retry_horizon.py']}}
result['decision']='RETRY_PACKET_FULL_HORIZON_UNRELIABLE__NO_PRODUCTION_ADMISSION' if result['failures'] else 'RETRY_PACKET_BOUNDED_PROGRESS_PASS__ACCURACY_AND_PRODUCTION_UNQUALIFIED'
(root/'integration/sw-rib-top03/TOP03_RETRY_HORIZON_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('series','source_sha256','repaired')},indent=2))
