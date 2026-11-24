"""Current native precondition verification reusing genuine completed full periods."""
import argparse,json,subprocess,sys,time
from pathlib import Path
from explicit_bottom9_snow_analytical_source import ROOT,complete_inverse,git
from analytical_hydraulic_archives import SHA


def main():
 p=argparse.ArgumentParser()
 for key in ('positive-batch','proof','build-root','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--reuse-map',type=Path);a=p.parse_args();complete_inverse();a.proof.mkdir(parents=True,exist_ok=True);a.build_root.mkdir(parents=True,exist_ok=True)
 head=git('rev-parse','HEAD').decode().strip();prior=json.loads(a.positive_batch.read_text());assert prior['source']==prior['actual_completion_head']=='505954d2943b3f7f478efbb617c53f53dc5f5126' and prior['status'].startswith('ALL6_') and len(prior['contexts'])==6
 reuse=json.loads(a.reuse_map.read_text()) if a.reuse_map else {};q=dict(status='RUNNING',source=head,optimization=prior['optimization'],original_full35_batch_sha256=SHA(a.positive_batch.read_bytes()),contexts=[],original_full35_periods_replayed=0,canonical_admission=False);start=time.monotonic()
 def save():(a.proof/'BATCH.json').write_text(json.dumps(q,indent=2)+'\n')
 def run(command,label):
  assert git('rev-parse','HEAD').decode().strip()==head
  with (a.proof/(label+'.stdout')).open('xb') as out,(a.proof/(label+'.stderr')).open('xb') as err:done=subprocess.run([sys.executable,'-B',*map(str,command)],cwd=ROOT,stdout=out,stderr=err,timeout=1200)
  assert done.returncode==0,dict(label=label,returncode=done.returncode)
 save()
 try:
  for case in prior['contexts']:
   label='model'+str(case['model'])+'-'+case['kind']+'-'+prior['optimization'];q['active']=label;save();original=Path(case['profile'])
   if label in reuse:
    bridge=Path(reuse[label]['profile']);result=json.loads((bridge/'RESULT.json').read_text());assert result['status'].startswith('ACTUAL_CURRENT_NATIVE_NO_VAPOR_GUARD') and result['original_full35_profile']==str(original)
    assert not git('diff',result['source'],'HEAD','--','app','src','tools','reference');reused=True
   else:
    bridge=a.proof/label;reused=False
    run(['tests/nomacro_drainage/explicit_bottom9_snow_analytical_guard_bridge.py','--profile',original,'--reference-work',a.reference_work,'--build-root',a.build_root/label,'--output',bridge],label+'-bridge')
    result=json.loads((bridge/'RESULT.json').read_text())
   refusal=None
   if case['model']==11:
    refusal=a.proof/(label+'-vapor-refusal')
    run(['tests/nomacro_drainage/explicit_bottom9_snow_analytical_vapor_refusal.py','--profile',bridge,'--output',refusal],label+'-vapor-refusal')
   q['contexts'].append(dict(model=case['model'],kind=case['kind'],optimization=prior['optimization'],original_full35_profile=str(original),original_full35_producer=case['producer'],current_guard_bridge=str(bridge),actual_current_compiler_producer=result['source'],reused_completed_current_bridge=reused,actual_current_warm_days=4,actual_current_cold_window=[4,7],compiled_foreign_active_vapor_refusal=str(refusal) if refusal else None,original_checkpoint_binding_rewritten=False,status=result['status']));save();print('ACTUAL_CURRENT_NO_VAPOR_GUARD_CONTEXT_PASS',label,flush=True)
  complete_inverse();assert len(q['contexts'])==6
  q.update(status='ALL6_CURRENT_NO_VAPOR_NATIVE_SOURCE_COMPILED_WARM4_COLD4_7_BRIDGES_PASS_NO_FULL35_REPLAY_NOT_ADMITTED',seconds=time.monotonic()-start);q.pop('active',None)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:q['actual_completion_head']=git('rev-parse','HEAD').decode().strip();save()
 assert q['actual_completion_head']==head;print(q['status'],q['optimization'],q['seconds'],flush=True)


if __name__=='__main__':main()
