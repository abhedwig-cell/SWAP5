"""Exact CI-only successor authority; production and original scientific assertions fixed."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3]
STATUS='integration/audits/MC_SOL01_SURFACE_AGE03_CI_STATUS.json'
SURFACE=['src','tests','tools','reference','.github','integration/audits/surface_age_ci','integration/audits/surface_age_longrun/verify.py']
def check(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())
def verify_source():
 s=record();base=s['baseline'];git('merge-base','--is-ancestor',base,'HEAD')
 check(not git('status','--porcelain','--',*SURFACE),'dirty CI successor surface')
 check(not git('diff',base,'HEAD','--','src','reference'),'CI successor changed production/reference')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',base,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in s['postimages'].items()},'foreign CI successor delta')
 for p,v in s['postimages'].items():check(sha((ROOT/p).read_bytes())==v['sha256'],'unqualified CI successor '+p)
 return dict(ci_successor=True,production_changed=False,qualified=False)
def evidence():
 e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'CI evidence integrity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms),'unsafe CI capsule');f={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(f.pop('MANIFEST.json'));check(set(f)==set(manifest),'CI evidence inventory')
 for p,h in manifest.items():check(sha(f[p])==h,'CI evidence member '+p)
 return f
def validate(f):
 r=json.loads(f['result.json']);check(r['status']=='THREE_EXISTING_CI_ROUTES_LOCAL_PASS','unfinished CI science')
 check(r['execution_commit']==record()['execution_commit'],'unbound CI execution')
 # The conservative inventory also includes source never compiled by these routes.
 # Only an exact independently qualified upstream parser and two guard changes
 # may differ; compiled physical providers remain byte-identical.
 delta={p:(h,sha((ROOT/p).read_bytes())) for p,h in r['input_sha256'].items() if sha((ROOT/p).read_bytes())!=h}
 allowed=record().get('inherited_inventory_delta',{})
 check(set(delta)==set(allowed),'unregistered CI inventory successor')
 for p,(before,after) in delta.items():
  v=allowed[p];check(before==v['before_sha256'] and after==v['after_sha256'],'unbound CI inventory successor '+p)
  check(sha(subprocess.check_output(['git','show',r['execution_commit']+':'+p],cwd=ROOT))==before,'CI predecessor inventory '+p)
 if delta:
  import runpy
  hist=runpy.run_path(str(ROOT/'tests/nut-crop/verify_hist_native_successor.py'),run_name='ci_registered_parser_science')
  g=json.loads((ROOT/hist['STATUS']).read_text())['historical_guard']
  hist['registered_label_reader'](g,hist['archive'](g['physical_evidence']))
  ee=json.loads(f['compiler-events.json'])
  for p in delta:
   check(not any('-c'in e['args']and e['args'][e['args'].index('-c')+1].endswith(p)for e in ee),'changed compiled CI provider '+p)
 required={'fci51':'FCI51P_SUCCESSOR_O0_O2_PRESERVATION=PASS','fci58':'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS','fgc':'F_GC_CLOSEOUT_FIXED_INTERFACE_GATE_PASS'}
 check({e['case']for e in r['events']}==set(required),'missing CI route')
 for e in r['events']:
  check(e['returncode']==0,'failed CI science')
  for stream in ['stdout','stderr']:check(e[stream]in f,'missing CI raw stream')
  text=f[e['stdout']].decode();check(required[e['case']]in text,'missing original CI final assertion '+e['case'])
 # Every declared compiler invocation is recorded by the local compiler wrapper.
 ee=json.loads(f['compiler-events.json']);check(ee and all(e['returncode']==0 for e in ee),'failed/unrecorded compiler')
 for opt in ['-O0','-O2']:check(any(opt in e['args']and'-c'in e['args']for e in ee),'missing optimization build')
 return dict(qualified=True,three_routes=True,production_changed=False)
def validate_closure_followup(f):
 # This optional repair is a successor of the same CI work unit, not a new
 # physical admission. Keep every original driver, flag and assertion fixed.
 follow=record().get('closure_ci_followup_20261019')
 if not follow:return {}
 r=json.loads(f['result.json']);check(r['status']=='PASS','unfinished closure CI science')
 check(r['execution_commit']==follow['execution_commit'],'unbound closure CI execution')
 for p,h in r['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'closure CI input drift '+p)
 required={
  'poison':'FPE_ZERO_WASTE01_POISON_GATE=PASS',
  'fkt22':'FKT22_FMR_PRODUCTION_RUNTIME_GATE=PASS',
  'ahl_matrix':'FAHL49_PRODUCTION_MATRIX=PASS',
  'ahl_optin':'FAHL49_APPLICATION_GATE=PASS',
  'ahl_scale':'FAHL49_APPLICATION_SCALE=PASS',
  'ahl_failclosed':'FAHL49_FAILCLOSED=PASS',
  'timeint16':'F_PE_TIMEINT16=PASS',
  'timeint16b':'F_PE_TIMEINT16B=PASS'}
 check(len(r['events'])==len(required) and {e['case'] for e in r['events']}==set(required),'closure CI inventory')
 for e in r['events']:
  check(e['returncode']==0 and required[e['case']]in f[e['log']].decode(),'closure CI native failure '+e['case'])
 ee=[json.loads(line)for line in f['compiler.jsonl'].decode().splitlines()]
 selected={e['case']:e.get('attempt',1)for e in r['events']}
 ee=[e for e in ee if e.get('attempt',1)==selected[e['case']]]
 check(ee and all(e['returncode']==0 for e in ee),'closure CI compiler failure')
 for case,opts in {'poison':['-O0','-O2'],'fkt22':['-O0','-O2'],'ahl_matrix':['-O3'],'ahl_optin':['-O0','-O2'],'ahl_scale':['-O2'],'ahl_failclosed':['-O2'],'timeint16':['-O2'],'timeint16b':['-O2']}.items():
  for opt in opts:check(any(e['case']==case and opt in e['args']and '-c'in e['args']for e in ee),'closure CI optimization '+case+opt)
 # Prove the build recipes have only the selected dependency closure edit.
 base=follow['baseline']
 recipes=['tests/fpe/run_fpe_zero_waste01_poison_workspace.sh','tests/fkt/run_fkt22_fmr_runtime_gate.sh','tests/fahl/run_fahl49_failclosed.sh','tests/fahl/run_fahl49_application_scale.sh','tests/fgc/run_fgc49d_production_application_context.sh']
 for p in recipes:
  old=subprocess.check_output(['git','show',base+':'+p],cwd=ROOT).decode()
  before='augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}"'
  expected=old.replace(before,'augment_bartholomeus_backend_sources.py --all "${MODULE_SRC[@]}"')
  if p=='tests/fgc/run_fgc49d_production_application_context.sh':
   expected=expected.replace('nm -D "$OUT/libfgc49d_application.so" | grep -q "$symbol"','nm -D "$OUT/libfgc49d_application.so" | grep "$symbol" > /dev/null')
  check(old.count(before)==1 and (ROOT/p).read_text()==expected,'non-closure recipe change '+p)
 p='tests/fahl/run_fahl49_production_matrix.sh';old=subprocess.check_output(['git','show',base+':'+p],cwd=ROOT).decode()
 marker='objects=()\nfor source in "${SRC[@]}"; do'
 check(old.count(marker)==1 and (ROOT/p).read_text()==old.replace(marker,'mapfile -t SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py --all "${SRC[@]}")\n'+marker),'non-closure matrix recipe change')
 controls=json.loads(f['materializer_controls.json'])
 check(controls['status']=='PASS'and controls['production_roundtrip_exact']and controls['legacy_materialization_byte_identical']and len(controls['negative_controls'])==4,'origin materialization preservation')
 symbols=[json.loads(f['symbol-control'+opt+'.json'])for opt in ['-O0','-O2']]
 check(all(x['defined_symbol_found']for x in symbols)and any(x['legacy_pipeline_status'].startswith('141 0')for x in symbols),'unproven symbol-pipe repair')
 check(not git('diff',base,'HEAD','--','src','reference'),'closure repair changed physics')
 return dict(closure_ci_followup=True,eight_original_native_oracles=True,physical_admission_changed=False)

def closure_followup_evidence():
 follow=record().get('closure_ci_followup_20261019')
 if not follow:return {}
 e=follow['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'closure CI capsule integrity')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe closure CI capsule');f={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(f.pop('MANIFEST.json'));check(set(f)==set(manifest),'closure CI capsule inventory')
 for p,h in manifest.items():check(sha(f[p])==h,'closure CI member '+p)
 return f

def verify_qualification():
 result={**verify_source(),**validate(evidence()),**validate_closure_followup(closure_followup_evidence())}
 s=json.loads((ROOT/'integration/f-ci/F-CI73P_STATUS.json').read_text())
 if s.get('current_successor_20261018'):
  import runpy
  runpy.run_path(str(ROOT/'integration/audits/fci73_current.py'),run_name='fci73_current_science')['verify_science']()
 return result
if __name__=='__main__':
 import sys
 print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
