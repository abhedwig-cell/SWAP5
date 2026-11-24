"""Finish only the missing foreign-native/vapor controls; no model replay."""
import argparse,json,subprocess,sys
from pathlib import Path
from snow58_analytical_source import ROOT,complete_inverse,git
from analytical_hydraulic_archives import SHA
p=argparse.ArgumentParser()
for key in ('profile','output'):p.add_argument('--'+key,type=Path,required=True)
a=p.parse_args();complete_inverse();head=git('rev-parse','HEAD').decode().strip();q=json.loads((a.profile/'RESULT.json').read_text());assert q['days']==35 and q['layer_models']==[11,11] and q['kind']=='water' and q['status'].endswith('PASS_NOT_ADMITTED');assert not git('diff',q['source'],head,'--','app','src','tools','reference');a.output.mkdir();checks={}
for key,driver in [('native18','snow58_analytical_native_controls.py'),('active-vapor','snow58_analytical_vapor_refusal.py')]:
 target=a.output/key;command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage'/driver),'--profile',str(a.profile),'--output',str(target)]
 with (a.output/(key+'.stdout')).open('xb') as out,(a.output/(key+'.stderr')).open('xb') as err:r=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=300)
 r.check_returncode();checks[key]=json.loads((target/'RESULT.json').read_text())
assert len(checks['native18']['compiled_refusals'])==18 and checks['native18']['positive_actual_compiled_ready'] and checks['active-vapor']['accepted_model_days']==0 and git('rev-parse','HEAD').decode().strip()==head
record=dict(status='ACTUAL_MISSING_LAST_MODEL11_NATIVE18_AND_ACTIVE_VAPOR_CONTROLS_PASS_NO_MODEL_REPLAY',actual_observer_source=head,actual_compiler_source=q['source'],profile=str(a.profile),profile_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),actual_BUILD_sha256=q['actual_BUILD_sha256'],checks=checks,compiler_executions=0,model_periods=0,accepted_model_days=0,canonical_admission=False)
(a.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],q['optimization'])
