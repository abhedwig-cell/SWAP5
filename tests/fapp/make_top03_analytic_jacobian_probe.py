#!/usr/bin/env python3
"""Compose scratch analytic boundary Jacobian with pressure-aware progress."""
import argparse,subprocess,sys
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('output',type=Path);ap.add_argument('scope',choices=['bottom','both']);a=ap.parse_args()
subprocess.run([sys.executable,'tests/fapp/make_top03_terminal_trace_probe.py',str(a.output),'--strict-descent'],check=True)
s=a.output.read_text();needle='   ! input\n'
s=s.replace(needle,needle+'   use mod_top03_analytic_boundary_probe, only: top03_dkdh\n')
needle='      if (SwKimpl == 1) fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + fsi_ws%dconductivity_dhead(NN) * 0.5d0'
assert s.count(needle)==1
s=s.replace(needle,needle+'''
      if (SwKimpl == 0 .and. provider_constitutive_active .and. swmacro == 0) then
         select type(observed=>evaluation_context%dynamic_top_boundary)
         type is(top03_observed_top_t)
            fsi_ws%dfdh_main(NN)=fsi_ws%dfdh_main(NN)+top03_dkdh(observed%delegate%hydraulics,NN,state%h(NN))
         class default
            error stop 'analytic probe requires observed top'
         end select
      end if
''')
if a.scope=='both':
 needle='!  layers 2 to (NN-1)\n   do i = 2, NN-1\n      fsi_ws%dfdh_main(i)'
 assert s.count(needle)==1
 s=s.replace(needle,'''
   if (provider_dynamic_top_active .and. provider_constitutive_active .and. SwKimpl == 0 .and. swmacro == 0) then
      if (provider_dynamic_top_result%external_surface_head_imposed .and. swkmean == 1) then
         select type(observed=>evaluation_context%dynamic_top_boundary)
         type is(top03_observed_top_t)
            if(observed%delegate%fixed_top_node_conductivity >= 0.0d0)error stop 'analytic probe top K is frozen'
            fsi_ws%dfdh_main(1)=fsi_ws%dfdh_main(1)-0.5d0*top03_dkdh(observed%delegate%hydraulics,1,state%h(1))*fsi_ws%head_gradient(1)
         end select
      end if
   end if
'''+needle)
a.output.write_text(s)
print('TOP03_ANALYTIC_SCOPE='+a.scope)
