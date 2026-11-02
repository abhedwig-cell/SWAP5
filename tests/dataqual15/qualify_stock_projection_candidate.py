"""Isolated numerical repair experiment; never patch the current production tree.

Applies the reviewable stock-comparison patch in a new isolated Git fixture,
then compiles the real current component closure against that candidate module.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from qualify_energy_boundary import ROOT, SOURCES, inputs, observe

MODULE = 'src/process/mod_whole_column_sensible_energy_accounting.f90'
PATCH = 'integration/dataqual15/STOCK_PROJECTION_NUMERICAL_CANDIDATE.patch'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    out = parser.parse_args().output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    assert not subprocess.check_output(['git','diff','HEAD','--',*SOURCES,PATCH],cwd=ROOT)
    fixture = out/'candidate'
    target = fixture/MODULE
    target.parent.mkdir(parents=True)
    target.write_bytes((ROOT/MODULE).read_bytes().replace(b'\r\n',b'\n'))
    local_patch=out/'candidate.patch'
    local_patch.write_bytes((ROOT/PATCH).read_bytes().replace(b'\r\n',b'\n'))
    subprocess.run(['git','init','-q',str(fixture)],check=True)
    subprocess.run(['git','apply','--check',str(local_patch)],cwd=fixture,check=True)
    subprocess.run(['git','apply',str(local_patch)],cwd=fixture,check=True)
    raw = inputs()
    (out/'inputs.dat').write_bytes(raw)
    compiler = shutil.which('gfortran')
    assert compiler
    sha = lambda b:hashlib.sha256(b).hexdigest()
    report = dict(measurement_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        scope='ISOLATED_NUMERICAL_CANDIDATE_NOT_CURRENT_PRODUCTION',
        patch_sha256=sha((ROOT/PATCH).read_bytes()),
        original_module_git_blob=subprocess.check_output(['git','rev-parse','HEAD:'+MODULE],cwd=ROOT,text=True).strip(),
        patched_source_sha256=sha(target.read_bytes()),production_modified=False,
        production_admitted=False,full_energy_balance_complete=False,builds={})
    # Deliberate 1 J/m2 representation inconsistency, not a boundary residual.
    injection='    roundoff_factor = (4.0_real64'
    candidate_text=target.read_text(encoding='utf-8')
    assert candidate_text.count(injection)==1
    faulty=out/'faulty_stock.f90'
    faulty.write_text(candidate_text.replace(injection,
        '    result%exact_storage_change_j_m2 = result%exact_storage_change_j_m2 + 1.0_real64\n'+injection),encoding='utf-8')
    # Remove only the observer's own tiny-gap assertion for the fault control:
    # the production status check and every physical observation remain active.
    driver_text=(ROOT/SOURCES[-1]).read_text(encoding='utf-8')
    assertion="   if(abs(ledger%exact_storage_change_j_m2-ledger%projected_balance%delta_storage_j_m2)>1d-6) &\n    error stop 'stock projection disagreement beyond diagnostic bound'\n"
    assert driver_text.count(assertion)==1
    fault_driver=out/'fault_driver.f90'
    fault_driver.write_text(driver_text.replace(assertion,''),encoding='utf-8')
    for opt in ('O0','O2'):
        for variant in ('candidate','fault'):
            build=out/(opt+'-'+variant)
            build.mkdir()
            sources=[str(target if p==MODULE else ROOT/p) for p in SOURCES]
            if variant=='fault':
                sources[SOURCES.index(MODULE)]=str(faulty)
                sources[-1]=str(fault_driver)
            exe=build/('driver.exe' if os.name=='nt' else 'driver')
            command=[compiler,'-'+opt,'-g','-fcheck=all','-ffree-line-length-none',
                     '-J'+str(build),'-I'+str(build),*sources,'-o',str(exe)]
            compiled=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=120)
            (build/'compile.stderr').write_text(compiled.stderr,encoding='utf-8')
            assert compiled.returncode==0,compiled.stderr
            run=subprocess.run([str(exe),str(out/'inputs.dat')],cwd=build,capture_output=True,text=True,timeout=120)
            (build/'stdout').write_text(run.stdout,encoding='utf-8')
            (build/'stderr').write_text(run.stderr,encoding='utf-8')
            assert run.returncode==0,run.stderr
            statuses=[int(l.rsplit(',',1)[1]) for l in run.stdout.splitlines() if l.startswith('LEDGER_STATUS,')]
            assert len(statuses)==864
            assert set(statuses)==({0} if variant=='candidate' else {4})
            measurement=observe(run.stdout,raw)
            assert measurement['raw_storage_domain_rejections']==864
            assert measurement['projected_stock_roundoff_rejections']==(0 if variant=='candidate' else 864)
            assert measurement['counterfactual_max_residual_j_cm2']['kind1_gauge0']>1.45
            report['builds'][opt+'-'+variant]=dict(command=command,executable_sha256=sha(exe.read_bytes()),
                stdout_sha256=sha(run.stdout.encode()),**measurement)
    for variant in ('candidate','fault'):
        assert (out/('O0-'+variant)/'stdout').read_bytes()==(out/('O2-'+variant)/'stdout').read_bytes()
    assert not subprocess.check_output(['git','diff','HEAD','--','src','app','reference'],cwd=ROOT)
    report['status']='NUMERICAL_CANDIDATE_PASS_1J_FAULT_REJECTED_PHYSICAL_ENERGY_GAP_RETAINED'
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
