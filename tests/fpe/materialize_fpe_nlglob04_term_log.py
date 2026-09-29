#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()
src=Path(args.source).read_text()

marker="   real(8)                          :: CritDevBalCp, CritDevBalTot\n"
insert=marker+"""   real(8) :: nlglob04_storage,nlglob04_upper,nlglob04_lower,nlglob04_bc,nlglob04_ss
"""
if marker not in src:
    raise SystemExit("NLGLOB04 declaration marker missing")
src=src.replace(marker,insert,1)

needle="""         do i=1,NN
            write(*,'(*(g0))') 'F_PE_NLGLOB03_RES|ITER=',state%numbit,'|NN=',NN,'|NODE=',i, &
                 '|R=',fsi_ws%residual(i)
         end do
"""
repl=needle+"""         do i=1,NN
            nlglob04_storage=(state%theta(i)-state%thetm1(i))*matrix_fraction(i)*grid_dz(i)/dt
            nlglob04_ss=fsi_ws%sink(i)-fsi_ws%source(i)+root_sink_term(i)
            nlglob04_upper=0.0d0
            nlglob04_lower=0.0d0
            nlglob04_bc=0.0d0
            if (i == 1) then
               if (NN > 1) nlglob04_lower=state%kmean(2)*fsi_ws%head_gradient(2)
               if (state%ftoph) then
                  nlglob04_bc=-state%kmean(1)*fsi_ws%head_gradient(1)
               else
                  nlglob04_bc=state%qtop
               end if
            else if (i == NN) then
               nlglob04_upper=-state%kmean(NN)*fsi_ws%head_gradient(NN)
               if (swbotb /= 2) nlglob04_bc=fsi_ws%residual(i) - &
                    (nlglob04_storage+nlglob04_upper+nlglob04_ss)
            else
               nlglob04_upper=-state%kmean(i)*fsi_ws%head_gradient(i)
               nlglob04_lower=state%kmean(i+1)*fsi_ws%head_gradient(i+1)
            end if
            write(*,'(*(g0))') 'F_PE_NLGLOB04_TERM|ITER=',state%numbit,'|NN=',NN,'|NODE=',i, &
                 '|STORAGE=',nlglob04_storage,'|UPPER=',nlglob04_upper,'|LOWER=',nlglob04_lower, &
                 '|BC=',nlglob04_bc,'|SS=',nlglob04_ss,'|THETA=',state%theta(i), &
                 '|THETAM1=',state%thetm1(i),'|FRAC=',matrix_fraction(i),'|DZ=',grid_dz(i), &
                 '|RES=',fsi_ws%residual(i),'|SWBOTB=',swbotb
         end do
"""
if needle not in src:
    raise SystemExit("NLGLOB04 residual-vector marker missing")
src=src.replace(needle,repl,1)

for req in ("F_PE_NLGLOB04_TERM","nlglob04_storage","|THETAM1="):
    if req not in src:
        raise SystemExit(f"NLGLOB04 injection failed: {req}")

Path(args.output).write_text(src)
print("F_PE_NLGLOB04_MATERIALIZER=PASS")
