#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

marker="   real(8)                          :: CritDevBalCp, CritDevBalTot\n"
insert=marker+"""   integer :: timeint15_tr_mode
   common /timeint15_tr_common/ timeint15_tr_mode
   logical :: timeint15_origin_captured
   real(8) :: timeint15_origin_nonstorage(1000)
"""
if marker not in src:
    raise SystemExit("TIMEINT15 declaration marker missing")
src=src.replace(marker,insert,1)

old="""!  calculate vector fsi_ws%residual (first time)
   call vector_F(1)

!  initial estimate of fsi_ws%residual inner product
"""
new="""!  calculate vector fsi_ws%residual (first time)
   timeint15_origin_captured = .false.
   call vector_F(1)

!  initial estimate of fsi_ws%residual inner product
"""
if old not in src:
    raise SystemExit("TIMEINT15 initial residual marker missing")
src=src.replace(old,new,1)

end_marker="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

end subroutine vector_F
"""
end_repl="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

   if (timeint15_tr_mode == 1) call timeint15_trapezoidal_residual()

end subroutine vector_F
"""
if end_marker not in src:
    raise SystemExit("TIMEINT15 vector_F end marker missing")
src=src.replace(end_marker,end_repl,1)

# Scale the spatial/off-storage Jacobian by 1/2. Storage derivative remains full.
src=src.replace(
"fsi_ws%dfdh_upper(i)   = - state%kmean(i)  /grid_disnod(i)",
"fsi_ws%dfdh_upper(i)   = - 0.5d0*state%kmean(i)  /grid_disnod(i)")
src=src.replace(
"fsi_ws%dfdh_upper(i)   = - state%kmean(i) / grid_disnod(i)",
"fsi_ws%dfdh_upper(i)   = - 0.5d0*state%kmean(i) / grid_disnod(i)")

