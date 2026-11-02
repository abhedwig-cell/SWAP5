"""Conservation regression against actual storage and face-reconstruction owners."""
import argparse, hashlib, importlib.util, json, shutil, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE = 'src/process/macropore/mod_macropore_standard_storage.f90'
DRIVER = 'tests/dataqual15/macropore_stock_driver.f90'
BASE = '7a7f994d8b7fd0327f761a0db791726ab7a98e75'

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--compiler', default='gfortran')
    a = p.parse_args(); out = a.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location('dep', ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
    dep = importlib.util.module_from_spec(spec); spec.loader.exec_module(dep)
    sources, _ = dep.strict_closure(ROOT, [DRIVER])
    sha = lambda b: hashlib.sha256(b).hexdigest()
    assert not subprocess.check_output(['git','diff','HEAD','--',*[str(x) for x in sources]], cwd=ROOT)
    old = out/'old_storage.f90'
    old.write_bytes(subprocess.check_output(['git','show',BASE+':'+MODULE],cwd=ROOT))
    report = dict(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        compiler=subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0],
        sources_sha256={str(s.relative_to(ROOT)):sha(s.read_bytes()) for s in sources},
        old_source_commit=BASE, old_source_sha256=sha(old.read_bytes()), events=[])
    for opt in ('O0','O2'):
        for variant in ('current','old'):
            folder=out/(opt+'-'+variant); folder.mkdir()
            selected=[old if variant=='old' and s==ROOT/MODULE else s for s in sources]
            command=[a.compiler,'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all',
                     '-ffpe-trap=invalid,zero,overflow','-J'+str(folder),'-I'+str(folder),
                     *map(str,selected),'-o',str(folder/'driver')]
            start=time.monotonic(); build=subprocess.run(command,capture_output=True)
            (folder/'compile.stderr').write_bytes(build.stderr); assert build.returncode==0,build.stderr
            run=subprocess.run([str(folder/'driver')],capture_output=True)
            (folder/'stdout').write_bytes(run.stdout); (folder/'stderr').write_bytes(run.stderr)
            report['events'].append(dict(optimization=opt,variant=variant,command=command,
                compile_returncode=build.returncode,native_returncode=run.returncode,
                seconds=time.monotonic()-start,stdout_sha256=sha(run.stdout),stderr_sha256=sha(run.stderr)))
            if variant=='current':
                assert run.returncode==0,run.stderr
                assert b'MACRO_STOCK_MASS_AND_CLOSED_BOTTOM_PASS 31' in run.stdout
            else:
                assert run.returncode!=0 and b'stock erased or invented' in run.stderr
    assert (out/'O0-current/stdout').read_bytes()==(out/'O2-current/stdout').read_bytes()
    report.update(status='CURRENT_MASS_PASS_OLD_QUANTIZATION_REJECTED',cases_per_build=31,
                  O0_O2_exact=True,full_original_481_complete=False)
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__': main()
