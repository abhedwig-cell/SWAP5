"""Verify exact-source Hupsel evidence; superseded combinations never inherit PASS."""
import csv,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];out=ROOT/'integration/dataqual15_hupsel';sha=lambda b:hashlib.sha256(b).hexdigest();r=json.loads((out/'RESULT.json').read_text());manifest=json.loads((out/'EVIDENCE_MANIFEST.json').read_text());assert sha((out/'EVIDENCE.tar.xz').read_bytes())==r['evidence_sha256']
for p,h in r['source_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('current source changed',p)
with tarfile.open(out/'EVIDENCE.tar.xz','r:xz')as t:files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
assert set(files)==set(manifest)
for n,h in manifest.items():assert sha(files[n])==h,n
read=lambda n:json.loads(files[n]);rows=lambda n:list(csv.DictReader(io.StringIO(files[n].decode())))
a='dq15-hupsel-codec-365-O2';b='dq15-hupsel-codec-365-O0';s='dq15-hupsel-codec-split250-O2';g='dq15-hupsel-codec-split130-O2';long='dq15-hupsel-codec-1096-attempt-O2'
for p in [a,b,s,g]:assert read(p+'/RESULT.json')['returncode']==0 and not read(p+'/RESULT.json')['censored']
for n in ['budget.csv','state.csv','temperature.csv','endpoint.csv','checkpoint.bin','restart.bin']:assert files[a+'/'+n]==files[b+'/'+n],('O0O2',n)
for n in ['state.csv','temperature.csv','endpoint.csv','checkpoint.bin','restart.bin']:assert files[a+'/'+n]==files[s+'/'+n],('restart',n)
assert rows(a+'/budget.csv')[251:]==rows(s+'/budget.csv')
assert files[a+'/checkpoint-145.bin']==files[g+'/checkpoint.bin']
assert [x for x in rows(a+'/budget.csv')if 130<float(x['t1_day'])<=145]==rows(g+'/budget.csv')
for base,opt in [(a,'O2'),(b,'O0')]:
 ss='dq15-hupsel-codec-split250-'+opt;gg='dq15-hupsel-codec-split130-'+opt
 assert read(ss+'/RESULT.json')['returncode']==0 and read(gg+'/RESULT.json')['returncode']==0
 for n in ['state.csv','temperature.csv','endpoint.csv','checkpoint.bin','restart.bin']:assert files[base+'/'+n]==files[ss+'/'+n]
 assert rows(base+'/budget.csv')[251:]==rows(ss+'/budget.csv')
 assert files[base+'/checkpoint-145.bin']==files[gg+'/checkpoint.bin']
 assert [x for x in rows(base+'/budget.csv')if 130<float(x['t1_day'])<=145]==rows(gg+'/budget.csv')
assert read(long+'/RESULT.json')['returncode']==1 and read(long+'/RESULT.json')['completed_days']==494
assert all(abs(float(x['water_end_cm'])-float(x['water_start_cm'])-float(x['water_in_cm'])+float(x['water_out_cm']))<=1e-10 and abs(float(x['solute_residual_mg_cm2']))<=1e-10 for p in [a,b,s,g,long]for x in rows(p+'/budget.csv'))
for opt in ['O0','O2']:
 q=read('dq15-hupsel-codec-restart-controls-'+opt+'/RESULT.json');assert len(q['events'])==16 and all(e['returncode']!=0 for e in q['events'])
assert read('dq15-hupsel-source-oracle-535/RESULT.json')['status']=='COMPILED_ORIGINAL_GERMINATION_O0_O2_PASS'
assert read('dq15-hupsel-contracts-535-originalflags/RESULT.json')['status']=='REAL_PRODUCTION_JARVIS_BLACK_FIXED_CROP_O0_O2_PASS'
print('DATAQUAL15_HUPSEL_ORIGINAL365_O0_O2_494_O2_EXACT_RESTART_PASS; full1096/scientific equivalence/production remain OPEN')
