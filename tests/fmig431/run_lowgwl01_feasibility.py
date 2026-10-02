#!/usr/bin/env python3
"""Negative feasibility evidence, not mode-1 production qualification."""
import hashlib,json,os,pathlib,re,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
TEST=ROOT/'tests/fmig431/test_lowgwl01_feasibility.f90'
FC=shlex.split(os.environ.get('FC','gfortran'))
LINK=shlex.split(os.environ.get('FMR_FC_LINK_FLAGS',''))
modules={}
for p in list((ROOT/'src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']:
    for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):modules[n.lower()]=p
ordered=[];seen=set();visiting=set()
def visit(p):
    if p in seen:return
    if p in visiting:raise RuntimeError('module cycle: '+str(p))
    visiting.add(p)
    for n in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)',p.read_text(),re.M|re.I):
        q=modules.get(n.lower())
        if q and q!=p:visit(q)
        elif not q and n.lower() not in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'):raise RuntimeError('missing module: '+n)
    visiting.remove(p);seen.add(p);ordered.append(p)
visit(ROOT/'src/legacy/b1_10_port/headcalc.f90');visit(TEST)
result={'work_unit':'F-MIG431-LOWGWL01-P0','claim':'negative diagnostic only; public mode1 must remain fail-closed','tested_postimage':os.environ.get('LOWGWL01_TESTED_SHA','not-specified'),'compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},'runner_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'runs':{},'production_qualification':False,'canonical_mode1_admission':False}
with tempfile.TemporaryDirectory(prefix='lowgwl01-feasibility-') as folder:
    for opt in ('O0','O2'):
        build=pathlib.Path(folder)/opt;build.mkdir()
        flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
        objects=[]
        for p in ordered:
            obj=build/(p.stem+'.o');objects.append(str(obj))
            subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,capture_output=True,text=True)
        exe=build/TEST.stem
        subprocess.run(FC+LINK+flags+objects+['-o',str(exe)],check=True,capture_output=True,text=True)
        public=subprocess.run([str(exe)],capture_output=True,text=True)
        marker='F-MIG431-LOWGWL01_TYPED_MODE1_FAIL_CLOSED=PASS'
        if public.returncode!=0 or marker not in public.stdout:raise RuntimeError('public fail-closed gate failed: '+public.stderr)
        raw=subprocess.run([str(exe),'raw-below'],capture_output=True,text=True)
        bounds="Index '9' of dimension 1 of array 'parameter_set%z' above upper bound of 8"
        if raw.returncode==0 or bounds not in raw.stderr:raise RuntimeError('expected bounds finding missing: '+raw.stderr)
        result['runs'][opt]={'public_gate':marker,'raw_diagnostic_exit':raw.returncode,'raw_diagnostic':bounds,'geometry':'8 active nodes, exact z(8), GWLEVEL=-100 cm; fifth lower face=-50 cm'}
        print(opt+' PUBLIC_FAIL_CLOSED=PASS RAW_TYPED_GEOMETRY_BLOCKER=REPRODUCED',flush=True)
if result['runs']['O0']!=result['runs']['O2']:raise RuntimeError('optimization-dependent negative finding')
result['status']='NEGATIVE_FEASIBILITY_REPRODUCED';result['o0_o2_identity']=True
pathlib.Path(os.environ.get('LOWGWL01_RESULT','lowgwl01_feasibility_result.json')).write_text(json.dumps(result,indent=2)+'\n')
