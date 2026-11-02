"""Qualify the real production stock owner, retaining missing terms and physical gaps."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

from qualify_energy_boundary import ROOT, SOURCES, inputs, observe

MODULE = 'src/process/mod_whole_column_sensible_energy_accounting.f90'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    out = parser.parse_args().output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    assert not subprocess.check_output(['git','diff','HEAD','--',*SOURCES],cwd=ROOT)
    old = json.loads((ROOT/'integration/dataqual15/STOCK_PROJECTION_CANDIDATE_RESULT_20261102.json').read_text(encoding='utf-8'))
    sha = lambda raw:hashlib.sha256(raw).hexdigest()
    module_text=(ROOT/MODULE).read_text(encoding='utf-8')
    with tarfile.open(ROOT/old['archive']) as archive:
        candidate=archive.extractfile('candidate/'+MODULE).read()
    assert sha(candidate)==old['patched_source_sha256']
    assert module_text.encode()==candidate.replace(b'\r\n',b'\n'), 'unreviewed numerical postimage'
    compiler=shutil.which('gfortran')
    assert compiler
    subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15/qualify_energy_boundary.py'),
                    '--output',str(out/'current')],cwd=ROOT,check=True,capture_output=True)
    current=json.loads((out/'current/RESULT.json').read_text(encoding='utf-8'))
    for opt in ('O0','O2'):
        b=current['builds'][opt]
        assert b['projected_stock_roundoff_rejections']==0
        assert b['raw_storage_domain_rejections']==864
        assert b['missing_boundary_rejections']==864
        assert b['stdout_sha256']==old['builds'][opt+'-candidate']['stdout_sha256']
    injection='    roundoff_factor = (4.0_real64'
    assert module_text.count(injection)==1
    faulty=out/'faulty_stock.f90'
    faulty.write_text(module_text.replace(injection,
        '    result%exact_storage_change_j_m2 = result%exact_storage_change_j_m2 + 1.0_real64\n'+injection),encoding='utf-8')
    driver=(ROOT/SOURCES[-1]).read_text(encoding='utf-8')
    assertion="   if(abs(ledger%exact_storage_change_j_m2-ledger%projected_balance%delta_storage_j_m2)>1d-6) &\n    error stop 'stock projection disagreement beyond diagnostic bound'\n"
    assert driver.count(assertion)==1
    fault_driver=out/'fault_driver.f90'
    fault_driver.write_text(driver.replace(assertion,''),encoding='utf-8')
    report=dict(status='PRODUCTION_STOCK_COMPARISON_PASS_PHYSICAL_ENERGY_OPEN',
        measurement_commit=current['measurement_commit'],source_git_blob=current['source_git_blob'],
        compiler=current['compiler'],current=current,full_energy_balance_complete=False,
        missing_boundary_still_rejected=True,raw_theta_domain_still_rejected=True,fault={},contracts={})
    raw=inputs()
    for opt in ('O0','O2'):
        build=out/('fault-'+opt);build.mkdir()
        exe=build/('driver.exe' if os.name=='nt' else 'driver')
        sources=[str(faulty if p==MODULE else ROOT/p) for p in SOURCES]
        sources[-1]=str(fault_driver)
        command=[compiler,'-'+opt,'-g','-fcheck=all','-ffree-line-length-none',
                 '-J'+str(build),'-I'+str(build),*sources,'-o',str(exe)]
        cp=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=120)
        (build/'compile.stderr').write_text(cp.stderr,encoding='utf-8')
        assert cp.returncode==0,cp.stderr
        cp=subprocess.run([str(exe),str(out/'current/inputs.dat')],cwd=build,capture_output=True,text=True,timeout=120)
        (build/'stdout').write_text(cp.stdout,encoding='utf-8')
        (build/'stderr').write_text(cp.stderr,encoding='utf-8')
        assert cp.returncode==0,cp.stderr
        measured=observe(cp.stdout,raw)
        assert measured['projected_stock_roundoff_rejections']==864
        assert sha(cp.stdout.encode())==old['builds'][opt+'-fault']['stdout_sha256']
        report['fault'][opt]=dict(stdout_sha256=sha(cp.stdout.encode()),executable_sha256=sha(exe.read_bytes()),**measured)
        for test in ('test_eb_i22_whole_column_sensible_energy_accounting','test_f_vq88_eb_i22_independent'):
            d=out/(test+'-'+opt);d.mkdir()
            executable=d/('contract.exe' if os.name=='nt' else 'contract')
            closure=['src/kernel/mod_energy_conservation_types.f90','src/process/mod_linear_mixture_sensible_storage.f90',
                     MODULE,'tests/eb/'+test+'.f90']
            command=[compiler,'-'+opt,'-fcheck=all','-ffree-line-length-none','-J'+str(d),'-I'+str(d),
                     *[str(ROOT/p) for p in closure],'-o',str(executable)]
            cp=subprocess.run(command,cwd=d,capture_output=True,text=True,timeout=60)
            assert cp.returncode==0,cp.stderr
            cp=subprocess.run([str(executable)],cwd=d,capture_output=True,text=True,timeout=30)
            assert cp.returncode==0 and 'PASS' in cp.stdout,(cp.stdout,cp.stderr)
            (d/'stdout').write_text(cp.stdout,encoding='utf-8')
            report['contracts'][test+'-'+opt]=dict(stdout=cp.stdout,source_git_blob={p:subprocess.check_output(
                ['git','rev-parse','HEAD:'+p],cwd=ROOT,text=True).strip() for p in closure})
    assert (out/'fault-O0/stdout').read_bytes()==(out/'fault-O2/stdout').read_bytes()
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
