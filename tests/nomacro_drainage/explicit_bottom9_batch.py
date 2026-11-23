"""One resumable boundary composition batch; never replay a completed model period."""
import argparse,json,os,subprocess,sys
from pathlib import Path
from explicit_bottom9_inputs import CASES,prepare
from explicit_bottom9_source_inverse import ROOT,CORE,git,complete_inverse
from explicit_bottom9_composition_science import audit
from analytical_hydraulic_archives import SHA

def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','work','reference-work','cleanup'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--task',required=True);a=p.parse_args();complete_inverse();head=git('rev-parse','HEAD').decode().strip()
 assert os.environ.get('PYTHONDONTWRITEBYTECODE')=='1' and os.environ.get('OMP_NUM_THREADS')=='1'
 def frozen():assert git('rev-parse','HEAD').decode().strip()==head
 def run(args):frozen();subprocess.run([sys.executable,'-B',*map(str,args)],cwd=ROOT,check=True)
 def allocate(label,opt):
  frozen();path=a.evidence/(label+'-allocation.json')
  assert not path.exists(),'Existing allocation requires inspecting previous execution, never overwrite it'
  raw=subprocess.check_output([sys.executable,'-B',str(a.cleanup),'allocate','--task',a.task,'--kind','build','--name',label,'--variant',opt,'--source-ref',head,'--recipe','explicit_bottom9_runtime/postimage; actual original provider; donor/kernel '+opt+'; original-adaptive-day-seed-v1'],cwd=ROOT,text=True)
  with path.open('x') as out:out.write(raw)
  return a.work/label
 result=dict(status='RUNNING',source=head,physical_core=CORE,canonical_admission=False,contexts=[],model_period_replays_for_metadata=0)
 summary=a.evidence/'EXPLICIT_BOTTOM9_COMPOSITION_BATCH_V1.json'
 def save():summary.write_text(json.dumps(result,indent=2)+'\n')
 for case,_,_,_ in CASES:
  primary=a.evidence/'explicit-bottom9-composed-inputs-v2'/case;assert primary.is_dir()
  counterpart=a.evidence/'explicit-bottom9-composition-input2-v1'/case
  if not counterpart.exists():prepare(case,counterpart,2)
  for opt in ('O0','O2'):
   first=opt=='O0' and case in ('cde-pressure-daily','age-pressure-daily')
   label='explicit-bottom9-'+case+'-'+opt+('-v1' if first else '-composition-v1')
   profile=a.evidence/label
   postlabel='explicit-bottom9-'+case+'-'+opt+('-postimage-v1' if first else '-composition-postimage-v1')
   post=a.evidence/postlabel
   if not (profile/'RESULT.json').exists():
    build=allocate(label,opt)
    run(['tests/nomacro_drainage/explicit_bottom9_runtime.py','--input',primary,'--reference-work',a.reference_work,'--build-root',build,'--output',profile,'--case',case,'--optimization',opt])
   else:
    old=json.loads((profile/'RESULT.json').read_text());assert old['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED','Interrupted/failed period requires diagnosis, never automatic replay'
    assert old['case']==case and old['optimization']==opt and Path(old['input_root'])==primary and not git('diff',CORE,old['source'],'--','app','src','tools/solute','tools/vq','reference')
   if not (post/'RESULT.json').exists():
    build=allocate(postlabel,opt)
    run(['tests/nomacro_drainage/explicit_bottom9_postimage.py','--profile',profile,'--input',counterpart,'--reference-work',a.reference_work,'--build-root',build,'--output',post])
   else:assert json.loads((post/'RESULT.json').read_text())['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_INITIAL2_WHOLE_COMPILED_POSTIMAGE_NATIVE_ABI_PASS_NO_MODEL_REPLAY'
   observed=audit(profile,a.reference_work,post);record=a.evidence/(label+'-independent-v1.json')
   if record.exists():assert json.loads(record.read_text())==observed
   else:
    with record.open('x') as out:json.dump(observed,out,indent=2);out.write('\n')
   result['contexts'].append(dict(case=case,optimization=opt,producer=observed['producer'],profile=str(profile),postimage=str(post),independent=str(record),independent_sha256=SHA(record.read_bytes()),reused_completed_period=first));save()
   print('INDEPENDENT_CONTEXT_PASS',case,opt,'completed',len(result['contexts']),flush=True)
 result.update(status='ALL_26_EXPLICIT9_COMPOSITION_CONTEXTS_INDEPENDENT_NATIVE_COLD_POSTIMAGE_PASS_NOT_ADMITTED',contexts_count=26,native_checkpoints=182,exact_cold_windows=78,whole_compiled_postimages=26);assert len(result['contexts'])==26;save()

if __name__=='__main__':main()
