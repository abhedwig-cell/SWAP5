#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

# Trial-only diagnostic storage in the HeadCalc host scope.
marker="   logical                          :: flboth, flok\n"
insert=marker+"""   real(8) :: nlglob04_s(1000),nlglob04_u(1000),nlglob04_l(1000),nlglob04_q(1000),nlglob04_t(1000)
"""
if marker not in src:
    raise SystemExit("NLGLOB04 declaration marker missing")
src=src.replace(marker,insert,1)

# Recompute the exact non-overlapping residual terms from the same state/flux
# variables used by vector_F.  The assembled residual is NOT used to construct
# any term; it is only emitted later as an independent decomposition check.
end_marker="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

end subroutine vector_F
"""
end_repl="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

   if (provider_dynamic_top_active) then
      nlglob04_s(1:NN)=0.0d0
      nlglob04_u(1:NN)=0.0d0
      nlglob04_l(1:NN)=0.0d0
      nlglob04_q(1:NN)=0.0d0
      nlglob04_t(1:NN)=0.0d0

      do i=1,NN
         nlglob04_s(i)=(state%theta(i)-state%thetm1(i))*matrix_fraction(i)*grid_dz(i)/dt
         nlglob04_q(i)=fsi_ws%sink(i)-fsi_ws%source(i)+root_sink_term(i)
      end do

      if (NN > 1) then
         nlglob04_l(1)=state%kmean(2)*fsi_ws%head_gradient(2)
      end if
      if (state%ftoph) then
         nlglob04_t(1)=-state%kmean(1)*fsi_ws%head_gradient(1)
      else
         nlglob04_t(1)=state%qtop
      end if

      do i=2,NN-1
         nlglob04_u(i)=-state%kmean(i)*fsi_ws%head_gradient(i)
         nlglob04_l(i)= state%kmean(i+1)*fsi_ws%head_gradient(i+1)
      end do

      if (NN > 1) nlglob04_u(NN)=-state%kmean(NN)*fsi_ws%head_gradient(NN)

      if (swbotb == 1 .AND. (.NOT.state%fllowgwl)) then
         nlglob04_l(NN)=state%kmean(NN+1)*fsi_ws%head_gradient(NN+1)
      else if (swbotb == 3 .AND. swbotb3Impl == 1) then
         nlglob04_l(NN)=-state%qbot
      else if (swbotb == 5 .OR. (swbotb == 1 .AND. state%fllowgwl)) then
         nlglob04_l(NN)=state%kmean(NN+1)*fsi_ws%head_gradient(NN+1)
      else if (swbotb == 9) then
         nlglob04_l(NN)=state%kmean(NN+1)*fsi_ws%head_gradient(NN+1)
      else if (swbotb == 7 .OR. swbotb == -2) then
         nlglob04_l(NN)=-state%qbot
      else if (swbotb == 8) then
         if (flboth) nlglob04_l(NN)=state%kmean(NN+1)*fsi_ws%head_gradient(NN+1)
      else
         nlglob04_l(NN)=-state%qbot
      end if

      if (swmacro == 1) nlglob04_q(1:NN)=nlglob04_q(1:NN)-QExcMpMtx(1:NN)
   end if

end subroutine vector_F
"""
if end_marker not in src:
    raise SystemExit("NLGLOB04 vector_F end marker missing")
src=src.replace(end_marker,end_repl,1)

# Emit the frozen decomposition at the same Newton origin where NLGLOB01 emits
# the step/residual-location diagnostic.  R is independent authority for the
# decomposition closure check, not an input to the terms above.
needle="""         write(*,'(*(g0))') 'F_PE_NLGLOB01_STEP|ITER=',state%numbit,'|DH_INF=',nlglob01_dh_inf, &
              '|DH_L2=',nlglob01_dh_l2,'|NODE_RAW=',nlglob01_node_raw,'|ZH_INF=',nlglob01_zh_inf, &
              '|NODE_ZH=',nlglob01_node_zh,'|DTHETA_INF=',nlglob01_dtheta_inf, &
              '|NODE_DTHETA=',nlglob01_node_dtheta,'|NODE_RES=',nlglob01_node_res, &
              '|TOP_DH=',dabs(fsi_ws%delta_head(1)), &
              '|BOTTOM_DH=',dabs(fsi_ws%delta_head(NN)),'|ROUTE=',trim(provider_dynamic_top_result%route)
      end if
"""
repl="""         write(*,'(*(g0))') 'F_PE_NLGLOB01_STEP|ITER=',state%numbit,'|DH_INF=',nlglob01_dh_inf, &
              '|DH_L2=',nlglob01_dh_l2,'|NODE_RAW=',nlglob01_node_raw,'|ZH_INF=',nlglob01_zh_inf, &
              '|NODE_ZH=',nlglob01_node_zh,'|DTHETA_INF=',nlglob01_dtheta_inf, &
              '|NODE_DTHETA=',nlglob01_node_dtheta,'|NODE_RES=',nlglob01_node_res, &
              '|TOP_DH=',dabs(fsi_ws%delta_head(1)), &
              '|BOTTOM_DH=',dabs(fsi_ws%delta_head(NN)),'|ROUTE=',trim(provider_dynamic_top_result%route)
         do i=1,NN
            write(*,'(*(g0))') 'F_PE_NLGLOB04_TERM|ITER=',state%numbit,'|NN=',NN,'|NODE=',i, &
                 '|S=',nlglob04_s(i),'|U=',nlglob04_u(i),'|L=',nlglob04_l(i), &
                 '|Q=',nlglob04_q(i),'|T=',nlglob04_t(i),'|R=',fsi_ws%residual(i)
         end do
      end if
"""
if needle not in src:
    raise SystemExit("NLGLOB04 NLGLOB01-step marker missing")
src=src.replace(needle,repl,1)

for token in ("F_PE_NLGLOB04_TERM","nlglob04_s(1:NN)","nlglob04_t(1)"):
    if token not in src:
        raise SystemExit(f"NLGLOB04 materialization failed: {token}")

Path(args.output).write_text(src)
print("F_PE_NLGLOB04_MATERIALIZER=PASS")
