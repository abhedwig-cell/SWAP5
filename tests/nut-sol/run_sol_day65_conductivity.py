"""Measure the real two-provider conductivity cutoff, without a model admission."""
import argparse,hashlib,json,os,shlex,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--swp',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 fixture=a.swp.read_text()
 for text in ['ORES=.032,.04','OSAT=.423,.45','ALFA=.0135,.02','NPAR=1.455,1.6','LEXP=.365,.4','KSATFIT=10.,2.','H_ENPR=0.,0.']:
  assert text in fixture,('foreign fixture',text)
 sources=[ROOT/p for p in ['src/solver/mod_soil_water_solver_contract.f90',
  'src/solver/mod_b110_default_mvg_provider.f90','tests/nut-sol/test_sol_day65_conductivity.f90']]
 fc=shlex.split(os.environ.get('FC','gfortran'));events=[];outputs=[]
 for opt in ['O0','O2']:
  folder=out/opt;folder.mkdir();exe=folder/'curve'
  flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fbacktrace','-J'+str(folder)]
  for kind,cmd in [('compile_link',fc+flags+list(map(str,sources))+['-o',str(exe)]),('native',[str(exe)])]:
   start=time.perf_counter();r=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=60)
   stem=opt+'-'+kind
   for stream in ['stdout','stderr']:(out/(stem+'.'+stream)).write_bytes(getattr(r,stream))
   events.append(dict(command=cmd,category=kind,seconds=time.perf_counter()-start,returncode=r.returncode))
   (out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
   assert r.returncode==0,(r.stdout,r.stderr)
   if kind=='native':
    assert b'SOL_DAY65_REAL_CONDUCTIVITY_CUTOFF_AND_CONTINUOUS_CURVE_PASS'in r.stdout
    outputs.append(r.stdout)
 assert outputs[0]==outputs[1]
 report=dict(status='REAL_CONDUCTIVITY_DISCONTINUITY_O0_O2_CONFIRMED',runtime_repair=False,
  source_sha256={str(p.relative_to(ROOT)):sha(p)for p in sources+[Path(__file__)]},
  swp_sha256=sha(a.swp),events=events,compiler=subprocess.check_output(fc+['--version'],text=True).splitlines()[0])
 (out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status']);print(outputs[0].decode())
if __name__=='__main__':main()
