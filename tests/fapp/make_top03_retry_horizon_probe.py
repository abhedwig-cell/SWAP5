#!/usr/bin/env python3
"""Declared research fallback packets; original nominal solve remains untouched."""
import argparse,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('head',type=Path);p.add_argument('test',type=Path);a=p.parse_args()
subprocess.run([sys.executable,'tests/fapp/make_top03_terminal_trace_probe.py',str(a.head),'--strict-descent'],check=True)
s=Path('tests/fapp/test_sw_rib_top03_surface_transition.f90').read_text()
s=s.replace('do bottom_case=1,3','do bottom_case=1,1').replace('do profile=1,3','do profile=1,2').replace('do level=0,12','do level=6,12').replace('  do history=1,3','  do history=1,3\n   if(history==2)cycle')
needle='  type(reference_richards_legacy_workspace_t)::workspace';assert s.count(needle)==1
s=s.replace(needle,needle+'''
  type(soil_water_solve_request_t)::packet_output
  real(real64)::packet_top,packet_bottom,packet_residual
  integer::packet_attempts,packet_rejected,packet_iterations,packets,failed_packets,retry_attempts,retry_rejected,successful_packets
  logical::packet_ok
''')
needle='  call cpu_time(cpu0)';assert s.count(needle)==1
s=s.replace(needle,'''  packets=0;failed_packets=0;retry_attempts=0;retry_rejected=0;successful_packets=0
'''+needle)
needle='   if(r%status/=SW_SOLVE_CONVERGED)then';assert s.count(needle)==1
s=s.replace(needle,needle+'''
    packets=packets+1
    call bounded_retry_packet(q,dt,external_head,packet_output,packet_top,packet_bottom,packet_ok, &
      packet_attempts,packet_rejected,packet_iterations,packet_residual)
    retry_attempts=retry_attempts+packet_attempts;retry_rejected=retry_rejected+packet_rejected
    iters=iters+packet_iterations
    if(packet_ok)then
     successful_packets=successful_packets+1
     transfer_cm=transfer_cm+packet_top;bottom_cm=bottom_cm+packet_bottom
     resmax=max(resmax,packet_residual)
     if(j==1)first_cm=packet_top
     q%base_state=packet_output%base_state;done=j
     cycle
    end if
    failed_packets=failed_packets+1
''')
needle='  call cpu_time(cpu1)';assert s.count(needle)==1
s=s.replace(needle,'''  write(*,'(*(g0,:,","))')'ADAPT_COUNTS',geometry_id,q%boundary%bottom_mode,profile,history,steps, &
    packets,successful_packets,failed_packets,retry_attempts,retry_rejected
'''+needle)
support=Path('tests/fapp/top03_retry_research.inc').read_text().split(' subroutine retry_step(',1)[1]
support=' subroutine retry_step('+support
support=support.replace('accepted,iterations,residual)','accepted,iterations,residual,imposed_head)',1)
support=support.replace(' real(real64),intent(in)::step',' real(real64),intent(in)::step,imposed_head',1)
support=support.replace('local_top%delegate%external_surface_water_head_cm=0.02_real64','local_top%delegate%external_surface_water_head_cm=imposed_head')
s=s.replace('contains\n','contains\n'+Path('tests/fapp/top03_retry_packet.inc').read_text()+support,1)
a.test.write_text(s)
