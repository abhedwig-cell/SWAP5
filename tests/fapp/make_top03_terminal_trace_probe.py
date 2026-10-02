#!/usr/bin/env python3
"""Generate an observational scratch headcalc; no numerical operations changed."""
import argparse,hashlib
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('output',type=Path);a=ap.parse_args()
p=Path('src/legacy/b1_10_port/headcalc.f90');s=p.read_text()
needle='   ! input\n';assert s.count(needle)==1
s=s.replace(needle,needle+'   use mod_top03_observed_top, only: top03_observed_top_t\n')
needle=' 1    continue\n';assert s.count(needle)==1
trace='''
! TOP03 research observation only, after the unchanged line search.
      if (canonical_trial .and. provider_dynamic_top_active .and. state%numbit >= MaxIt-7) then
         select type (observed => evaluation_context%dynamic_top_boundary)
         type is (top03_observed_top_t)
            if (associated(observed%trace)) then
               write(*,'(*(g0,:,","))') 'ITER',trim(observed%trace%label),state%numbit,itry, &
                    dt,factor,sumold,sump,Fmax,maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))), &
                    maxval(abs(fsi_ws%delta_head(1:NN))),fsi_ws%old_head(1),state%h(1), &
                    fsi_ws%old_head(NN),state%h(NN),state%qtop,state%qbot,state%k(NN),state%dimoca(NN), &
                    fsi_ws%dfdh_main(NN),fsi_ws%residual(NN),minval(state%h(1:NN)),maxval(state%h(1:NN)), &
                    state%kmean(1),CritDevBalCp,CritDevBalTot
            end if
         end select
      end if
'''
s=s.replace(needle,needle+trace)
a.output.write_text(s)
print('TOP03_TRACE_ORIGINAL_SHA256='+hashlib.sha256(p.read_bytes()).hexdigest())
