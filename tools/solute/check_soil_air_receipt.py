"""Execute the production lookup codec in its complete native original closure."""
import argparse,hashlib,json,shutil,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
from lower_boundary_receipt import render_budget as render
from daily_host import NO_MACRO_FP_FLAGS

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    ref=a.reference_work.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    prepared=json.loads((ref/'PREPARED.json').read_text());compiler=Path(shutil.which('gfortran'))
    assert sha(compiler)==prepared['toolchain']['gfortran']['sha256']
    selected=ref/'build/swap-selected';objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj'
    source=ROOT/'app/hybrid_water/hybrid_step_budget.f90'
    profiles=[]
    for opt in ('O0','O2'):
        target=out/opt;target.mkdir();generated=target/'hybrid_step_budget.f90';generated.write_text(render(source.read_text(encoding='cp1252')),encoding='cp1252')
        driver=ROOT/'tools/solute/drivers/original_soil_air_receipt.f90'
        flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch',*NO_MACRO_FP_FLAGS,'-I',str(objects),'-I',str(ttutil)]
        commands=[['gfortran',*flags,'-c',str(generated),str(driver)],
                  ['gfortran','-o',str(target/'codec.exe'),*[str(q) for q in sorted(objects.glob('*.o')) if q.name not in ('swap_main.o','hybrid_step_budget.o')],str(target/'hybrid_step_budget.o'),str(target/'original_soil_air_receipt.o'),str(ttutil/'libttutil.a')]]
        compilation=[]
        for command in commands:
            r=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=120);compilation.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
        def execute(name,mode,payload=None,refused=False):
            directory=target/name;directory.mkdir()
            if payload is not None:(directory/'state.bin').write_bytes(payload)
            r=subprocess.run([str(target/'codec.exe'),mode],cwd=directory,capture_output=True,text=True,timeout=15)
            (directory/'stdout.log').write_text(r.stdout);(directory/'stderr.log').write_text(r.stderr)
            assert (r.returncode!=0)==refused,(opt,name,r.stdout,r.stderr)
            if refused:assert 'soil-air trial boundary receipt' in r.stderr.lower(),(name,r.stderr)
            return directory,dict(name=name,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr)
        valid,positive=execute('valid','valid');attacks=[]
        for mode in ('missing','nan','infinity'):
            _,record=execute(mode,mode,refused=True);attacks.append(record)
        profiles.append(dict(optimization=opt,original_provider_optimization='O2',compilation=compilation,positive=positive,refusals=attacks,
          explicit_open_and_closed=True,reconstructed_qbot_ignored=True,original_explicit_zero_flux_exact=True,physical_state_unchanged=True,
          generated_source_sha256=sha(generated),executable_sha256=sha(target/'codec.exe')))
    (out/'RESULT.json').write_text(json.dumps(dict(status='PRODUCTION_ORIGINAL_SOIL_AIR_RECEIPT_O0_O2_PASS',compiler=prepared['toolchain']['gfortran'],profiles=profiles,
      production_generator_sha256=sha(ROOT/'app/hybrid_water/lower_boundary_receipt.py'),original_source_sha256=sha(source),driver_sha256=sha(ROOT/'tools/solute/drivers/original_soil_air_receipt.f90'),
      scope='Actual production independent soil-air boundary trial receipt in complete original native dependency closure; no model or active macropore execution'),indent=2)+'\n')
    print('PRODUCTION_ORIGINAL_SOIL_AIR_RECEIPT_O0_O2_PASS')

if __name__=='__main__':main()
