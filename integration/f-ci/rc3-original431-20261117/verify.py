"""Portable raw result/reuse verification; execute no model or compiler."""
from pathlib import Path
import csv,hashlib,io,json,zipfile
from decimal import Decimal,getcontext
getcontext().prec=50
root=Path(__file__).resolve().parent;sha=lambda b:hashlib.sha256(b).hexdigest();seal=json.loads((root/'SEAL.json').read_bytes())
assert sha((root/'FILES.json').read_bytes())==seal['index_sha256']
assert sha((root/'COMPARISON.json').read_bytes())==seal['report_sha256']
assert sha((root/seal['archive']).read_bytes())==seal['sha256']
index=json.loads((root/'FILES.json').read_bytes());report=json.loads((root/'COMPARISON.json').read_bytes())
parent=json.loads((root.parent/'nomacro-rc3-20261117/local-raw.index.json').read_bytes())['files']
assert report['new_model_executions']==0 and report['tolerances_changed'] is False
def read(z,path):return list(csv.DictReader(s for s in z.read(path).decode().splitlines() if s.strip() and not s.startswith('*')))
with zipfile.ZipFile(root/seal['archive']) as z:
 for name,h in index.items():assert sha(z.read(name))==h,name
 assert z.read('COMPARISON.json')==(root/'COMPARISON.json').read_bytes()
 old=json.loads(z.read('prior/COMPARISON.json'));audit=json.loads(z.read('AUDIT.json'))
 prepared=json.loads(z.read('RC3_PROVIDER_PREPARED.json'));original=json.loads(z.read('prior/ORIGINAL_PROVIDER_PREPARED.json'))
 for key in ('source_archives','toolchain','floating_point_profile','preparation_sources','inputs'):assert prepared[key]==original[key]
 for name,h in audit['original_selected_sources'].items():assert h==original['provider_files']['build/swap-selected/'+name]==parent['provider/build/swap-selected/'+name]['sha256']
 for name,p in report['profiles'].items():
  key='salt' if name=='saltfarm' else name;base=name+'-O2-candidate-full/'
  assert p['rc3_csv_sha256']==sha(z.read(name+'/rc3.csv'))==parent[base+'original/result_output.csv']['sha256']
  assert p['rc3_journal_sha256']==parent[base+'daily.jsonl']['sha256']
  assert p['rc3_build_sha256']==sha(z.read(name+'/BUILD.json'))==parent[name+'-O2-candidate-build/BUILD.json']['sha256']
  assert p['original_csv_sha256']==sha(z.read(name+'/original431.csv'))==old['profiles'][key]['original_csv_sha256']
  for n,h in p['input_sha256'].items():assert sha(z.read(name+'/input/'+n))==h==old['profiles'][key]['input_sha256'][n]==parent[base+'original/'+n]['sha256']
  a,b=read(z,name+'/original431.csv'),read(z,name+'/rc3.csv');assert len(a)==len(b)==p['days']+1;assert [r['DATE'] for r in a]==[r['DATE'] for r in b]
  for field,v in p['fields'].items():
   values=[(abs(Decimal(y[field])-Decimal(x[field])),i,x['DATE']) for i,(x,y) in enumerate(zip(a[1:],b[1:]),1) if Decimal(x[field]) not in {Decimal('-999'),Decimal('-999.999')} and Decimal(y[field]) not in {Decimal('-999'),Decimal('-999.999')}]
   if values:
    maximum=max(values,key=lambda x:(x[0],x[1]));assert maximum==(Decimal(v['max_abs_difference']),v['worst_day'],v['worst_date'])
   else:assert v['max_abs_difference'] is None
print('RC3_ORIGINAL431_ALL_RAW_FIELDS_AND_PARENT_REUSE_VERIFIED_NO_MODELS')
