"""Use the literal admitted external transaction control for Snow vapor."""
import argparse,json,subprocess,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import original_output_controls as inherited


def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','output','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir()
 path='tests/nomacro_scheduled_subsurface/original_output_controls.py'
 assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','8e27dd9eb0f633050d2d82d00d28992435c313cb:'+path],cwd=ROOT)
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),contexts={},canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  for kind in ('water','cde'):
   for opt in ('O0','O2'):
    label=f'snow-vapor-{kind}-{opt}-v3';profile=a.evidence/label;item=json.loads((profile/'RESULT.json').read_text())
    project=inherited.m.e.load(item['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    q['contexts'][label]=inherited.transactions(Path(item['build_root']),a.reference_work,project,profile/'trajectory',a.output/label);save()
  assert len(q['contexts'])==4;q['status']='FOUR_ACTUAL_SNOW_VAPOR_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVERY_CONTEXTS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],flush=True)


if __name__=='__main__':main()
