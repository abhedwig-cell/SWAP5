"""Actual compiled no-vapor precondition on genuine current checkpoint origins."""
import argparse,hashlib,json,re,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2];sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
import implicit_conductivity_runtime as original
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
p=argparse.ArgumentParser()
for key in ('profile','output'):p.add_argument('--'+key,type=Path,required=True)
a=p.parse_args();q=json.loads((a.profile/'RESULT.json').read_text());assert q['status'].startswith('ACTUAL_CURRENT_NATIVE_NO_VAPOR_GUARD') and q['layer_models']==[11,11]
git=lambda *args:subprocess.check_output(['git',*args],cwd=R).decode().strip();observer=git('rev-parse','HEAD');assert not git('diff',q['source'],'HEAD','--','app','src','tools','reference')
build=Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256'];project=original.m.e.load(q['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
checkpoint=a.profile/'trajectory/accepted-column-1-day-2.zip';checkpointsha=SHA(checkpoint.read_bytes());a.output.mkdir();rows=[]
for label,active in [('own-positive',False),('foreign-active-vapor-private-input',True)]:
 root=a.output/label;root.mkdir();origin=root/'origin';receipt=original.m.h.verify_checkpoint(checkpoint,2,meta['binding'],origin);directory=root/'original'
 original.m.h.prepare_column(Path(q['input_root']),directory,original.m.h.ColumnStart('original',2,origin,receipt),True,True,project);path=directory/'swap.swp';before=path.read_bytes()
 if active:
  after,count=re.subn(rb'(?mi)^([ \t]*SWVAPOR[ \t]*=[ \t]*)[^!\r\n]*',lambda match:match[1]+b'1 1 ',before);assert count==1;path.write_bytes(after)
 result=subprocess.run([str(original.m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,input=b'0 0\n',capture_output=True,timeout=20)
 (root/'donor.stdout').write_bytes(result.stdout);(root/'donor.stderr').write_bytes(result.stderr);assert b'HYBRID_DAY_RETURN' not in result.stdout and SHA(checkpoint.read_bytes())==checkpointsha
 rows.append(dict(label=label,actual_private_input_sha256=SHA(path.read_bytes()),original_private_input_sha256=SHA(before),returncode=result.returncode,ready=b'HYBRID_READY' in result.stdout,stderr=result.stderr.decode('utf8',errors='replace')))
assert rows[0]['ready'] and rows[0]['returncode'] in (0,100) and not rows[0]['stderr']
assert not rows[1]['ready'] and rows[1]['returncode'] not in (0,100) and 'Active vapor cannot use analytical Snow native' in rows[1]['stderr']
assert git('rev-parse','HEAD')==observer
q=dict(status='ACTUAL_CURRENT_COMPILED_NO_VAPOR_NATIVE_OWN_POSITIVE_AND_FOREIGN_ACTIVE_VAPOR_REFUSAL_PASS',actual_compiler_producer=q['source'],actual_observer_source=observer,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),genuine_current_checkpoint_sha256=checkpointsha,kind=q['kind'],optimization=q['optimization'],rows=rows,compiler_executions=0,model_periods=0,accepted_model_days=0,original_checkpoint_rebound=False,canonical_admission=False)
(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],q['kind'],q['optimization'])
