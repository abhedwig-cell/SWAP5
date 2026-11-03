"""Actual native transport inventory and real production liquid enthalpy driver."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
from analyze_transport_donors import analyze
from analyze_native_thermal_receipts import analyze as heat
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('folder',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False)
 thermal=(a.folder/'actual-thermal.csv').read_bytes();transport=(a.folder/'actual-transport.csv').read_bytes();r,cases=analyze(thermal,transport);r['thermal']=heat(thermal)
 r['measurement_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();sources=['src/process/mod_liquid_water_sensible_enthalpy.f90','tests/dataqual15/research/liquid_donor_driver.f90','tests/dataqual15/qualify_transport_donors.py','tests/dataqual15/analyze_transport_donors.py','tests/dataqual15/analyze_native_thermal_receipts.py'];r['source_git_blob']={x:subprocess.check_output(['git','rev-parse','HEAD:'+x],cwd=ROOT,text=True).strip() for x in sources};assert not subprocess.check_output(['git','diff','HEAD','--',*sources],cwd=ROOT)
 r['input_sha256']={n:hashlib.sha256(raw).hexdigest() for n,raw in [('actual-thermal.csv',thermal),('actual-transport.csv',transport)]}
 data=out/'donors.dat';data.write_text(''.join(' '.join(format(v,'.17e') for v in row)+'\n' for row in cases),encoding='utf-8');r['root_donor_scenarios']=len(cases);r['builds']={}
 for opt in ('O0','O2'):
  build=out/opt;build.mkdir();exe=build/'donor.exe';cmd=['gfortran','-'+opt,'-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fbacktrace','-J'+str(build),'-I'+str(build),str(ROOT/sources[0]),str(ROOT/sources[1]),'-o',str(exe)]
  start=time.monotonic();cp=subprocess.run(cmd,cwd=build,capture_output=True);(build/'build.stdout').write_bytes(cp.stdout);(build/'build.stderr').write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode()
  cp=subprocess.run([exe,data],cwd=build,capture_output=True);(build/'run.stdout').write_bytes(cp.stdout);(build/'run.stderr').write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode();assert b'UNKNOWN_DONOR_CONTROLS_PASS' in cp.stdout
  r['builds'][opt]=dict(seconds=time.monotonic()-start,command=cmd,stdout=cp.stdout.decode(),executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest())
 assert r['builds']['O0']['stdout']==r['builds']['O2']['stdout']
 # Corrupt actual, nonzero native records; independent ledger checks must refuse.
 controls={}
 for label,kind,col in [('macro-face','MACRO',6),('matrix-source','MATRIX',7),('macro-negative-stock','MACRO',5)]:
  rows=transport.decode().splitlines()
  for i,row in enumerate(rows):
   v=row.split(',')
   if v[0]==kind:
    v[col]=str(-1. if label=='macro-negative-stock' else float(v[col])+1.);rows[i]=','.join(v);break
  try:analyze(thermal,('\n'.join(rows)+'\n').encode())
  except AssertionError:controls[label]='REJECTED'
  else:raise AssertionError('accepted corrupt '+label)
 r['corrupt_actual_data_controls']=controls;r['compiler']=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0]
 (out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8');print('ACTUAL_TRANSPORT_AND_ENDPOINT_DONOR_SCENARIOS_O0_O2_PASS_FULL_ENERGY_OPEN')
if __name__=='__main__':main()
