"""Actual original reader-supported tighter root inputs, no model change."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,sys,time
import implicit_conductivity_runtime as c
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output','input-source'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();inputs=a.output/'input';shutil.copytree(a.input_source,inputs)
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),optimization=a.optimization,original_input_source=str(a.input_source),selection='Explicit original crop precision tightening at unchanged physical/numerical model source; head5 geometric mean positive chemistry. All35day/native gates before1096day/native. Water/CDE guards unchanged1e-10. NOT whole qualification.',input_delta={},executions=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 sha=lambda b:hashlib.sha256(b).hexdigest()
 try:
  q['crops']={}
  for name in ('maize.crp','potato.crp','grass.crp'):
   crop=inputs/name;raw=crop.read_bytes();text=raw.decode('cp1252')
   for key,value in dict(TOL_2='1.0d-10',MYTOLX='1.0d-10',TOLCONV='1.0d-9').items():text=assignment(text,key,value)
   crop.write_text(text,encoding='cp1252');q['crops'][name]=dict(before_sha256=sha(raw),after_sha256=sha(crop.read_bytes()),explicit_original_reader_values=dict(TOL_2=1e-10,MYTOLX=1e-10,TOLCONV=1e-9))
  before={str(f.relative_to(a.input_source)):sha(f.read_bytes()) for f in a.input_source.rglob('*') if f.is_file()};after={str(f.relative_to(inputs)):sha(f.read_bytes()) for f in inputs.rglob('*') if f.is_file()};assert before.keys()==after.keys();q['input_delta']={k:dict(before=before[k],after=after[k]) for k in before if before[k]!=after[k]};assert set(q['input_delta'])==set(q['crops']);save()
  for phase in ('short','full'):
   root=a.output/phase;cmd=[sys.executable,'-B',str(Path(__file__).with_name('implicit_conductivity_runtime.py')),'--reference-work',str(a.reference_work),'--output',str(root),'--optimization',a.optimization,'--solute','1','--hysteresis','0','--bottom','5','--kmean','3','--perstep','--mode','explicit','--format','3','--reset','1','--existing-input',str(inputs),'--phase',phase]
   if phase=='full':cmd+=['--reuse-build',q['short']['build_root']]
   start=time.perf_counter();v=subprocess.run(cmd,cwd=c.ROOT,capture_output=True,text=True,timeout=600);(a.output/(phase+'.stdout')).write_text(v.stdout);(a.output/(phase+'.stderr')).write_text(v.stderr);q['executions'].append(dict(command=cmd,returncode=v.returncode,seconds=time.perf_counter()-start));save();v.check_returncode();q[phase]=json.loads((root/'RESULT.json').read_text());assert q[phase]['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_'+phase.upper()+'_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS';save();print(phase,'ACTUAL_ORIGINAL_TIGHT_ROOT_PRECISION_NATIVE_PASS',flush=True)
  q['status']='ACTUAL_ORIGINAL_TIGHT_ROOT_PRECISION_POSITIVE_HEAD_SHORT_FULL_NATIVE_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
