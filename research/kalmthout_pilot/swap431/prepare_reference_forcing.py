#!/usr/bin/env python3
"""Create the explicit bare-soil SWAP431 case from interval-start weather CSV."""
from pathlib import Path
import csv,datetime,sys,shutil,math,json,hashlib
source=Path(sys.argv[1]);case=Path(sys.argv[2]);case.mkdir(parents=True,exist_ok=True)
shutil.copyfile(Path(__file__).with_name('reference_case.swp'),case/'swap.swp')
rows=list(csv.DictReader(source.open()));assert len(rows)==24120
ts=[datetime.datetime.fromisoformat(r['time']) for r in rows]
assert ts[0]==datetime.datetime(2024,1,1) and ts[-1]==datetime.datetime(2026,10,1,23)
with (case/'kalmthout.met').open('w') as f:
 f.write('* ERA5 reanalysis via Open-Meteo, UTC, not station observations\nStation,DD,MM,YYYY,Rad,Tmin,Tmax,Hum,Wind,Rain,ETref,Wet\n')
 for i in range(0,len(rows),24):
  day=rows[i:i+24];r=day[0];d=ts[i];rain=math.fsum(float(x['precip_mm_hour']) for x in day)
  f.write(f"'KAL',{d.day},{d.month},{d.year},{r['radiation_kj_m2_day']},{r['tmin_day_c']},{r['tmax_day_c']},{r['vapour_pressure_kpa']},{r['wind2_m_s']},{rain:.6f},{r['et0_mm_day']},0.0\n")
with (case/'kalmthout.rain').open('w') as f:
 f.write('* END of interval; preceding-hour amount mm\nDAY MONTH YEAR TIME AMOUNT\n')
 for d,r in zip(ts,rows):
  end=d+datetime.timedelta(hours=1)
  f.write(f"{end.day} {end.month} {end.year} {end.hour/24:.15f} {r['precip_mm_hour']}\n")
print(json.dumps({'csv_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'rain_mm':math.fsum(float(r['precip_mm_hour']) for r in rows),'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in case.iterdir() if p.is_file()}},indent=2))
