"""Compile literal original meteo/Rutter, with selected partition correction."""
from pathlib import Path
import argparse,json,subprocess,sys,hashlib
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from extended_interception import render

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser()
 for k in ('provider','build-root','output'):p.add_argument('--'+k,type=Path,required=True)
 p.add_argument('--optimization',choices=['O0','O2'],required=True)
 a=p.parse_args();a.output.mkdir();original=a.provider/'build/swap-src/SWAP/MOD_meteo.f90';text=original.read_text(encoding='cp1252')
 for mode in ('original','corrected'):
  out=a.build_root/mode;out.mkdir(parents=True);source=out/'MOD_meteo.f90';source.write_text(text if mode=='original' else render(text),encoding='cp1252')
  provider=a.provider/'build/swap-obj';flags=['gfortran','-'+a.optimization,'-cpp','-Dlinux','-ffp-contract=off','-march=x86-64','-mtune=generic','-ffree-line-length-none','-I',str(out),'-I',str(provider),'-J',str(out)]
  commands=[flags+['-c',str(source),'-o',str(out/'MOD_meteo.o')]]
  objects=[out/'MOD_meteo.o' if f.name=='MOD_meteo.o' else f for f in sorted(provider.glob('*.o')) if f.name!='swap_main.o'];driver=ROOT/'tests/nomacro_drainage/test_original_positive_interception.f90';exe=out/'probe.exe'
  commands.append(flags+[str(driver),*map(str,objects),str(a.provider/'build/ttutil-obj/libttutil.a'),'-o',str(exe)]);logs=[]
  for command in commands:
   r=subprocess.run(command,cwd=out,capture_output=True,text=True);logs.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
  r=subprocess.run([str(exe),mode],cwd=out,capture_output=True,text=True)
  for f in (source,exe):(a.output/(mode+'-'+f.name)).write_bytes(f.read_bytes())
  report=dict(mode=mode,optimization=a.optimization,source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),original_sha256=sha(original),source_sha256=sha(source),driver_sha256=sha(driver),executable_sha256=sha(exe),objects={str(f):sha(f) for f in objects},compile=logs,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr)
  (a.output/(mode+'.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf8');print(mode,r.returncode,r.stdout,flush=True);assert r.returncode==0,r.stderr

if __name__=='__main__':main()
