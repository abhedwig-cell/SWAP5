"""Independent surface mass oracle using the existing BOFEK00 geometry/provider."""
from pathlib import Path
import subprocess,sys,os
root=Path(__file__).resolve().parents[2];build=Path(sys.argv[1]).resolve()
s=(root/'tests/verification/test_bofek00_dynamic_top_correction.f90').read_text()
anchor="  write(*,'(A)') 'F_PE_BOFEK00_DYNAMIC_TOP_CORRECTION=PASS'"
assert s.count(anchor)==1
s=s.replace(anchor,"""  call check_surface_receipt(2.0_real64*KS,h_top,0.0_real64)
  call check_surface_receipt(4.0_real64*KS,h_top,0.01_real64)
"""+anchor,1)
s=s.replace('contains\n',"""contains
  subroutine check_surface_receipt(rain,h,oldpond)
    real(real64),intent(in)::rain,h,oldpond
    type(b110_dynamic_top_boundary_request_t)::r
    type(b110_dynamic_top_boundary_result_t)::z
    real(real64)::residual,infiltration_only
    call make_request(r,rain,h,0.0_real64)
    r%previous_ponding_depth_cm=oldpond
    call evaluate_b110_dynamic_top_boundary(geometry,hp,r,z)
    call require(z%status==B110_DYN_TOP_AVAILABLE,'surface receipt available')
    residual=rain*DT+oldpond+z%actual_top_flux_cm_per_day*DT-z%candidate_ponding_depth_cm-z%runoff_depth_cm
    call require(abs(residual)<=1e-12_real64,'independent surface balance')
    infiltration_only=z%candidate_ponding_depth_cm-oldpond
    call require(abs(infiltration_only)>1e-8_real64,'material distinction of external receipt and infiltration')
    write(*,'(*(g0))') 'A28_SURFACE_RECEIPT_ORACLE|ROUTE=',trim(z%route),'|MASS=',residual, &
       '|POND_CHANGE=',infiltration_only,'|RUNOFF=',z%runoff_depth_cm
  end subroutine
""",1)
p=build/'a28_surface_receipt_oracle.f90';p.write_text(s)
exe=build/'a28_surface_receipt_oracle'
subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-O2','-I'+str(build),str(p),
                '-L'+str(build),'-lfgc45_multiswap','-Wl,-rpath,'+str(build),'-o',str(exe)],check=True)
subprocess.run([str(exe)],check=True)
