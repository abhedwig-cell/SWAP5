"""Resolve heat implementation versus shared formulation on matched explicit inputs.

Original B1.11 is compiled unmodified from immutable authority. No complete
project, accepted-interval reconstruction or full physical energy is claimed.
"""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
from original_sources import build_original
from qualify_energy_boundary import ROOT,SOURCES,inputs

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 raw=inputs();(out/'inputs.dat').write_bytes(raw)
 fc=str(a.compiler.resolve());report=dict(scope='MATCHED_EXPLICIT_COMPONENT_INPUTS_NOT_ACCEPTED_APPLICATION_INTERVALS',
  baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  input_sha256=hashlib.sha256(raw).hexdigest(),production_changed=False,full_energy_complete=False,builds={},
  source_sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in SOURCES[:5]+['tests/dataqual15/paired_heat_owner.f90','tests/dataqual15/qualify_paired_heat_owner.py']})
 for opt in ('O0','O2'):
  start=time.monotonic();ref=build_original(out/('original-'+opt),fc,opt)
  folder=out/opt;folder.mkdir();flags=['-'+opt,'-g','-ffree-line-length-none','-fcheck=all',
   '-fbacktrace','-I'+str(folder),'-J'+str(folder),'-I'+str(ref/'swobj'),'-I'+str(ref/'ttobj')]
  sources=[str(ROOT/p)for p in SOURCES[:5]]+[str(ROOT/'tests/dataqual15/paired_heat_owner.f90')]
  command=[fc,*flags,*sources,*map(str,sorted((ref/'swobj').glob('*.o'))),str(ref/'ttobj/libttutil.a'),'-o',str(folder/'paired')]
  compile=subprocess.run(command,cwd=folder,capture_output=True,timeout=120)
  (folder/'compile.stdout').write_bytes(compile.stdout);(folder/'compile.stderr').write_bytes(compile.stderr)
  assert compile.returncode==0,compile.stderr.decode(errors='replace')[-4000:]
  run=subprocess.run([folder/'paired',out/'inputs.dat'],cwd=folder,capture_output=True,timeout=120)
  (folder/'stdout').write_bytes(run.stdout);(folder/'stderr').write_bytes(run.stderr)
  assert run.returncode==0,run.stderr.decode(errors='replace')[-4000:]
  rows=[line.split(',')for line in run.stdout.decode().splitlines()if line.startswith('PAIR,')]
  assert len(rows)==432
  maxima={str(kind):max(abs(float(row[5]))for row in rows if int(row[2])==kind)for kind in range(4)}
  report['builds'][opt]=dict(command=command,seconds=time.monotonic()-start,cases=len(rows),
   max_temperature_difference_c=max(float(r[3])for r in rows),max_capacity_difference=max(float(r[4])for r in rows),
   max_boundary_energy_difference_j_cm2=max(float(r[8])for r in rows),
   shared_physical_gap_j_cm2_by_kind=maxima,stdout_sha256=hashlib.sha256(run.stdout).hexdigest())
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 report['O0_O2_stdout_exact']=(out/'O0/stdout').read_bytes()==(out/'O2/stdout').read_bytes()
 report['status']='MATCHED_OWNERS_PASS_SHARED_FORMULATION_LIMITATION_RETAINED'
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
