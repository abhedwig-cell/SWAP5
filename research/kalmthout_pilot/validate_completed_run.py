#!/usr/bin/env python3
import csv,datetime,hashlib,json,math,sys
from pathlib import Path
p=Path(sys.argv[1]);rows=list(csv.DictReader(p.open()));assert len(rows)==24120
assert rows[0]['time']=='2024-01-01T00:00' and rows[-1]['time']=='2026-10-01T23:00'
assert all(datetime.datetime.fromisoformat(b['time'])-datetime.datetime.fromisoformat(a['time'])==datetime.timedelta(hours=1) for a,b in zip(rows,rows[1:]))
assert all(math.isfinite(float(r['mass_residual_cm'])) and abs(float(r['mass_residual_cm']))<=1e-10 for r in rows)
rain=math.fsum(float(r['precip_mm_hour']) for r in rows);assert abs(rain-2216.6)<1e-6
answer={'hours':len(rows),'precip_mm':rain,'max_hour_mass_residual_cm':max(abs(float(r['mass_residual_cm'])) for r in rows),'solver_rejections':sum(int(r['solver_rejections']) for r in rows),'temporal_rejections':sum(int(r['temporal_rejections']) for r in rows),'accepted_substeps':sum(int(r['accepted_substeps']) for r in rows),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
if 'pond_storage_cm' in rows[0]:
 pond=[float(r['pond_storage_cm']) for r in rows]
 assert all(v>=0 for v in pond)
 assert all(float(r['canopy_storage_cm'])==0 for r in rows)
 answer.update({'dry_hour_endpoints':sum(v==0 for v in pond),'ponded_hour_endpoints':sum(v>0 for v in pond),'wet_dry_transitions':sum((a==0)!=(b==0) for a,b in zip(pond,pond[1:])),'min_positive_pond_cm':min(v for v in pond if v>0),'max_pond_cm':max(pond)})
print(json.dumps(answer,indent=2))
