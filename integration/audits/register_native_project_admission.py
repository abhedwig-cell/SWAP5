"""Register exact source/evidence postimages; never assert canonical admission."""
import argparse,base64,io,json,subprocess,tarfile
from pathlib import Path
from native_project_admission import ROOT,BASE,STATUS,SCIENCE,child,sha,unpack,projection,NUT_PARENT,CYCLE_PARENT
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--evidence',type=Path,required=True);a=ap.parse_args()
 evidence=a.evidence.resolve();raw=base64.b64decode(evidence.read_bytes());f=unpack(raw)
 current=json.loads(f['ASSESSMENT.json']);assert current['baseline']==BASE
 for p,h in current['current_inputs'].items():assert sha((ROOT/p).read_bytes())==h,(p,'not current executed evidence')
 assert (ROOT/'integration/performance/verify_weather_line_search_successor.py').read_bytes()==projection()
 assert (ROOT/NUT_PARENT).read_bytes()==projection(NUT_PARENT)
 assert (ROOT/CYCLE_PARENT).read_bytes()==projection(CYCLE_PARENT)
 delta={line.split('\t')[1]:line.split('\t')[0]for line in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--',*SCIENCE],cwd=ROOT,text=True).splitlines()}
 status=json.loads((ROOT/STATUS).read_text());owner=child(status)
 previous=owner.get('source_admission',{})
 prior=json.loads(subprocess.check_output(['git','show',BASE+':benchmarks/performance/PERF01_LINE_SEARCH_RETRY_20261022_STATUS.json'],cwd=ROOT))['source_successor']
 inputs=dict(current['current_inputs'])
 # Unchanged canonical component authorities and original native admission body.
 for p in ['integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json','tests/fci/run_fci93_non_m1_fixed_k_qualification.sh',
           'integration/performance/authority.py','integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json']:
  baseline=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT);assert (ROOT/p).read_bytes()==baseline;inputs[p]=sha(baseline)
 r=dict(baseline=BASE,source_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in delta if p!=STATUS},
  source_inputs=inputs,evidence=dict(path=str(evidence.relative_to(ROOT)),decoded_sha256=sha(raw),decoded_bytes=len(raw),members=len(f)),
  frozen_fsi35_successors=prior['frozen_fsi35_successors'],qualified_science=False,qualified_fsi35=False,canonically_admitted=False,
  scope='EXPLICIT_NATIVE_PROJECT_AND_NUMERICAL_OPTIONS_WITH_CURRENT_DEFAULT_PRESERVATION',
  full_historical_migration=False,next_action='Complete current source and corruption controls and original independent FSI35 O0/O2 body before canonical admission.')
 native_path='integration/audits/evidence/MC_SOL01_NATIVE_FSI35_20261023.tar.xz'
 native=(ROOT/native_path).read_bytes()
 with tarfile.open(fileobj=io.BytesIO(native),mode='r:xz')as t:
  terminal=json.load(t.extractfile('RESULT.json'));stdout=t.extractfile('stdout').read()
 assert terminal['status']=='PASS'and terminal['returncode']==0 and sha(stdout)==terminal['raw_sha256']['stdout']
 assert b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in stdout
 for p,h in terminal['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('current original native input',p)
 r['native_fsi35']=dict(path=native_path,sha256=sha(native));r['qualified_fsi35']=True
 if previous.get('postimages')==r['postimages']and previous.get('source_inputs')==r['source_inputs']:
  for key in ['source_controls','qualified_science']:
   if key in previous:r[key]=previous[key]
 owner['source_admission']=r
 (ROOT/STATUS).write_text(json.dumps(status,indent=2)+'\n')
 print(json.dumps(dict(scientific_paths=len(delta),current_inputs=len(inputs),decoded_sha256=sha(raw))))
if __name__=='__main__':main()
