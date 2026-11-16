"""Evidence-only inventory. Never executes a model or rewrites historical totals."""
from pathlib import Path
import json,hashlib,tarfile,zipfile,csv,io
R=Path(__file__).resolve().parent;ROOT=R.parent
def sha(b):return hashlib.sha256(b).hexdigest()
def save(n,x):(R/n).write_text(json.dumps(x,indent=2)+'\n')
def fields(b):
 out={}
 for line in b.decode('cp1252').splitlines():
  s=line.split()
  if len(s)>1:
   try:out[s[0].lower()]=[float(v.replace('D','E')) for v in s[1:]]
   except ValueError:pass
 return out
sources=[];snapshots=[]
macro=['cqmpoutdrrap','cqmpintopvrtdm1','wasrdm1ini','wasrdm2ini','cgrai','cqbot']
for name in ['state02','stagnation05','contract06','retry07','native09','day10','midnight11','ledger12']:
 folder=ROOT/('swap431-macro-b1-'+name);meta=json.loads((folder/'EVIDENCE.json').read_text());arc=folder/meta['file'];assert sha(arc.read_bytes())==meta['sha256']
 candidates=[]
 with zipfile.ZipFile(arc) as z:
  for n in z.namelist():
   if not n.endswith('.txt') or '/data/' not in n or 'preliminary' in n:continue
   f=fields(z.read(n));seen=[k for k in macro if k in f]
   if seen:
    candidates.append(dict(member=n,fields=seen));
    if n.endswith('ledger_checkpoint.txt'):snapshots.append(dict(source=name,member=n,sha256=sha(z.read(n)),values={k:f[k] for k in macro if k in f}))
  sources.append(dict(work_unit=name,file=meta['file'],sha256=meta['sha256'],macro_ledger_numeric_snapshots=candidates))
a=ROOT/'swap431-macro-b1-accept01';m=json.loads((a/'EVIDENCE.json').read_text());arc=a/m['file'];assert sha(arc.read_bytes())==m['sha256'];daily=[]
out=R/'recovered';out.mkdir(exist_ok=True)
with tarfile.open(arc) as z:
 exact_old=[]
 for item in z.getmembers():
  if item.isfile() and item.name.endswith(('.txt','.dat','.csv')):
   ff=fields(z.extractfile(item).read())
   if any(k in ff for k in macro):exact_old.append(item.name)
 assert not exact_old
 for name in ['phase/O2/B0/case/result_output.csv','phase/O2/V1/case/result_output.csv','phase/O2/V2/case/result_output.csv','phase/O0/V1-metrics/case/result_output.csv']:
  b=z.extractfile(name).read();p=out/(name.replace('/','__'));p.write_bytes(b)
  rows=list(csv.DictReader(io.StringIO('\n'.join(l for l in b.decode('cp1252').splitlines() if l and not l.startswith('*')))))
  assert len(rows)==3
  daily.append(dict(archive=m['file'],archive_sha256=m['sha256'],member=name,sha256=sha(b),rows=rows,precision='formatted rounded daily aggregates, not exact native ledger'))
sources.append(dict(work_unit='accept01',file=m['file'],sha256=m['sha256'],daily_members=len(daily)))
# Preserve a native cold-prefix partial output as supplementary evidence, explicitly
# distinguished from sealed artifacts. Its existing rows match the sealed V1 data.
p=Path('C:/Users/Veldh012/swap431-native09-work/O2-B_TRIAL-FINAL3/result_output.csv');b=p.read_bytes();(out/'NATIVE09_O2_TRIAL_partial.csv').write_bytes(b)
rows=list(csv.DictReader(io.StringIO('\n'.join(l for l in b.decode('cp1252').splitlines() if l and not l.startswith('*')))))
assert rows==daily[1]['rows'][:2]
supp=dict(path=str(p),sha256=sha(b),rows=rows,authority='Supplementary local artifact, now captured; numeric rows agree with sealed V1 initial and first-day records')
v1=daily[1]['rows'];assert v1[0]['MP_WVOL_1']=='1.58200' and v1[0]['MP_WVOL_2']=='.04949'
v3=fields((ROOT/'swap431-macro-b1-ledger12/data/O2/CONTINUE/ledger_checkpoint.txt').read_bytes())
assert v3['wasrdm1ini']==v3['wasrdm2ini']==[0.]
native=(ROOT/'swap431-macro-b1-native09/native_state.f90').read_text().lower();assert all(k not in native for k in macro)
assert len([x for x in sources if x.get('macro_ledger_numeric_snapshots')])==1
save('SOURCE_INVENTORY.json',sources);save('DAILY_HISTORY.json',daily);save('LOCAL_SUPPLEMENT.json',supp)
save('EXACT_LEDGER_SNAPSHOTS.json',snapshots)
report=dict(work_unit='SWAP431-MACRO-B1-HISTORY13',models_launched=0,decision='PARTIAL_ORIGINAL_HISTORY_AVAILABLE_COMPLETE_CANDIDATE_PERIOD_HISTORY_NOT_RECOVERED',
 sealed_daily_records=dict(variants=['B0','V1','V2'],dates=['initial 1997-12-31','1998-01-01','1998-01-02'],initial_macro_stocks_cm=[1.582,.04949],meaning='Available original rounded stock and flux checks; never exact 132-field replacement'),
 exact_preboundary_native_ledgers='Not found in inspected sealed evidence before LEDGER12',
 exact_current_coverage=dict(start=35796.99991333311,checkpoint=35797.,end=35797.0001733362,scope='Locally accumulated last-boundary-step and next-day step; no historical carry-in'),
 losses=['NATIVE09 B writer omitted cumulative ledgers','DAY10 read B physical file and wrote last-subday physical file without ledgers','MID11/LEDGER12 bootstrap from last-subday file without prior cumulative carry-in'],
 invariant='Do not replace missing candidate ledger by rounded old-variant totals or silently rebase the historical balance origin',
 minimum_addition=['Declare exact balance origin, end and actual source/policy history, including patch activation time',
 'Obtain exact authoritative cumulative carry-in and original balance initial stocks at the first legacy handoff, or capture the missing prefix from that origin in one uninterrupted same-candidate process',
 'Carry all required water-output state through every handoff with explicit history coverage/origin metadata; reject full-period claim when coverage is incomplete',
 'Verify independent external balance from the original inventory to final inventory, and actual period output/reset/labels on O0/O2'],
 required_new_model_selection='None in this evidence-only task; exact prefix recovery would require separate tightly scoped selection, no automatic two-day/481 campaign',
 full_period_balance='NOT_QUALIFIED',local_LEDGER12_PASS_preserved=True,production_changed=False,official_promotion=False)
save('RESULT.json',report);print(json.dumps(report,indent=2))
