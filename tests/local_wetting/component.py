from pathlib import Path
import argparse,hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import local_wetting_time as pulse
def main():
 p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
 ref=a.reference_work/'build';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();result={'policy':pulse.POLICY,'profiles':{}}
 for opt in ('O0','O2'):
  out=(a.output/opt).resolve();out.mkdir();src=out/'timecontrol.f90';src.write_bytes(pulse.source((ref/'swap-selected/timecontrol.f90').read_bytes()))
  flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-ffp-contract=off','-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj')]
  exe=out/'component.exe';commands=[['gfortran',*flags,'-c',str(src)],['gfortran',*flags,str(Path(__file__).with_suffix('.f90')),str(out/'timecontrol.o'),*[str(x) for x in sorted((ref/'swap-obj').glob('*.o')) if x.name not in ('timecontrol.o','swap_main.o')],str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)],[str(exe)]]
  logs=[]
  for cmd in commands:
   r=subprocess.run(cmd,cwd=out,capture_output=True,text=True,timeout=30);logs.append(r.stdout+r.stderr);(out/'logs').write_text('\n'.join(logs));assert r.returncode==0,logs[-1]
  assert 'PULSE_COMPONENT_PASS' in logs[-1]
  result['profiles'][opt]=dict(commands=commands,source_sha256=sha(src),driver_sha256=sha(Path(__file__).with_suffix('.f90')),executable_sha256=sha(exe),stdout=logs[-1])
 (a.output/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps(result['profiles'],indent=2)[:200])
if __name__=='__main__':main()
