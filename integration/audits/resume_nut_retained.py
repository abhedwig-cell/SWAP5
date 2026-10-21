"""Continue unchanged retained assertions after an oracle environment mismatch.

The completed default/request executions are retained with exact source and
artifact identities. Reproductive and retained drivers execute freshly through
their original runners. This is a same-session continuation, not a native cache.
"""
from pathlib import Path
import ast,hashlib,json,os,re,runpy,shlex,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['CROP_N_RESULT_DIR']).resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
result=json.loads((OUT/'result.json').read_text())
assert result['status']=='B111_REQUEST_AFFECTED_SCIENCE_PASS_NOT_ADMITTED'
events=json.loads((OUT/'events.json').read_text())
assert all(e['returncode']==0 for e in events)
for p,h in result['input_sha256'].items():assert sha(ROOT/p)==h,p
for e in events:
 for stream in ['stdout','stderr']:assert sha(OUT/e[stream+'_file'])==e[stream+'_sha256']
artifacts={str(p.relative_to(OUT)):sha(p)for p in OUT.rglob('*')if p.suffix in ['.o','.mod']}
recovery=dict(status='LITERAL_ENVIRONMENT_DIGEST_MISMATCH_AFTER_PASSED_DEFAULT_REQUEST',
             preimage_result_sha256=sha(OUT/'result.json'),preimage_result=result,
             preimage_events_sha256=sha(OUT/'events.json'),artifacts=artifacts,
             native_PASS_reused_only_for_identical_completed_default_and_request=True,
             remaining_reproductive_and_retained='FRESH_ORIGINAL_RUNNER_ASSERTIONS')
(OUT/'RECOVERY.json').write_text(json.dumps(recovery,indent=2)+'\n')
FC=shlex.split(os.environ['FC'])
compile_events=[e for e in events if e['category']=='compile'and '-O2'in e['command']and
                Path(e['command'][-1]).name.startswith('provider-')]
ordered=[Path(e['command'][e['command'].index('-c')+1])for e in compile_events]
assert ordered and len(ordered)==len(set(ordered))
flags=compile_events[0]['command'][len(FC):-4]
assert '-fcheck=all'in flags and '-ffpe-trap=invalid,zero,overflow'in flags
providers={}
for p in [*ROOT.joinpath('src').rglob('*.f90'),*(OUT/'O2').glob('*.f90')]:
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[name.lower()]=p
seen=set(ordered);active=set()
def visit(p):
 if p in seen:return
 assert p not in active,'module cycle'
 active.add(p)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
  name=name.lower()
  if name in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:continue
  if providers[name]!=p:visit(providers[name])
 active.remove(p);seen.add(p);ordered.append(p)

# Execute the literal original command/event adapter, preserving its assertions
# and raw-event format rather than inventing successful completion records.
source=ROOT/'tests/nut-crop/run_crop_supply.py'
node=next(n for n in ast.parse(source.read_text()).body if isinstance(n,ast.FunctionDef)and n.name=='cmd')
namespace=dict(OUT=OUT,FC=FC,sha=sha,events=events,subprocess=subprocess,
               hashlib=hashlib,json=json,time=__import__('time'))
exec(compile(ast.Module(body=[node],type_ignores=[]),str(source),'exec'),namespace)
ns={**namespace,'ROOT':ROOT,'providers':providers,'ordered':ordered,'visit':visit,
    'flags':flags,'results':result}
literal=Path(os.environ['REPRODUCTIVE_LITERAL_FILE'])
assert sha(literal)=='b64c01e310927bad85f40a467ac356c300c4f72a062d60cc113927f68ac76c14'
os.environ['REPRODUCTIVE_LITERAL_SHA256']=sha(literal)
original_run_path=runpy.run_path
def resume(path,*args,**kwargs):
 if Path(path)==ROOT/'tests/nut-crop/run_b111_request_binding.py':
  return {'ns':ns,'result':result}
 return original_run_path(path,*args,**kwargs)
runpy.run_path=resume
sys.path.insert(0,str(ROOT/'tests/nut-crop'))
try:
 original_run_path(str(ROOT/'tests/nut-crop/run_b112_retained_joint.py'),run_name='retained_controlled_continuation')
finally:
 runpy.run_path=original_run_path
assert all(sha(OUT/p)==h for p,h in artifacts.items()),'completed provider artifact drift'
print('RETAINED_CONTROLLED_CONTINUATION_PASS')
