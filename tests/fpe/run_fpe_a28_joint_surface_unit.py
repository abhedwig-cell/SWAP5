"""Bounds-checked research service and unchanged A11/A15 controls, O0/O2."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
sources=['src/solver/mod_soil_water_solver_contract.f90','src/process/macropore/mod_rfm_unponded_activation.f90',
         'src/runtime/mod_rfm_unponded_surface_composition.f90','tests/fpe/support/mod_fpe_a28_joint_surface_receipt.f90']
for opt in ['O0','O2']:
 p=out/opt;p.mkdir(exist_ok=True)
 for t in ['test_ppa_wu05a11_rfm_unponded_activation','test_ppa_wu05a15_rfm_unponded_surface_composition','test_ppa_wu05a28_joint_surface']:
  subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-'+opt,'-J'+str(p),
                  *sources,'tests/fpm/'+t+'.f90','-o',str(p/t)],cwd=root,check=True)
  subprocess.run([str(p/t)],check=True)
