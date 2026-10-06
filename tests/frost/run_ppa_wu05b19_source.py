#!/usr/bin/env python3
"""Whole corrected DIVDRA/FrozenCond/FrozenBounds on the actual B19 four-node grid."""
from pathlib import Path
import argparse,hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--record',required=True);a=ap.parse_args()
    build=Path(tempfile.mkdtemp(prefix='ppa-wu05b19-source-'))
    files=['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90','src/process/mod_drainage_spatial_distribution.f90','src/process/mod_frost_divdra_drainage_effect.f90','src/process/mod_frost_geometry_effect.f90','src/process/mod_frost_hydraulic_effect.f90','tests/frost/test_ppa_wu05b19_divdra_globals.f90','reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-02/divdra.f90','reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90','tests/frost/test_ppa_wu05b19_divdra_source.f90']
    for o in(0,2):
        d=build/f'o{o}';d.mkdir()
        subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-w','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{o}','-J',str(d),'-I',str(d),*[str(ROOT/f)for f in files],'-o',str(d/'test')],check=True)
        with(d/'output.txt').open('w')as out:subprocess.run([str(d/'test')],stdout=out,check=True)
    assert (build/'o0/output.txt').read_bytes()==(build/'o2/output.txt').read_bytes()
    text=(build/'o0/output.txt').read_text();assert text.count('B19_SOURCE case=')==660 and 'cases=660 accepted=412 held=248'in text
    r=dict(work_unit='PPA-WU05B19',status='LOCAL_ACTUAL_SOURCE_PARITY_PASS_NOT_RUNTIME_ADMISSION',build=str(build),cases_per_optimization=660,accepted=412,unavailable=248,O0_O2_byte_identity=True,source_sha256={f:sha(ROOT/f)for f in files},outputs={f'o{o}':sha(build/f'o{o}/output.txt')for o in(0,2)},executables={f'o{o}':sha(build/f'o{o}/test')for o in(0,2)},summary=text.splitlines()[-1])
    Path(a.record).write_text(json.dumps(r,indent=2)+'\n');print(r['summary'],flush=True)
if __name__=='__main__':main()
