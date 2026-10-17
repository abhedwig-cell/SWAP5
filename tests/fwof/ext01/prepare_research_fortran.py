import csv,datetime as dt,json,sys
from pathlib import Path
p=Path(sys.argv[1]);d=Path(sys.argv[2]);d.mkdir(parents=True,exist_ok=True)
params=json.loads((p/"crop_parameter_values.json").read_text())
rows=list(csv.DictReader((p/"pcse_daily_fortran_boundary.csv").open()))
assert len(rows)==61
assert all(dt.date.fromisoformat(r["day"])==dt.date(2010,4,16)+dt.timedelta(days=i) for i,r in enumerate(rows))
def table(n,x):
 t=params[n];z=list(zip(t[::2],t[1::2]))
 for (a,b),(c,e) in zip(z,z[1:]):
  if x<=c:return b+(e-b)*max(0.,x-a)/(c-a)
 return z[-1][1]
forcing=[]
for i,r in enumerate(rows[:60],1):
 q=lambda k:float(r[k])
 mins=[float(x["TMIN"]) for x in rows[max(0,i-7):i]]
 vals=[1,i,q("TMIN"),q("TEMP"),(q("TEMP")+q("TMAX"))/2,q("IRRAD_J_M2_D"),q("DAYL_H"),q("DAYLP_H"),q("SINLD"),q("COSLD"),q("DIFPP_J_M2_S"),q("DSINBE_S"),sum(mins)/len(mins),table("CO2EFFTB",420.),table("CO2AMAXTB",420.)]
 forcing.append(" ".join(str(z) for z in vals))
(d/"forcing.dat").write_text("\n".join(forcing)+"\n")
print("EXT01_FORCING_READY",len(forcing))
