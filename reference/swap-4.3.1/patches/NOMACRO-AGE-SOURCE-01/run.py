"""Actual original host delegated to real age providers; explicit age ledgers."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location('age_source',Path(__file__).with_name('source.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
spec=importlib.util.spec_from_file_location('original_age_inputs',ROOT/'tests/nomacro_scheduled_subsurface/age_reference.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
from original_pond_budget import render as render_linear_pond_conservation
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def validate(stdout):
    rows=[list(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('AGE_CUMULATIVE ')]
    assert len(rows)==1097,len(rows)
    assert all(len(r)==11 and all(map(math.isfinite,r)) and min(r[:3])>=0 for r in rows)
    maxima=dict(soil=0.,pond=0.,combined=0.);max_scaled=0.;epsilon=sys.float_info.epsilon
    for old,new in zip(rows,rows[1:]):
        prod,pondprod,external,drain,bottom,root,runoff,infil=[new[i]-old[i] for i in range(3,11)]
        errors=dict(soil=math.fsum([new[0],-old[0],-prod,-infil,-bottom,drain,root]),
                    pond=math.fsum([new[1],-old[1],-pondprod,-external,infil,runoff]),
                    combined=math.fsum([new[2],-old[2],-prod,-pondprod,-external,-bottom,drain,root,runoff]))
        scale=max(1.,*map(abs,old[:3]),*map(abs,new[:3]),abs(prod),abs(pondprod),abs(external),abs(bottom),abs(drain),abs(root),abs(runoff),abs(infil))
        tolerance=8192*epsilon*scale
        for name,value in errors.items():
            maxima[name]=max(maxima[name],abs(value));assert abs(value)<=tolerance,(name,value,tolerance)
            max_scaled=max(max_scaled,abs(value)/tolerance)
    return dict(days=1096,initial=rows[0],final=rows[-1],maximum_residual_cm_day=maxima,
                maximum_fraction_of_accepted_age_tolerance=max_scaled,
                tolerance_policy='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)',
                chemical_mass_guard_changed=False)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();a.output.mkdir();provider=a.reference_work/'build';objects=provider/'swap-obj';ttutil=provider/'ttutil-obj'
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles={},events=[],
                policy=s.POLICY,SWAP5_activation=False,whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    def call(command,cwd,label):
        start=time.perf_counter();r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=60)
        (cwd/(label+'.stdout')).write_bytes(r.stdout);(cwd/(label+'.stderr')).write_bytes(r.stderr)
        result['events'].append(dict(command=list(map(str,command)),seconds=time.perf_counter()-start,returncode=r.returncode));save()
        assert r.returncode==0,(r.stdout.decode(errors='replace')[-1800:],r.stderr.decode(errors='replace'))
        return r
    save()
    try:
        for opt in ('O0','O2'):
            build=a.output/opt;build.mkdir()
            (build/'solute.f90').write_bytes(s.source((provider/'swap-selected/solute.f90').read_bytes()))
            (build/'swap_csv_output.f90').write_bytes(s.csv_source((provider/'swap-selected/swap_csv_output.f90').read_bytes()))
            (build/'boundtop.f90').write_text(render_linear_pond_conservation((provider/'swap-selected/boundtop.f90').read_text(encoding='cp1252')),encoding='cp1252')
            flags=['-'+opt,'-std=legacy','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=bounds',
                   '-ffp-contract=off','-march=x86-64','-mtune=generic','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(ttutil)]
            for name in s.PROVIDERS:
                (build/(name+'.f90')).write_bytes((ROOT/'src/process'/(name+'.f90')).read_bytes())
            for name in (*s.PROVIDERS,'solute','swap_csv_output','boundtop'):
                call(['gfortran',*flags,'-c',build/(name+'.f90'),'-o',build/(name+'.o')],build,name+'-compile')
            linked=[p for p in sorted(objects.glob('*.o')) if p.name not in ('solute.o','swap_csv_output.o','boundtop.o')]
            linked += [build/(name+'.o') for name in (*s.PROVIDERS,'solute','swap_csv_output','boundtop')]
            exe=build/'swap_age.exe';call(['gfortran','-o',exe,*linked,ttutil/'libttutil.a'],build,'link')
            profile=result['profiles'][opt]=dict(cases={},generated_sha256={p.name:sha(p) for p in build.glob('*.f90')},executable_sha256=sha(exe));save()
            for initial in (0.,100.):
                case=build/str(int(initial));f.fixture(case,initial);inventory={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
                run=call([exe,'./swap.swp'],case,'reference');assert (case/'swap.ok').exists()
                r=validate(run.stdout.decode(errors='replace'));r['input_sha256']=inventory
                profile['cases'][str(int(initial))]=r;save();print(opt,initial,'ACTUAL_SOIL_POND_AGE_LEDGER_PASS',flush=True)
        result['status']='ORIGINAL_HOST_REAL_AGE_PROVIDERS_FULL_O0_O2_LEDGER_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
