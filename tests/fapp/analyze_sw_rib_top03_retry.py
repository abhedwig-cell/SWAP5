#!/usr/bin/env python3
"""Single-interval retry result, preserving distinction from production acceptance."""
import csv,hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[2];log=Path('/tmp/top03-retry.log');lines=log.read_text().splitlines()
rows=[list(map(float,l.split(',')[1:])) for l in lines if l.startswith('RETRY,')]
assert len(rows)==28 and rows[:14]==rows[14:]
header=next(l.split(',') for l in lines if l.startswith('geometry,'))
baseline_rows=[dict(zip(header,next(csv.reader([l])))) for l in lines if l.startswith('2,7,')]
b=next(r for r in csv.DictReader((root/'integration/sw-rib-top03/evidence/terminal_trace/strict_geometry2_O0.csv').open()) if r['bottom_mode']=='7' and r['profile']=='1' and r['history']=='3' and r['steps']=='2048')
stable=lambda r:{k:(v.strip() if k=='solver_route' else float(v)) for k,v in r.items() if k!='cpu_seconds'}
assert len(baseline_rows)==2 and all(stable(r)==stable(b) for r in baseline_rows)
names=['kind','configuration','requested_days','completed_days','accepted','rejected','attempts','stop_reason','top_cm','bottom_cm','storage_cm','ledger_cm','max_soil_residual_cm','iterations','hbottom_cm']
records=[dict(zip(names,r)) for r in rows[:14]]
for r in records:
 assert abs(r['ledger_cm'])<1e-10 and r['max_soil_residual_cm']<1e-10
 assert r['attempts']==r['accepted']+r['rejected']
 assert (r['stop_reason']==0)==(r['completed_days']==r['requested_days'])
complete=[r for r in records if r['stop_reason']==0]
result={'scope':'one original failed interval, unchanged reference law; 14 packets per O0/O2',
 'source_checkpoint':'a8e493a3a0e29ac8a863556a4f8d85cf0d74186b','production_qualified':False,
 'O0_O2_identity':True,'surrounding_baseline_preserved':True,'origin_preservation_assertions_pass':True,
 'completed_packets':len(complete),'total_packets_per_build':14,
 'decision':'NONMONOTONE_SUBDIVISION__GROWTH2_PACKET_COMPLETES__FULL_HORIZON_UNQUALIFIED',
 'max_complete_top_spread_cm':max(r['top_cm'] for r in complete)-min(r['top_cm'] for r in complete),
 'max_complete_storage_spread_cm':max(r['storage_cm'] for r in complete)-min(r['storage_cm'] for r in complete),
 'records':records,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),
 'source_sha256':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['tests/fapp/make_top03_retry_probe.py','tests/fapp/top03_retry_research.inc','tests/fapp/run_sw_rib_top03_retry.sh','tests/fapp/analyze_sw_rib_top03_retry.py']}}
out=root/'integration/sw-rib-top03/evidence/retry';out.mkdir(parents=True,exist_ok=True)
(out/'observations_O0_O2.txt').write_text('\n'.join(l for l in lines if l.startswith(('RETRY,','retry_kind,','geometry,','2,7,','STOP,','TOP03_TRANSITION_O')))+'\n')
(root/'integration/sw-rib-top03/TOP03_RETRY_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('records','source_sha256')},indent=2))
