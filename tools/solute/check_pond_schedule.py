"""Actual generated original PondRunoff schedule and independent balance O0/O2."""
import argparse,hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--build-bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    ref=a.reference_work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    prepared=json.loads((ref/'PREPARED.json').read_text());assert sha(Path(shutil.which('gfortran')))==prepared['toolchain']['gfortran']['sha256']
    original=a.build_bundle.resolve()/'boundtop.f90';meta=json.loads((a.build_bundle/'BUILD.json').read_text());assert sha(original)==meta['identity']['donor_generated']['boundtop.f90']
    objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj';profiles=[]
    for opt in ('O0','O2'):
        target=out/opt;target.mkdir();source=target/'boundtop.f90'
        text=original.read_text(encoding='cp1252');assert text.count('\ncontains\n')==1
        # Test-only access to two private workspace fields. The complete actual
        # production procedure bodies remain literal; no copied implementation.
        source.write_text(text.replace('\ncontains\n','\npublic :: h0max,k1max\ncontains\n'),encoding='cp1252')
        driver=ROOT/'tools/solute/drivers/original_pond_schedule.f90'
        commands=[['gfortran','-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-ffp-contract=off','-march=x86-64','-mtune=generic','-I',str(objects),'-I',str(ttutil),'-c',str(source),str(driver)],
                  ['gfortran','-o',str(target/'pond.exe'),*[str(q) for q in sorted(objects.glob('*.o')) if q.name.lower() not in ('swap_main.o','boundtop.o')],str(target/'boundtop.o'),str(target/'original_pond_schedule.o'),str(ttutil/'libttutil.a')]]
        compilation=[]
        for cmd in commands:
            r=subprocess.run(cmd,cwd=target,capture_output=True,text=True,timeout=120);compilation.append(dict(command=cmd,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
        r=subprocess.run([str(target/'pond.exe')],cwd=target,capture_output=True,text=True,timeout=15);(target/'stdout.log').write_text(r.stdout);(target/'stderr.log').write_text(r.stderr);assert r.returncode==0,(r.stdout,r.stderr)
        data=[list(map(float,s.split())) for s in r.stdout.splitlines()];assert len(data)==5
        profiles.append(dict(optimization=opt,original_provider_optimization='O2',compilation=compilation,clock_threshold_pond_runoff_and_independent_residual=data,generated_source_sha256=sha(source),executable_sha256=sha(target/'pond.exe')))
    result=dict(status='ACTUAL_ORIGINAL_SCHEDULED_POND_O0_O2_PASS',profiles=profiles,driver_sha256=sha(driver),generator_sha256=sha(ROOT/'app/hybrid_water/surface_schedule.py'),production_generated_preimage_sha256=sha(original),test_only_visibility='One PUBLIC declaration exposes h0max/k1max workspace to the driver; complete production routine bodies are exact; no production interface change',scope='Complete actually emitted original MOD_top/PondRunoff native dependency closure; real interpolation/runoff and independent storage/flux identity, no model or macro execution')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])


if __name__=='__main__':main()
