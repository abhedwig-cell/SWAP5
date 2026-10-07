#!/usr/bin/env python3
import pathlib,re,shutil,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
BUILD=ROOT/'tests/fmig431/.dramet3-build'
if BUILD.exists():shutil.rmtree(BUILD)
BUILD.mkdir(parents=True)
stub=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90'
mods={}
for p in [*ROOT.joinpath('src').rglob('*.f90'),stub]:
    m=re.search(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.I|re.M)
    if m:mods[m.group(1).lower()]=p
def closure(roots):
    out=[];seen=set();active=[]
    def visit(name):
        if name in seen or name not in mods:return
        if name in active:raise RuntimeError(active+[name])
        p=mods[name];active.append(name)
        for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',p.read_text(),re.I|re.M):visit(n.lower())
        active.pop();seen.add(name);out.append(p)
    for root in roots:visit(root)
    return out
testsrc=ROOT/'tests/fmig431/test_swap431_dramet3.f90'
for opt in (0,2):
    out=BUILD/f'o{opt}';out.mkdir()
    flags=['-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(out),'-I',str(out)]
    objs=[]
    for p in closure(['mod_fmr_drainage_response_binding']):
        obj=out/(p.stem+'.o');subprocess.run(['gfortran',*flags,'-c',str(p),'-o',str(obj)],check=True);objs.append(str(obj))
    t=out/'test.o';subprocess.run(['gfortran',*flags,'-c',str(testsrc),'-o',str(t)],check=True)
    exe=out/'test';subprocess.run(['gfortran',f'-O{opt}',*objs,str(t),'-o',str(exe)],check=True)
    cp=subprocess.run([str(exe)],text=True,capture_output=True)
    (out/'output.txt').write_text(cp.stdout+cp.stderr)
    if cp.returncode:sys.stdout.write(cp.stdout);sys.stderr.write(cp.stderr);raise SystemExit(cp.returncode)
    for marker in ['SW431_DRAMET3_SOURCE_SEMANTICS=PASS','SW431_DRAIN_ALLOCATION=PASS','SW431_DRAIN_INF_LIMIT=PASS']:
        assert marker in cp.stdout,marker
    print(f'SW431_DRAMET3_O{opt}=PASS')
    bdir=BUILD/f'backend-o{opt}';bdir.mkdir()
    bflags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace',f'-O{opt}','-J',str(bdir),'-I',str(bdir)]
    for p in closure(['mod_fmr_serialized_reference_backend']):
        obj=bdir/(p.stem+'.o');subprocess.run(['gfortran',*bflags,'-c',str(p),'-o',str(obj)],check=True)
    print(f'SW431_DRAMET3_BACKEND_COMPILE_O{opt}=PASS')
a=(BUILD/'o0/output.txt').read_text();b=(BUILD/'o2/output.txt').read_text()
assert a==b
print('SW431_DRAMET3_O0_O2_IDENTITY=PASS')
