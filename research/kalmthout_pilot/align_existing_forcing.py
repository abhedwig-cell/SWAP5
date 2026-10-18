#!/usr/bin/env python3
"""Shift preceding-hour ERA5 aggregates into explicit interval-start columns.

Reuse the immutable 24120-row CSV. The only extra required values are P and Rs
at 2026-10-02T00:00. Temperature/dew/wind remain instantaneous at the row time.
Source convention: https://open-meteo.com/en/docs/historical-weather-api
"""
import csv,json,sys,datetime,math,hashlib
from pathlib import Path
src,endpoint,dst=map(Path,sys.argv[1:4])
rows=list(csv.DictReader(src.open()));h=json.loads(endpoint.read_text())['hourly']
assert len(rows)==24120 and h['time'][0]=='2026-10-02T00:00'
assert all(datetime.datetime.fromisoformat(b['time'])-datetime.datetime.fromisoformat(a['time'])==datetime.timedelta(hours=1) for a,b in zip(rows,rows[1:]))
next_rain=[r['precip_mm_hour'] for r in rows[1:]]+[f"{h['precipitation'][0]:.6f}"]
next_rad=[r['shortwave_mj_m2_hour'] for r in rows[1:]]+[f"{h['shortwave_radiation'][0]*.0036:.6f}"]
with dst.open('w') as f:
 w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader()
 for r,p,rad in zip(rows,next_rain,next_rad):
  out=dict(r);out['precip_mm_hour']=p;out['shortwave_mj_m2_hour']=rad;w.writerow(out)
# Midnight Rs=0 throughout this latitude/period, so existing daily radiation
# integrals and temperature/humidity/wind aggregates remain valid.
for i in range(0,len(rows),24):
 assert abs(sum(map(float,next_rad[i:i+24]))*1000-float(rows[i]['radiation_kj_m2_day']))<.03
print(json.dumps({'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'aligned_sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'endpoint_sha256':hashlib.sha256(endpoint.read_bytes()).hexdigest(),'old_rain_mm':math.fsum(float(r['precip_mm_hour']) for r in rows),'aligned_rain_mm':math.fsum(map(float,next_rain)),'records':len(rows),'convention':'P and Rs preceding-hour to interval-start; instantaneous temperature/dew/wind unchanged'},indent=2))
