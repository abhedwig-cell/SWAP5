#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="   logical                          :: flboth, flok\n"
insert=marker+"""   integer :: nlglob01_node_raw,nlglob01_node_zh,nlglob01_node_dtheta,nlglob01_node_res
   real(8) :: nlglob01_dh_inf,nlglob01_dh_l2,nlglob01_zh_inf,nlglob01_dtheta_inf,nlglob01_tmp
"""
if marker not in src:
    raise SystemExit("NLGLOB01 declaration marker missing")
src=src.replace(marker,insert,1)

marker="""!     in the rare case that TRIDAG fails, use alternative solution
      if (ierror /= 0) then
"""
insert="""      if (provider_dynamic_top_active) then
         nlglob01_dh_inf=0.0d0
         nlglob01_dh_l2=sqrt(dot_product(fsi_ws%delta_head(1:NN),fsi_ws%delta_head(1:NN)))
         nlglob01_zh_inf=0.0d0
         nlglob01_dtheta_inf=0.0d0
         nlglob01_node_raw=1
         nlglob01_node_zh=1
         nlglob01_node_dtheta=1
         nlglob01_node_res=maxloc(dabs(fsi_ws%residual(1:NN)),dim=1)
         do i=1,NN
            nlglob01_tmp=dabs(fsi_ws%delta_head(i))
            if (nlglob01_tmp > nlglob01_dh_inf) then
               nlglob01_dh_inf=nlglob01_tmp
               nlglob01_node_raw=i
            end if
            nlglob01_tmp=dabs(fsi_ws%delta_head(i))/max(1.0d0,dabs(fsi_ws%old_head(i)))
            if (nlglob01_tmp > nlglob01_zh_inf) then
               nlglob01_zh_inf=nlglob01_tmp
               nlglob01_node_zh=i
            end if
            nlglob01_tmp=dabs(state%dimoca(i)*fsi_ws%delta_head(i))
            if (nlglob01_tmp > nlglob01_dtheta_inf) then
               nlglob01_dtheta_inf=nlglob01_tmp
               nlglob01_node_dtheta=i
            end if
         end do
         write(*,'(*(g0))') 'F_PE_NLGLOB01_STEP|ITER=',state%numbit,'|DH_INF=',nlglob01_dh_inf, &
              '|DH_L2=',nlglob01_dh_l2,'|NODE_RAW=',nlglob01_node_raw,'|ZH_INF=',nlglob01_zh_inf, &
              '|NODE_ZH=',nlglob01_node_zh,'|DTHETA_INF=',nlglob01_dtheta_inf, &
              '|NODE_DTHETA=',nlglob01_node_dtheta,'|NODE_RES=',nlglob01_node_res, &
              '|TOP_DH=',dabs(fsi_ws%delta_head(1)), &
              '|BOTTOM_DH=',dabs(fsi_ws%delta_head(NN)),'|ROUTE=',trim(provider_dynamic_top_result%route)
      end if

!     in the rare case that TRIDAG fails, use alternative solution
      if (ierror /= 0) then
"""
if marker not in src:
    raise SystemExit("NLGLOB01 Newton-step marker missing")
src=src.replace(marker,insert,1)

if "F_PE_NLGLOB01_STEP" not in src:
    raise SystemExit("NLGLOB01 injection failed")
Path(args.output).write_text(src)
print("F_PE_NLGLOB01_MATERIALIZER=PASS")
