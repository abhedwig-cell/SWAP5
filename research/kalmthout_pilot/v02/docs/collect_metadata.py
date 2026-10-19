from pathlib import Path
from collections import Counter
import json,csv,re,hashlib
import numpy as np
from netCDF4 import Dataset
import argparse
p=argparse.ArgumentParser();p.add_argument('run_root',type=Path);a=p.parse_args()
ROOT=a.run_root.resolve();R=Path(__file__).resolve().parent.parent
def clean(x):
 if isinstance(x,np.ndarray):return x.tolist()
 if isinstance(x,np.generic):return x.item()
 return x
metadata={'scope':'Observed file schema and receipts, not independent scientific validation','files':[]}
for p in sorted((ROOT/'daily_netcdf').glob('*.nc')):
 with Dataset(p) as d:
  v={name:{'dimensions':list(z.dimensions),'shape':list(z.shape),'dtype':str(z.dtype),'attributes':{a:clean(z.getncattr(a)) for a in z.ncattrs()},'chunks':z.chunking(),'filters':z.filters()} for name,z in d.variables.items()}
  metadata['files'].append({'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'dimensions':{k:len(z) for k,z in d.dimensions.items()},'attributes':{a:clean(d.getncattr(a)) for a in d.ncattrs()},'variables':v})
(R/'metadata/netcdf_schema.json').write_text(json.dumps(metadata,indent=2,allow_nan=True)+'\n')
# Strict JSON records the NaN fill value explicitly as text.
p=R/'metadata/netcdf_schema.json';p.write_text(p.read_text().replace('NaN','"NaN"'))
audit={'native_ledger_max_error_cm':0.,'max_native_BALDEV_cm':0.,'reset_dates':Counter(),'native_status':Counter(),'GASST_flags':Counter()}
for p in (ROOT/'cells').glob('*/v02_run_receipt.json'):
 r=json.loads(p.read_text());audit['native_status'][r['status']]+=1
 for k in ('native_ledger_max_error_cm','max_native_BALDEV_cm'):audit[k]=max(audit[k],r['audit'][k])
 for x in r['audit']['canopy_reset_flags']:audit['reset_dates'][x['date']]+=1
for f in metadata['files']:
 with Dataset(ROOT/'daily_netcdf'/f['name']) as d:
  u,c=np.unique(d['GASST_flag'][:],return_counts=True)
  for a,b in zip(u,c):audit['GASST_flags'][str(a)]+=int(b)
(R/'metadata/extended_audit_summary.json').write_text(json.dumps(audit,indent=2)+'\n')
params={}
for p in [ROOT/'cells/K250_00007/swap.swp',*sorted((ROOT/'crops').glob('*.crp'))]:
 s=p.read_text();params[p.name]={'scalar_assignments':dict(re.findall(r'^\s*(\w+)\s*=\s*([^\n!]*)',s,re.M)),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'note':'Representative SWP settings; soil values and crop calendar vary by cell. Tables and exact complete files are retained in the recovery archive.'}
(R/'metadata/parameter_inventory.json').write_text(json.dumps(params,indent=2)+'\n')
print(json.dumps(audit,indent=2))
