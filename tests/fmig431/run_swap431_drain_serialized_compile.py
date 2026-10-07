#!/usr/bin/env python3
import pathlib,re,shutil,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
files=list(ROOT.joinpath('src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']
modules={}
for path in files:
    text=path.read_text(errors='ignore')
    m=re.search(r'^\s*module\s+(?!procedure\b)(\w+)',text,re.I|re.M)
    if m: modules[m.group(1).lower()]=path
seen=set(); ordered=[]; visiting=[]
def visit(name):
    if name in seen or name not in modules:return
    if name in visiting: raise RuntimeError('dependency cycle '+name)
    path=modules[name]; visiting.append(name)
    text=path.read_text(errors='ignore')
    for used in dict.fromkeys(x.lower() for x in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',text,re.I|re.M)):
        visit(used)
    visiting.pop(); seen.add(name); ordered.append(path)
for root in ['mod_fmr_divdra_serialized_runtime','mod_fmr_production_application_bootstrap']:
    visit(root)
build=pathlib.Path(tempfile.mkdtemp(prefix='swap431-drain-runtime-compile-'))
try:
    for opt in (0,2):
        out=build/f'o{opt}';out.mkdir()
        for path in ordered:
            obj=out/(path.stem+'.o')
            subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-w','-fopenmp',
                '-fcheck=all','-fbacktrace',f'-O{opt}','-J',str(out),'-I',str(out),'-c',str(path),'-o',str(obj)],check=True)
        print(f'SW431_DRAIN_SERIALIZED_COMPILE_O{opt}=PASS')
    print('SW431_DRAIN_SERIALIZED_COMPILE=PASS')
finally:
    shutil.rmtree(build,ignore_errors=True)
