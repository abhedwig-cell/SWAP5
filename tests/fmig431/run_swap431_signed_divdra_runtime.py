#!/usr/bin/env python3
import pathlib,re,shutil,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
BUILD=ROOT/'tests/fmig431/.signed-divdra-build'
if BUILD.exists(): shutil.rmtree(BUILD)
BUILD.mkdir(parents=True)
source=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()
assert subprocess.check_output(['git','diff','--name-only','HEAD','--','src','tests/fmig431'],cwd=ROOT,text=True).strip()==''
print('SW431_SIGNED_SOURCE_TREE='+source,flush=True)
stub=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90'
modules={}
for p in [*ROOT.joinpath('src').rglob('*.f90'),stub]:
    m=re.search(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.I|re.M)
    if m: modules[m.group(1).lower()]=p
ordered=[];seen=set();visiting=[]
def visit(name):
    if name in seen or name not in modules:return
    if name in visiting: raise RuntimeError(visiting+[name])
    p=modules[name];visiting.append(name)
    for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',p.read_text(),re.I|re.M):
        visit(n.lower())
    visiting.pop();seen.add(name);ordered.append(p)
visit('mod_fmr_divdra_serialized_runtime')
fixed=ROOT/'tests/fmr/mod_fmr04_fixed_top_provider.f90'
ordered += [ROOT/'src/legacy/b1_10_port/headcalc.f90',fixed,ROOT/'tests/fmig431/test_swap431_signed_divdra_runtime.f90']
outputs={}
for opt in (0,2):
    out=BUILD/f'o{opt}';out.mkdir()
    flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(out),'-I',str(out)]
    objects=[]
    for p in ordered:
        obj=out/(p.stem+'.o')
        subprocess.run(['gfortran',*flags,'-c',str(p),'-o',str(obj)],check=True)
        objects.append(str(obj))
    exe=out/'test'
    subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,'-o',str(exe)],check=True)
    cp=subprocess.run([str(exe)],cwd=ROOT,text=True,capture_output=True)
    (out/'stdout.txt').write_text(cp.stdout);(out/'stderr.txt').write_text(cp.stderr)
    if cp.returncode:
        sys.stdout.write(cp.stdout);sys.stderr.write(cp.stderr);raise SystemExit(cp.returncode)
    for marker in [
      'SW431_SIGNED_VALID_SINGLE_ACTIVE_CASES=12',
      'SW431_SIGNED_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS',
      'SW431_SIGNED_INACTIVE_EXACT_IDENTITY=PASS',
      'SW431_SIGNED_TWO_ACTIVE_COLUMNS_NO_CROSS_CONTAMINATION=PASS',
      'SW431_SIGNED_FAIL_CLOSED_PREMUTATION_MATRIX=PASS']:
        assert marker in cp.stdout,marker
    assert cp.stdout.count('SW431_SIGNED_SINGLE ')==12
    outputs[opt]=cp.stdout
    print(f'SW431_SIGNED_RUNTIME_O{opt}=PASS',flush=True)
assert outputs[0]==outputs[2]
print('SW431_SIGNED_RUNTIME_O0_O2_IDENTITY=PASS',flush=True)
