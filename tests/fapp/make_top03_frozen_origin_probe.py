#!/usr/bin/env python3
"""Observe one failed trial, keeping reference law and numerical operations fixed."""
import argparse, subprocess, sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('head',type=Path);p.add_argument('test',type=Path);a=p.parse_args()
subprocess.run([sys.executable,'tests/fapp/make_top03_terminal_trace_probe.py',str(a.head),'--strict-descent'],check=True)
s=a.head.read_text();needle=' 1    continue\n';assert s.count(needle)==1
s=s.replace(needle,needle+'''
      if(canonical_trial.and.provider_dynamic_top_active.and.state%numbit==80)then
         write(*,'(*(g0,:,","))')'FROZEN_HEADER',NN,dt,state%hsurf,state%qtop,state%qbot
         do i=1,NN
            write(*,'(*(g0,:,","))')'FROZEN_NODE',i,grid_z(i),grid_dz(i),grid_disnod(i), &
              state%thetm1(i),state%h(i),state%theta(i),state%kmean(i),fsi_ws%residual(i), &
              fsi_ws%sink(i),fsi_ws%source(i),root_sink_term(i)
         end do
      end if
''')
a.head.write_text(s)
s=Path('tests/fapp/test_sw_rib_top03_surface_transition.f90').read_text()
s=s.replace('do bottom_case=1,3','do bottom_case=1,1').replace('do profile=1,3','do profile=1,1').replace('do history=1,3','do history=3,3').replace('do level=0,12','do level=11,11')
needle=' call initialize_b110_default_mvg_parameters(hp,cofgen)';assert s.count(needle)==1
s=s.replace(needle,needle+'''
 write(*,'(*(g0,:,","))')'FROZEN_COEFFICIENTS',hp%cofgen(:,1)
''')
a.test.write_text(s)
