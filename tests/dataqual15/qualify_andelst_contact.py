"""Compile actual unsaturated owner; isolate whole-cell topology discontinuity."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ['src/process/macropore/mod_ppa_wu05a6_sorptivity_rate.f90',
           'src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90',
           'tests/dataqual15/andelst_contact_driver.f90']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    out = parser.parse_args().output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    assert not subprocess.check_output(['git','diff','HEAD','--',*SOURCES],cwd=ROOT), 'persist source before qualification'
    compiler = shutil.which('gfortran')
    assert compiler
    sha = lambda raw: hashlib.sha256(raw).hexdigest()
    report = dict(scope='SYNTHETIC_DTO_REAL_OWNER_TOPOLOGY_CONTROL_NOT_COMPLETE_ANDELST_REPLAY',
                  measurement_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  source_sha256={p:sha((ROOT/p).read_bytes()) for p in SOURCES},
                  source_git_blob={p:subprocess.check_output(['git','rev-parse','HEAD:'+p],cwd=ROOT,text=True).strip() for p in SOURCES},
                  repair_implemented=False, full_original_complete=False, builds={})
    for opt in ('O0','O2'):
        build = out/opt
        build.mkdir()
        exe = build/('contact.exe' if os.name=='nt' else 'contact')
        command = [compiler,'-'+opt,'-g','-fcheck=all','-ffree-line-length-none',
                   '-J'+str(build),'-I'+str(build),*[str(ROOT/p) for p in SOURCES],'-o',str(exe)]
        compiled = subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=90)
        (build/'compile.stderr').write_text(compiled.stderr,encoding='utf-8')
        assert compiled.returncode==0,compiled.stderr
        run = subprocess.run([str(exe)],cwd=build,capture_output=True,text=True,timeout=30)
        (build/'stdout').write_text(run.stdout,encoding='utf-8')
        (build/'stderr').write_text(run.stderr,encoding='utf-8')
        assert run.returncode==0,run.stderr
        rows=[list(map(float,line.split(',')[1:])) for line in run.stdout.splitlines() if line.startswith('CONTACT,')]
        assert len(rows)==36
        assert {r[0] for r in rows}=={1e-3,1e-8,1e-13}
        assert {r[2] for r in rows}=={0.,1.,2.}
        assert all(abs(2*r[1]*r[4]-r[3])<1e-14 for r in rows)
        assert max(r[3] for r in rows)-min(r[3] for r in rows)<2.1e-5
        report['builds'][opt]=dict(command=command,rows=len(rows),
            executable_sha256=sha(exe.read_bytes()),stdout_sha256=sha(run.stdout.encode()),
            jump_range_cm_day=[min(r[3] for r in rows),max(r[3] for r in rows)])
    report['O0_O2_stdout_exact']=(out/'O0/stdout').read_bytes()==(out/'O2/stdout').read_bytes()
    assert report['O0_O2_stdout_exact']
    report['status']='TOPOLOGY_CONTROL_PASS_CONTACT_REPAIR_OPEN'
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
