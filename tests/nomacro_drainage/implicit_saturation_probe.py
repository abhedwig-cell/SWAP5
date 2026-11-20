"""Actual complete original MOD_MvG source/executable component custody."""
import argparse,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from extended_implicit_saturation import source as corrected
from donor_sources import sha

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('provider','baseline-build','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();a.build_root.mkdir(parents=True)
 baseline=a.baseline_build/'MOD_MvG_functions.f90';driver=Path(__file__).with_name('test_extended_implicit_saturation.f90');objects=a.provider/'build/swap-obj';tt=a.provider/'build/ttutil-obj'
 original=[p for p in sorted(objects.glob('*.o')) if p.name not in ('swap_main.o','MOD_MvG_functions.o')]
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,actual_baseline_build_sha256=sha(a.baseline_build/'BUILD.json'),actual_baseline_source_sha256=sha(baseline),driver_sha256=sha(driver),renderer_sha256=sha(ROOT/'app/hybrid_water/extended_implicit_saturation.py'),original_objects={p.name:sha(p) for p in original},ttutil_sha256=sha(tt/'libttutil.a'),modes={})
 for mode in ('original','corrected'):
  build=a.build_root/mode;build.mkdir();path=build/'MOD_MvG_functions.f90';text=baseline.read_text(encoding='cp1252');path.write_text(corrected(text) if mode=='corrected' else text,encoding='cp1252');exe=build/'probe.exe'
  flags=['gfortran','-'+a.optimization,'-ffp-contract=off','-march=x86-64','-mtune=generic','-ffree-line-length-none','-fcheck=all','-I',str(build),'-I',str(objects),'-I',str(tt)]
  commands=[flags+['-c',str(path),'-o',str(build/'MOD_MvG_functions.o')],flags+[str(driver),str(build/'MOD_MvG_functions.o'),*map(str,original),str(tt/'libttutil.a'),'-o',str(exe)]];logs=[]
  for command in commands:
   v=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=60);logs.append(dict(command=command,returncode=v.returncode,stdout=v.stdout,stderr=v.stderr));(a.output/(mode+'-compile.json')).write_text(json.dumps(logs,indent=2));v.check_returncode()
  v=subprocess.run([str(exe)],cwd=build,capture_output=True,text=True,timeout=30);(a.output/(mode+'.stdout')).write_text(v.stdout);(a.output/(mode+'.stderr')).write_text(v.stderr)
  for f in (path,exe):shutil.copyfile(f,a.output/(mode+'-'+f.name))
  q['modes'][mode]=dict(returncode=v.returncode,source_sha256=sha(path),executable_sha256=sha(exe));(a.output/'RESULT.json').write_text(json.dumps(q,indent=2));v.check_returncode();assert 'ACTUAL_ORIGINAL_SATURATION_COMPONENT_COMPLETE 32' in v.stdout
 q['status']='ACTUAL_ORIGINAL_AND_CORRECTED_MUALem_COMPONENT_BYTES_CAPTURED_PENDING_INDEPENDENT_SCIENCE';(a.output/'RESULT.json').write_text(json.dumps(q,indent=2));print(q['status'],a.optimization)
if __name__=='__main__':main()
