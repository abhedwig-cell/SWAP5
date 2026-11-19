"""Two-day native seam after orthogonal canonical groundwater composition."""
from pathlib import Path
import argparse,json,subprocess,sys,time,zipfile
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import physical,rows,check,csvlines
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);a=p.parse_args();w=a.work;w.mkdir(parents=True,exist_ok=True)
record=dict(source=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),scope='Actual two-day O0/O2 composed SaltFarm native seams; qualified full trajectories inherited by exact generated Fortran and complete input-word preservation',optimizations={})
with zipfile.ZipFile(ROOT/'integration/f-ci/saltfarm-typed07/TYPED_UBUNTU.zip') as gold:
 for opt in ('O0','O2'):
  out=w/opt;out.mkdir();build=out/'build';base=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',h.SALTFARM.model,'--no-macro-release','--reference-work',str(w/'provider')];calls=[]
  def run(extra):
   cmd=[*base,*map(str,extra)];start=time.perf_counter();r=subprocess.run(cmd,capture_output=True,text=True,timeout=120);calls.append(dict(command=cmd,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
  run(['--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',build]);meta,case=validate_bundle(build,w/'provider',h.SALTFARM)
  expected={Path(n).name:gold.read(n) for n in gold.namelist() if n.startswith('qualified-'+opt+'/') and n.endswith('.f90')};assert {p.name:p.read_bytes() for p in build.glob('*.f90')}==expected
  prior=json.loads(gold.read('qualified-'+opt+'/BUILD.json'));assert meta['inputs']==prior['inputs'] and meta['identity']['kernel_sources']==prior['identity']['kernel_sources']
  for dest,cut in [('warm',1),('warm-endpoint',2)]:run(['--build-bundle',build,'--days',2,'--checkpoint-at',cut,'--timeout-seconds',15,'--output',out/dest])
  origin=out/'warm/accepted-column-1-day-1.zip';digest=h.sha(origin);run(['--build-bundle',build,'--days',2,'--checkpoint-at',2,'--restart',origin,'--restart-day',1,'--timeout-seconds',15,'--output',out/'cold'])
  warm=rows(out/'warm');cold=rows(out/'cold');endpoint=rows(out/'warm-endpoint');original=[json.loads(x) for x in gold.read('accept-'+opt+'/full/daily.jsonl').splitlines()]
  for data in (warm,cold,endpoint):check(data)
  assert physical(warm)==physical(endpoint)==physical(original[:2]) and physical(cold)==physical(warm[1:]) and h.sha(origin)==digest
  for member in ('result.end','macro.bin'):
   with zipfile.ZipFile(out/'cold/accepted-column-1-day-2.zip') as x,zipfile.ZipFile(out/'warm-endpoint/accepted-column-1-day-2.zip') as y:assert x.read(member)==y.read(member)
  assert csvlines(out/'cold/original/result_output.csv')[-1:]==csvlines(out/'warm/original/result_output.csv')[-1:]
  record['optimizations'][opt]=dict(status='ACTUAL_COMPOSED_TWO_DAY_NATIVE_COLD_AND_GENERATED_FORTRAN_EXACT',calls=calls,build_sha256=h.sha(build/'BUILD.json'),budgets=check(warm))
(w/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
