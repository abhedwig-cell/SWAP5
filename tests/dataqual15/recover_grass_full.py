"""Execute an authentic archived Grassgrowth binary without source rebinding."""
import argparse,csv,hashlib,io,json,subprocess,tarfile,time
from pathlib import Path
from grass_full_capsule import ROOT,INPUTS,verify

def recover(output,capsule,manifest):
 proof=verify(capsule,manifest)
 out=Path(output).resolve();out.mkdir(parents=True,exist_ok=False)
 with tarfile.open(capsule,'r:xz')as tar:
  spec=json.load(tar.extractfile('SPEC.json'));full=spec['full']
  def member(name):return tar.extractfile(name).read()
  binary=member('build/O2/swap5_grass_startup')
  exe=out/'swap5_grass_startup';exe.write_bytes(binary);exe.chmod(0o755)
  for name in [*INPUTS,'application.binding']:(out/name).write_bytes(member(full+'/'+name))
  origin=member(full+'/checkpoint-1800.bin');(out/'restart-origin.bin').write_bytes(origin)
  endpoint=member(full+'/checkpoint.bin')
  expected={name:member(full+'/'+name)for name in ['budget.csv','crop.csv','state.csv','endpoint.csv']}
 digest=lambda raw:hashlib.sha256(raw).hexdigest()
 command=[str(exe),'1827','retain-step','100000',str(out/'restart-origin.bin')]
 launch=dict(command=command,executable_sha256=digest(binary),restart_sha256=digest(origin),capsule_sha256=digest(Path(capsule).read_bytes()),source_rebound=False)
 (out/'LAUNCH.json').write_text(json.dumps(launch,indent=2)+'\n')
 start=time.monotonic();censored=False
 with (out/'stdout').open('wb')as stdout,(out/'stderr').open('wb')as stderr:
  try:result=subprocess.run(command,cwd=out,stdout=stdout,stderr=stderr,timeout=300);code=result.returncode
  except subprocess.TimeoutExpired:code=None;censored=True
 report=dict(launch,status='CENSORED'if censored else'FAILED',returncode=code,censored=censored,seconds=time.monotonic()-start,origin_day=1800,end_day=1827,scientific_equivalence=False)
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 assert code==0 and not censored,report
 assert (out/'restart-origin.bin').read_bytes()==origin
 assert (out/'checkpoint.bin').read_bytes()==endpoint,'same-binary endpoint changed'
 rows=lambda raw:list(csv.DictReader(io.StringIO(raw.decode())))
 for name in ['budget.csv','crop.csv']:
  assert rows((out/name).read_bytes())==[row for row in rows(expected[name])if int(row['day'])>1800],name
 for name in ['state.csv','endpoint.csv']:assert(out/name).read_bytes()==expected[name],name
 report.update(status='ARCHIVED_SAME_BINARY_RECOVERY_PASS',complete_native_checkpoint_byte_exact=True,checkpoint_sha256=digest(endpoint),inherited_full_days=proof['full_original_days'])
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 return report

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--capsule',type=Path,default=ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz')
 p.add_argument('--manifest',type=Path,default=ROOT/'integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json');a=p.parse_args()
 print(json.dumps(recover(a.output,a.capsule,a.manifest),indent=2))