repls={
"fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + state%kmean(1)/grid_disnod(1) * &":
"fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + 0.5d0*state%kmean(1)/grid_disnod(1) * &",
"fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + state%kmean(1)/grid_disnod(1)":
"fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + 0.5d0*state%kmean(1)/grid_disnod(1)",
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + state%kmean(NN+1)/(grid_z(NN)-state%gwlinp)":
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.5d0*state%kmean(NN+1)/(grid_z(NN)-state%gwlinp)",
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 1.0d0 / (grid_disnod(NN+1)/state%kmean(NN+1) + rimlay)":
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.5d0 / (grid_disnod(NN+1)/state%kmean(NN+1) + rimlay)",
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 1.0d0 / rimlay":
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.5d0 / rimlay",
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + state%kmean(NN+1)/grid_disnod(NN+1)":
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.5d0*state%kmean(NN+1)/grid_disnod(NN+1)",
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + fsi_ws%dconductivity_dhead(NN) * 0.5d0":
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.25d0*fsi_ws%dconductivity_dhead(NN)",
"fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + fsi_ws%dconductivity_dhead(1) * fsi_ws%head_gradient(2) * dkmean":
"fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) + 0.5d0*fsi_ws%dconductivity_dhead(1) * fsi_ws%head_gradient(2) * dkmean",
"fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) - fsi_ws%dconductivity_dhead(1) * fsi_ws%head_gradient(1) * 0.5d0":
"fsi_ws%dfdh_main(1) = fsi_ws%dfdh_main(1) - 0.25d0*fsi_ws%dconductivity_dhead(1) * fsi_ws%head_gradient(1)",
"fsi_ws%dfdh_lower(1) = fsi_ws%dfdh_lower(1) + fsi_ws%dconductivity_dhead(2) * fsi_ws%head_gradient(2) * dkmean":
"fsi_ws%dfdh_lower(1) = fsi_ws%dfdh_lower(1) + 0.5d0*fsi_ws%dconductivity_dhead(2) * fsi_ws%head_gradient(2) * dkmean",
"fsi_ws%dfdh_upper(i) = fsi_ws%dfdh_upper(i) - fsi_ws%dconductivity_dhead(i-1) * fsi_ws%head_gradient(i) * dkmean":
"fsi_ws%dfdh_upper(i) = fsi_ws%dfdh_upper(i) - 0.5d0*fsi_ws%dconductivity_dhead(i-1) * fsi_ws%head_gradient(i) * dkmean",
"fsi_ws%dfdh_main(i) = fsi_ws%dfdh_main(i) - fsi_ws%dconductivity_dhead(i) * fsi_ws%head_gradient(i) * dkmean":
"fsi_ws%dfdh_main(i) = fsi_ws%dfdh_main(i) - 0.5d0*fsi_ws%dconductivity_dhead(i) * fsi_ws%head_gradient(i) * dkmean",
"+ fsi_ws%dconductivity_dhead(i) * fsi_ws%head_gradient(i+1) * dkmean":
"+ 0.5d0*fsi_ws%dconductivity_dhead(i) * fsi_ws%head_gradient(i+1) * dkmean",
"fsi_ws%dfdh_lower(i) = fsi_ws%dfdh_lower(i) + fsi_ws%dconductivity_dhead(i+1) * fsi_ws%head_gradient(i+1) * dkmean":
"fsi_ws%dfdh_lower(i) = fsi_ws%dfdh_lower(i) + 0.5d0*fsi_ws%dconductivity_dhead(i+1) * fsi_ws%head_gradient(i+1) * dkmean",
"fsi_ws%dfdh_upper(NN) = fsi_ws%dfdh_upper(NN) - fsi_ws%dconductivity_dhead(NN-1) * fsi_ws%head_gradient(NN) * dkmean":
"fsi_ws%dfdh_upper(NN) = fsi_ws%dfdh_upper(NN) - 0.5d0*fsi_ws%dconductivity_dhead(NN-1) * fsi_ws%head_gradient(NN) * dkmean",
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) - fsi_ws%dconductivity_dhead(NN) * fsi_ws%head_gradient(NN) * dkmean":
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) - 0.5d0*fsi_ws%dconductivity_dhead(NN) * fsi_ws%head_gradient(NN) * dkmean",
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.5d0 * fsi_ws%dconductivity_dhead(NN) * fsi_ws%head_gradient(NN+1)":
"fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + 0.25d0*fsi_ws%dconductivity_dhead(NN) * fsi_ws%head_gradient(NN+1)"
}
for a,b in repls.items():
    src=src.replace(a,b)

contains_marker="contains\n\nlogical function pond_balance_option_allows()"
helper="""contains

subroutine timeint15_trapezoidal_residual()
   integer :: node
   real(8) :: storage_rate
   if (.not.timeint15_origin_captured) then
      do node=1,NN
         storage_rate=(state%theta(node)-state%thetm1(node))*matrix_fraction(node)*grid_dz(node)/dt
         timeint15_origin_nonstorage(node)=fsi_ws%residual(node)-storage_rate
      end do
      timeint15_origin_captured=.true.
   else
      do node=1,NN
         storage_rate=(state%theta(node)-state%thetm1(node))*matrix_fraction(node)*grid_dz(node)/dt
         fsi_ws%residual(node)=storage_rate+0.5d0*((fsi_ws%residual(node)-storage_rate)+timeint15_origin_nonstorage(node))
      end do
   end if
end subroutine timeint15_trapezoidal_residual

logical function pond_balance_option_allows()"""
if contains_marker not in src:
    raise SystemExit("TIMEINT15 contains marker missing")
src=src.replace(contains_marker,helper,1)

required=[
"timeint15_origin_nonstorage",
"0.5d0*state%kmean(i)",
"timeint15_trapezoidal_residual()",
"storage_rate+0.5d0"
]
for item in required:
    if item not in src:
        raise SystemExit(f"TIMEINT15 patch failed: {item}")

Path(args.output).write_text(src)
print("F_PE_TIMEINT15_TRAPEZOIDAL_MATERIALIZER=PASS")
