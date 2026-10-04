"""Preserve A15 and test the bounded zero-preferential surface degeneration."""
import subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
sources=['src/solver/mod_soil_water_solver_contract.f90','src/process/macropore/mod_rfm_unponded_activation.f90',
         'src/runtime/mod_rfm_unponded_surface_composition.f90','src/runtime/mod_rfm_matrix_only_surface_composition.f90']
for opt in ['O0','O2']:
 build=out/opt;build.mkdir(exist_ok=True)
 for test in ['test_ppa_wu05a15_rfm_unponded_surface_composition','test_ppa_wu05a28_matrix_only_surface']:
  subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-'+opt,'-J'+str(build),
                  *sources,'tests/fpm/'+test+'.f90','-o',str(build/test)],cwd=root,check=True)
  subprocess.run([str(build/test)],check=True)
