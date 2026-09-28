#!/usr/bin/env python3
from pathlib import Path
import sys

src=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2])

decl="""   logical :: fpe_timeint05_bdf2_active
   real(8) :: fpe_timeint05_theta_nm1(1000)
   common /fpe_timeint05_bdf2_ctrl/ fpe_timeint05_theta_nm1, fpe_timeint05_bdf2_active
"""
needle="   real(8), parameter               :: Critdz = 1.0d-5\n"
if needle not in src:
    raise SystemExit("TIMEINT05 declaration insertion source drift")
src=src.replace(needle,needle+"\n"+decl,1)

replacements={
"(state%theta(1) - state%thetm1(1)) * matrix_fraction(1) * grid_dz(1) / dt":"temporal_storage_rate(1)",
"(state%theta(i) - state%thetm1(i)) * matrix_fraction(i) * grid_dz(i) / dt":"temporal_storage_rate(i)",
"grid_dz(i)*matrix_fraction(i)*(state%theta(i)-state%thetm1(i)) / dt":"temporal_storage_rate(i)",
"(state%theta(NN) - state%thetm1(NN))*matrix_fraction(NN)*grid_dz(NN)/dt":"temporal_storage_rate(NN)",
"state%dimoca(1)*matrix_fraction(1)*grid_dz(1)/dt":"temporal_capacity_rate(1)",
"state%dimoca(i)*matrix_fraction(i)*grid_dz(i)/dt":"temporal_capacity_rate(i)",
"state%dimoca(NN)*matrix_fraction(NN)*grid_dz(NN)/dt":"temporal_capacity_rate(NN)",
}
counts={}
for old,new in replacements.items():
    n=src.count(old)
    counts[old]=n
    if n==0:
        raise SystemExit("TIMEINT05 source drift, missing: "+old)
    src=src.replace(old,new)

insert="""real(8) function temporal_storage_rate(node)
   integer, intent(in) :: node
   if (fpe_timeint05_bdf2_active) then
      temporal_storage_rate = (1.5d0*state%theta(node) - 2.0d0*state%thetm1(node) + &
           0.5d0*fpe_timeint05_theta_nm1(node)) * matrix_fraction(node) * grid_dz(node) / dt
   else
      temporal_storage_rate = (state%theta(node)-state%thetm1(node)) * matrix_fraction(node) * grid_dz(node) / dt
   end if
end function temporal_storage_rate

real(8) function temporal_capacity_rate(node)
   integer, intent(in) :: node
   if (fpe_timeint05_bdf2_active) then
      temporal_capacity_rate = 1.5d0*state%dimoca(node)*matrix_fraction(node)*grid_dz(node)/dt
   else
      temporal_capacity_rate = state%dimoca(node)*matrix_fraction(node)*grid_dz(node)/dt
   end if
end function temporal_capacity_rate

"""
where="real(8) function root_sink_term(node)\n"
if where not in src:
    raise SystemExit("TIMEINT05 helper insertion source drift")
src=src.replace(where,insert+where,1)

out.write_text(src)
print("F_PE_TIMEINT05_BDF2_MATERIALIZE=PASS")
for k,v in counts.items():
    print("REPLACED",v,k)
