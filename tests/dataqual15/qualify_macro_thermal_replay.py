"""Replay immutable native hydraulic data with explicit modeled macro thermal inputs."""
import argparse,hashlib,json,subprocess,tarfile,time
from pathlib import Path
from analyze_transport_donors import analyze
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False)
 capsule=ROOT/'integration/dataqual15/COUPLED_CONTACT_WINDOWS_EVIDENCE_20261103.tar.xz';record=json.loads((ROOT/'integration/dataqual15/COUPLED_CONTACT_WINDOWS_EVIDENCE_20261103.json').read_text(encoding='utf-8'));assert hashlib.sha256(capsule.read_bytes()).hexdigest()==record['archive_sha256']
 with tarfile.open(capsule) as t:heat=t.extractfile('O0/actual-prefix/actual-thermal.csv').read();water=t.extractfile('O0/actual-prefix/actual-transport.csv').read()
 audit,cases=analyze(heat,water);thermal={};macro={};intervals={}
 for line in heat.decode().splitlines():
  r=line.split(',');key=(float(r[1]),float(r[2]));node=int(r[3]);thermal[key+(node,)]=[float(r[4]),float(r[5])];intervals[key]=True
 for line in water.decode().splitlines():
  r=line.split(',')
  if r[0]=='MACRO':macro[(float(r[1]),float(r[2]),int(r[3]),int(r[4]))]=list(map(float,r[5:]))
 nd=max(k[2] for k in macro);n=112;data=out/'explicit_thermal_inputs.dat';rows=[f'{len(intervals)} {nd} {n}']
 for t0,t1 in sorted(intervals):
  rows.append(f'{t0:.17e} {t1:.17e}')
  for node in range(1,n+1):rows.append(' '.join(format(x,'.17e') for x in thermal[(t0,t1,node)]))
  for domain in range(1,nd+1):
   rows.append(f'{8.+4.*t0:.17e} {8.+4.*t1:.17e}')
   for node in range(1,n+1):rows.append(' '.join(format(x,'.17e') for x in macro[(t0,t1,domain,node)]))
 data.write_text('\n'.join(rows)+'\n',encoding='utf-8',newline='\n')
 paths=['src/solver/mod_reference_linear_solver.f90','tests/dataqual15/research/mod_macro_liquid_thermal.f90','tests/dataqual15/research/macro_native_thermal_driver.f90','tests/dataqual15/qualify_macro_thermal_replay.py','tests/dataqual15/analyze_transport_donors.py'];git=lambda *x:subprocess.check_output(['git',*x],cwd=ROOT,text=True).strip();assert not git('diff','HEAD','--',*paths),'persist first'
 report=dict(measurement_commit=git('rev-parse','HEAD'),source_git_blob={x:git('rev-parse','HEAD:'+x) for x in paths},hydraulic_capsule_sha256=record['archive_sha256'],input_sha256=hashlib.sha256(data.read_bytes()).hexdigest(),hydraulic_audit=audit,model=dict(initial_macro_temperature='Explicit initial thermal equilibrium with measured matrix start profile',external_macro_top_temperature_c='Prescribed research scenario8+4*t(day), not a historical measurement',matrix_temperature_path='Declared piecewise linear between actual legacy thermal endpoints, without matrix heat feedback',time_rule='Conservative implicit upwind/right-endpoint donor quadrature refined1/4/16/64 per hydraulic interval',gas_latent_radiation=False,full_physical_energy_complete=False),compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],builds={})
 for opt in ['O0','O2']:
  build=out/opt;build.mkdir();exe=build/'replay.exe';cmd=['gfortran','-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build),*[str(ROOT/x) for x in paths[:3]],'-o',str(exe)];start=time.monotonic();cp=subprocess.run(cmd,cwd=build,capture_output=True);(build/'compile.stderr').write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode();cp=subprocess.run([exe,data],cwd=build,capture_output=True);(build/'run.stdout').write_bytes(cp.stdout);(build/'run.stderr').write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode();report['builds'][opt]=dict(seconds=time.monotonic()-start,stdout=cp.stdout.decode().replace('\r\n','\n'),executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),files_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in build.glob('*.csv')})
 assert report['builds']['O0']['stdout']==report['builds']['O2']['stdout'];assert report['builds']['O0']['files_sha256']==report['builds']['O2']['files_sha256']
 report['status']='ACTUAL_HYDRAULIC_REPLAY_INDEPENDENT_MACRO_TEMPERATURE_AND_REFINED_EXPLICIT_DONORS_PASS';(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report['status']);print(report['builds']['O0']['stdout'])
if __name__=='__main__':main()
