"""Compile a read-only instrumented HeadCalc copy; never edit native source."""
import argparse,hashlib,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--compiler',required=True);p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[3];a.output.mkdir(parents=True,exist_ok=True)
original=root/'src/legacy/b1_10_port/headcalc.f90';source=original.read_text();anchor='      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.';assert source.count(anchor)==1
added='''
      if (solver_numbit == MaxIt1 .and. flnonconv) then
         print *, 'STRIP_HEADCALC_GATE',dt,maxval(abs(fsi_ws%residual(1:NN))),abs(sum1), &
              maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))/max(1.0d0,abs(fsi_ws%old_head(1:NN)))), &
              CritDevBalCp,CritDevBalTot,CritDevh1Cp,CritDevh2Cp
      end if
'''
source=source.replace(anchor,anchor+added);copy=a.output/'headcalc_observed.f90';copy.write_text(source);obj=a.output/'headcalc_observed.o';subprocess.run([a.compiler,'-std=f2008','-ffree-line-length-none','-fPIC','-fopenmp','-O2','-J',str(a.build),'-I',str(a.build),'-c',str(copy),'-o',str(obj)],check=True)
objects=[str(x) for x in sorted(a.build.glob('*.o')) if x.name!='headcalc.o'];subprocess.run([a.compiler,'-shared','-fopenmp',*objects,str(obj),'-o',str(a.output/'libstrip01_observed.so')],check=True)
(a.output/'manifest.json').write_text(json.dumps(dict(original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),observed_copy_sha256=hashlib.sha256(copy.read_bytes()).hexdigest(),change='PRINT_ONLY_NO_NUMERICAL_MUTATION'),indent=2)+'\n')
