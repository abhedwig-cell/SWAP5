#!/usr/bin/env python3
"""Build the existing real production closure; retain objects for local diagnosis."""
from pathlib import Path
import re, shlex, subprocess, sys, json, hashlib, time
root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]).resolve(); out.mkdir(parents=True,exist_ok=True)
opt=sys.argv[2] if len(sys.argv)>2 else '-O2'
s=(root/'tests/fapp/run_ppa_wu01_production_application_bootstrap.sh').read_text()
sources=[shlex.split(l)[0] for l in re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)[1].splitlines() if l.strip()]
if len(sys.argv)>3: sources[0]=sys.argv[3]
sources=subprocess.check_output(['python3','tests/support/augment_bartholomeus_backend_sources.py',*sources],cwd=root,text=True).splitlines()
flags=['-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',opt,'-J',str(out),'-I',str(out)]
start=time.monotonic(); objects=[]
continuous=len(sys.argv)>4 and sys.argv[4]=='continuous'
compiled_sources={}

for src in sources+['research/kalmthout_pilot/kalmthout_swap5_pilot.f90']:
    source_path=root/src
    if continuous and src=='src/solver/mod_b110_default_mvg_provider.f90':
        text=source_path.read_text()
        before='else if (relsat > (1.0_real64-1.0e-6_real64)) then'
        assert text.count(before)==1, 'hydraulic source changed: reconcile candidate patch'
        source_path=out/'continuous_mvg_provider.f90'
        source_path.write_text(text.replace(before,'else if (head >= 0.0_real64) then'))
    compiled_sources[src]=hashlib.sha256(source_path.read_bytes()).hexdigest()
    obj=out/(Path(src).stem+'.o'); objects.append(str(obj))
    subprocess.run(['gfortran',*flags,'-c',str(source_path),'-o',str(obj)],cwd=root,check=True)
subprocess.run(['gfortran','-fopenmp',opt,*objects,'-o',str(out/'pilot')],cwd=root,check=True)
(out/'build.json').write_text(json.dumps({'flags':flags,'compiler':subprocess.check_output(['gfortran','--version'],text=True),'seconds':time.monotonic()-start,'continuous_mvg_experiment':continuous,'sources':compiled_sources},indent=2))
print('LOCAL_BUILD_COMPLETE',len(sources),time.monotonic()-start)
