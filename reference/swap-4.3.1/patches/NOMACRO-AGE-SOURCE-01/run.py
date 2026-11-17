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
    p.add_argument('--resume',action='store_true')
    p.add_argument('--effluent',action='store_true')
    p.add_argument('--prior-core-reference-root',type=Path)
    a=p.parse_args();a.output.mkdir(exist_ok=a.resume);provider=a.reference_work/'build';objects=provider/'swap-obj';ttutil=provider/'ttutil-obj'
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles={},events=[],
                policy=s.POLICY,SWAP5_activation=False,whole_scientific_equivalence='NOT_QUALIFIED')
    if a.effluent:result['effluent_policy']=s.EFFLUENT_POLICY
    providers=(*s.PROVIDERS,*s.OUTPUT_PROVIDERS) if a.effluent else s.PROVIDERS
    if a.resume:
        result=json.loads((a.output/'RESULT.json').read_text())
        result['retained_failure']=dict(status=result['status'],error=result.pop('error',None))
        result['controller_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        result['status']='RESUMING'
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    def call(command,cwd,label,allowed=(0,)):
        start=time.perf_counter();r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=60)
        (cwd/(label+'.stdout')).write_bytes(r.stdout);(cwd/(label+'.stderr')).write_bytes(r.stderr)
        result['events'].append(dict(command=list(map(str,command)),seconds=time.perf_counter()-start,returncode=r.returncode));save()
        assert r.returncode in allowed,(r.stdout.decode(errors='replace')[-1800:],r.stderr.decode(errors='replace'))
        return r
    save()
    try:
        for opt in ('O0','O2'):
            build=a.output/opt;build.mkdir(exist_ok=a.resume)
            generated={'solute.f90':s.source((provider/'swap-selected/solute.f90').read_bytes(),effluent=a.effluent),
                       'swap_csv_output.f90':s.csv_source((provider/'swap-selected/swap_csv_output.f90').read_bytes())}
            pond=render_linear_pond_conservation((provider/'swap-selected/boundtop.f90').read_text(encoding='cp1252'))
            import os
            generated['boundtop.f90']=pond.replace('\n',os.linesep).encode('cp1252')
            flags=['-'+opt,'-std=legacy','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=bounds',
                   '-ffp-contract=off','-march=x86-64','-mtune=generic','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(ttutil)]
            for name in providers:
                generated[name+'.f90']=(ROOT/'src/process'/(name+'.f90')).read_bytes()
            reused=a.resume and opt in result['profiles']
            if reused:
                # Validate before writing: never damage an immutable retained
                # source/executable pair when a later controller is resumed.
                assert result['profiles'][opt]['generated_sha256']=={name:hashlib.sha256(raw).hexdigest() for name,raw in generated.items()}
                assert all((build/name).read_bytes()==raw for name,raw in generated.items())
            else:
                for name,raw in generated.items():(build/name).write_bytes(raw)
            if not reused:
                for name in (*providers,'solute','swap_csv_output','boundtop'):
                    call(['gfortran',*flags,'-c',build/(name+'.f90'),'-o',build/(name+'.o')],build,name+'-compile')
            linked=[p for p in sorted(objects.glob('*.o')) if p.name not in ('solute.o','swap_csv_output.o','boundtop.o')]
            linked += [build/(name+'.o') for name in (*providers,'solute','swap_csv_output','boundtop')]
            exe=build/'swap_age.exe'
            if reused:
                profile=result['profiles'][opt]
                assert profile['generated_sha256']=={p.name:sha(p) for p in build.glob('*.f90')} and profile['executable_sha256']==sha(exe)
            else:
                call(['gfortran','-o',exe,*linked,ttutil/'libttutil.a'],build,'link')
                profile=result['profiles'][opt]=dict(cases={},generated_sha256={p.name:sha(p) for p in build.glob('*.f90')},executable_sha256=sha(exe));save()
            for initial in (0.,100.):
                case=build/str(int(initial))
                if a.resume and (case/'swap.ok').exists():
                    original=json.loads((ROOT/'integration/f-ci/nomacro-complete01/AGE_ORIGINAL_DIAGNOSTIC.json').read_text())
                    inventory=original['profiles'][opt+'-'+str(int(initial))]['input_sha256']
                    assert all(sha(case/name)==digest for name,digest in inventory.items())
                    stdout=(case/'reference.stdout').read_text()
                else:
                    f.fixture(case,initial);inventory={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
                    run=call([exe,'./swap.swp'],case,'reference',allowed=(0,100));assert (case/'swap.ok').exists()
                    stdout=run.stdout.decode(errors='replace')
                r=validate(stdout);r['input_sha256']=inventory
                if a.effluent:
                    spec=importlib.util.spec_from_file_location('age_output_validation',ROOT/'tests/nomacro_scheduled_subsurface/age_runtime.py')
                    output=importlib.util.module_from_spec(spec);spec.loader.exec_module(output)
                    values=[list(map(float,line.split()[1:])) for line in stdout.splitlines() if line.startswith('HYBRID_AGE_EFFLUENT ')]
                    assert len(values)==1096
                    data=[dict(day=i+1,age_effluent=v) for i,v in enumerate(values)]
                    r['effluent_output']=output.output_values_from_directory(case,data)
                if a.prior_core_reference_root:
                    old=(a.prior_core_reference_root/opt/str(int(initial))/'reference.stdout').read_text()
                    probe=lambda text:[line for line in text.splitlines() if line.startswith('AGE_CUMULATIVE ')]
                    assert probe(stdout)==probe(old),'Corrected effluent changed core reference'
                    r['all_core_reference_rows_exact']=True
                profile['cases'][str(int(initial))]=r;save();print(opt,initial,'ACTUAL_SOIL_POND_AGE_LEDGER_PASS',flush=True)
        result['status']='ORIGINAL_HOST_AGE_CORE_AND_CORRECTED_EFFLUENT_FULL_O0_O2_PASS' if a.effluent else 'ORIGINAL_HOST_REAL_AGE_PROVIDERS_FULL_O0_O2_LEDGER_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
