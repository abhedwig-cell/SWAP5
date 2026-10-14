#!/usr/bin/env python3
"""Compile the existing exact B15 provider closure without an unused main program.

A build is never a scientific PASS. Full original owning programs qualify it.
"""
import argparse, hashlib, importlib.util, json, os, pathlib, platform, re, resource, subprocess, time
ROOT=pathlib.Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True,type=pathlib.Path);p.add_argument('--opt',required=True,type=int,choices=[0,2]);a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    stub=out/'consistent_grid_stubs.f90';original_stub=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90';text=original_stub.read_text();old='  real(8), parameter :: disnod(numnod+1) = 1.0d0'
    if text.count(old)!=1:raise ValueError('certified grid source drift')
    stub.write_text(text.replace(old,'  real(8), parameter :: disnod(numnod+1) = [0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]'))
    original=ROOT/'tests/frost/test_ppa_wu05b15_low_air_runtime.f90';driver=out/'low_air_driver.f90';text=original.read_text()
    for old,new in [('    config%transaction%retry_scale = 0.5_real64','    config%retain_accepted_step_proposal = .true.\n    config%transaction%retry_scale = 0.5_real64'),('    cfg%numerical%transaction%retry_scale=.5_real64','    cfg%numerical%retain_accepted_step_proposal=.true.\n    cfg%numerical%transaction%retry_scale=.5_real64')]:
        if text.count(old)!=1:raise ValueError('bootstrap discovery recipe drift')
        text=text.replace(old,new)
    driver.write_text(text) # Dependency discovery only; this main is not compiled/executed.
    original_runtime=ROOT/'src/runtime/mod_canonical_interval_runtime.f90';runtime=out/original_runtime.name;runtime.write_bytes(original_runtime.read_bytes())
    spec=importlib.util.spec_from_file_location('identity',ROOT/'tools/performance/irrigation_build_identity.py');identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
    identity.USE=re.compile(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(?!ieee_arithmetic\b|ieee_exceptions\b|iso_c_binding\b|omp_lib\b)(\w+)',re.I|re.M)
    files=[x for x in sorted((ROOT/'src').rglob('*.f90')) if x!=original_runtime]+[runtime,stub]+list((ROOT/'tests/frost').glob('mod_*fixture.f90'))
    providers=identity.discover(files,[driver])+[ROOT/'src/legacy/b1_10_port/headcalc.f90']
    flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{a.opt}']
    report={'scope':'FRESH_PROVIDER_BUILD_NOT_QUALIFICATION','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'host':platform.uname()._asdict(),'profile':False,'provider_only':True,'compiler':subprocess.check_output(['gfortran','--version'],text=True),'flags':flags,'ordered_sources':list(map(str,providers+[driver])),'sources':{str(x):sha(x) for x in providers+[driver,original_stub,original,original_runtime]},'events':[],'uncompiled_bootstrap_role':'Dependency discovery only; all seven original main programs compiled by owning matrix.'}
    for i,source in enumerate(providers):
        command=list(map(str,['gfortran',*flags,'-J',out,'-I',out,'-c',source,'-o',out/f'{i}.o']))
        began=time.monotonic();before=resource.getrusage(resource.RUSAGE_CHILDREN)
        with (out/f'compile-{i}.stdout').open('w') as so,(out/f'compile-{i}.stderr').open('w') as se:code=subprocess.run(command,cwd=out,stdout=so,stderr=se).returncode
        after=resource.getrusage(resource.RUSAGE_CHILDREN)
        report['events'].append({'label':f'compile-{i}','command':command,'exit':code,'wall_seconds':time.monotonic()-began,'cpu_seconds':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime})
        (out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n')
        if code:raise RuntimeError('provider compile failed; retain evidence')
    report['terminal_status']='PROVIDERS_ONLY_NOT_QUALIFICATION';(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n');print('PROVIDERS_ONLY_BUILD=PASS')
if __name__=='__main__':main()
