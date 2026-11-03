"""Pin historical thermal inputs; never relabel air/initial soil as measured water donors."""
import argparse, hashlib, json, re, tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def audit():
 capsule=ROOT/'integration/dataqual15/ANDELST_CONTACT_DIAGNOSTIC.tar.xz'
 with tarfile.open(capsule) as archive:
  swp=archive.extractfile('run/input.swp').read();nml=archive.extractfile('run/input.nml').read()
 text=swp.decode();prepared=nml.decode()
 switches={key:int(re.search(r'^\s*'+key+r'\s*=\s*(\d+)',text,re.M).group(1)) for key in ['SWHEA','SWCALT','SWTOPBHEA','SWBOTBHEA']}
 assert switches==dict(SWHEA=1,SWCALT=2,SWTOPBHEA=1,SWBOTBHEA=1)
 table=text.split('TSOILTB =',1)[1].split('* End of table',1)[0]
 initial=[[float(x) for x in line.split()] for line in table.splitlines() if line.strip()]
 assert initial==[[-0.0,10.0],[-320.0,10.0]]
 paths=[ROOT/f'reference/swap-4.3.1/projects/3.macroporeflow/andelst_meteo.{year}' for year in ['998','999']]
 rows=[]
 for path in paths:
  for line in path.read_text().splitlines():
   if not line.startswith("'ANDE-M'"):continue
   fields=line.split();day,month,year=map(int,fields[1:4]);tmin,tmax=map(float,fields[5:7])
   rows.append(dict(date=f'{year:04}-{month:02}-{day:02}',air_mean_c=(tmin+tmax)/2))
 air=re.search(r'air_temperature_c\s*=([^/]+)',prepared,re.I).group(1)
 values=[float(x) for x in re.findall(r'[-+]?\d+(?:\.\d*)?(?:[eEdD][-+]?\d+)?',air.split('\n',1)[0])]
 assert all(abs(values[i]-rows[i]['air_mean_c'])<1e-12 for i in range(3))
 digest=lambda data:hashlib.sha256(data).hexdigest()
 return dict(status='PASS',source_sha256={str(p.relative_to(ROOT)).replace('\\','/'):digest(p.read_bytes()) for p in [capsule,*paths]},
  embedded_sha256=dict(input_swp=digest(swp),input_nml=digest(nml)),switches=switches,initial_soil_table=initial,
  historical_air_first_three_days=rows[:3],historical_air_days=len(rows),
  independent_rain_temperature_available=False,independent_groundwater_temperature_available=False,
  strict_nonzero_missing_donor_policy='REFUSE_WITHOUT_COMMIT',
  research_proxy_policy=dict(rain='native historical air temperature',groundwater='native bottom matrix temperature at interval origin',
   independent_measured_water_donors=False),full_physical_energy_complete=False)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 result=audit();a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(result['status'])
if __name__=='__main__':main()
