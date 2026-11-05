"""Run original sharp-entry input from initialization with current numerical input.

Prepared forcing is reused byte for byte; no archived executable or checkpoint
is executed. A time-censored prefix never qualifies the 481-day request.
"""
import argparse,csv,hashlib,json,os,subprocess,tarfile,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--seconds',type=int,default=90);a=p.parse_args()
 out=a.output.resolve();out.mkdir()
 bundle=a.bundle.resolve();meta=json.loads((bundle/'column/build-complete.json').read_text())
 exe=bundle/'column/swap5_solute_project'
 if not exe.exists():exe=exe.with_suffix('.exe')
 assert sha(exe.read_bytes())==meta['executable_sha256']
 assert all(sha((ROOT/n).read_bytes())==h for n,h in meta['input_sha256'].items())
 historical=json.loads((ROOT/'integration/dataqual15/CLOSURE16_CURRENT_ANDELST_RESULT.json').read_text())
 with tarfile.open(ROOT/'integration/dataqual15/CLOSURE16_CURRENT_ANDELST_EVIDENCE.tar.xz')as t:
  launch=json.loads(t.extractfile('sharp/LAUNCH.json').read())
 archive=ROOT/'integration/dataqual15/ANDELST_CONTACT_DIAGNOSTIC.tar.xz'
 assert sha(archive.read_bytes())==launch['archive_sha256']
 with tarfile.open(archive)as t:
  for name,pin in launch['physical_input_sha256'].items():
   raw=t.extractfile('run/'+name).read();assert sha(raw)==pin
   (out/name).write_bytes(raw)
 assert (out/'input.swp').read_bytes()==(ROOT/'reference/swap-4.3.1/projects/3.macroporeflow/swap.swp').read_bytes()
 binding=sha(b''.join((out/n).read_bytes()for n in ['input.nml','input.swp','macro.nml'])+sha(exe.read_bytes()).encode())
 command=launch['command'];command[0]=str(exe);command[6]=binding
 assert command[2]=='-' and command[3]=='481' and command[9]==''
 record=dict(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  command=command,original_sharp_entry=True,original_initialization=True,source_numerical_controls=True,
  original_input_sha256=launch['physical_input_sha256'],source_sha256=meta['input_sha256'],
  executable_sha256=sha(exe.read_bytes()),timeout_seconds=a.seconds,full_original_complete=False,
  historical_scope=historical['scope'])
 (out/'LAUNCH.json').write_text(json.dumps(record,indent=2)+'\n')
 start=time.monotonic();censored=False
 with(out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
  try:r=subprocess.run(command,cwd=out,env=dict(os.environ,OMP_NUM_THREADS='1'),stdout=so,stderr=se,timeout=a.seconds);code=r.returncode
  except subprocess.TimeoutExpired:code=None;censored=True
 rows=lambda n:list(csv.DictReader((out/n).open()))if(out/n).exists()else[]
 daily=rows('budget.csv');progress=rows('progress.csv');cost=rows('cost.csv')
 record.update(returncode=code,censored=censored,seconds=time.monotonic()-start,
  completed_days=int(daily[-1]['day'])if daily else 0,last_completed_source_interval=float(progress[-1]['t1'])if progress else 0,
  maximum_water_residual_cm=max((abs(float(r['water_residual_cm']))for r in daily),default=None),cost=cost,
  full_original_complete=code==0 and len(daily)==481)
 record['numerical_controls_observed']=[s for s in(out/'stdout').read_text().splitlines()if 'ORIGINAL_NATIVE_NUMERICAL_CONTROLS'in s]
 record['files_sha256']={f.name:sha(f.read_bytes())for f in out.iterdir()if f.is_file()}
 (out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({k:v for k,v in record.items()if k not in ['source_sha256','files_sha256','cost','original_input_sha256']},indent=2))

if __name__=='__main__':main()
