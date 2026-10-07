#!/usr/bin/env python3
"""Bounded SWBOTB1 below-profile qualification; in-profile remains fail-closed."""
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
result={'work_unit':'F-MIG431-LOWGWL01-P0','claim':'ordinary SWBOTB1 typed solver qualification for below-profile and in-profile branches; high-GWL special branch remains fail-closed','tested_postimage':os.environ.get('LOWGWL01_TESTED_SHA','not-specified'),'compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},'runner_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'runs':{},'production_qualification':True,'canonical_mode1_full_admission':False}
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
        markers=['F-MIG431-LOWGWL01_BELOW_PROFILE_TYPED=PASS','F-MIG431-LOWGWL01_IN_PROFILE_PROVIDER_RAW=PASS','F-MIG431-LOWGWL01_IN_PROFILE_TYPED=PASS','F-MIG431-LOWGWL01_HIGH_GWL_FAIL_CLOSED=PASS']
        if public.returncode!=0 or any(m not in public.stdout for m in markers):
            raise RuntimeError('bounded mode1 gate failed: '+public.stdout+'\n'+public.stderr)
        result['runs'][opt]={'markers':markers,'geometry':'8 exact active nodes; below-profile GWLEVEL=-100 cm; in-profile GWLEVEL=-42 cm rejected'}
        print(opt+' LOWGWL01_BELOW_PROFILE=PASS IN_PROFILE_PROVIDER_RAW=PASS IN_PROFILE_TYPED=PASS HIGH_GWL_FAIL_CLOSED=PASS',flush=True)
if result['runs']['O0']!=result['runs']['O2']:raise RuntimeError('optimization-dependent finding')
result['status']='BOUNDED_BELOW_PROFILE_QUALIFIED';result['o0_o2_identity']=True
pathlib.Path(os.environ.get('LOWGWL01_RESULT','lowgwl01_feasibility_result.json')).write_text(json.dumps(result,indent=2)+'\n')
