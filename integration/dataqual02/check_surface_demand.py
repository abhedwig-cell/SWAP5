"""Bounded original-input output/history oracle; altered rain can reset drying history."""
import csv,hashlib,json,re,struct,zlib
from pathlib import Path

def check(folder):
 folder=Path(folder);m=json.loads((folder/'manifest.json').read_text());assert m['status']=='COMPLETE'
 assert m['mode']=='experimental'and m['source_surface_demand']
 assert m['preparation']['original_sources']['original_swp']=='c87ef0f8561f90277a2ae22f74fd12e050e4cafb26cb3b475768a737c76c059b'
 for name,h in m['files'].items():assert hashlib.sha256((folder/name).read_bytes()).hexdigest()==h,name
 rows=list(csv.DictReader((folder/'budget.csv').open()));assert rows and float(rows[0]['t0'])==0.
 first=rows[0];assert float(first['t1'])==1.
 text=(folder/'input.nml').read_text();match=re.search(r'^\s*soil_evaporation_cm_day=([^\n]+)',text,re.M);assert match
 potential=float(match.group(1).split(',')[0]);actual=float(first['soil_evap_cm'])
 assert 0.<actual<=potential+1.e-12,(actual,potential)
 for row in rows:
  for key in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']:assert abs(float(row[key]))<=1.e-10
 raw=(folder/'restart.bin').read_bytes();assert raw[:8]==b'S5WM0001'
 assert zlib.crc32(raw[:-4])==struct.unpack_from('<I',raw,len(raw)-4)[0]
 nodes=struct.unpack_from('<i',raw,72)[0];assert nodes==112
 spev,saev=struct.unpack_from('<2d',raw,216+2*nodes*8+16)
 assert spev>0. and saev>0.
 return dict(first_day_soil_evap_cm=actual,original_potential_cm=potential,SPEV=spev,SAEV=saev)
if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('run',type=Path);a=p.parse_args();print(json.dumps(check(a.run)))
