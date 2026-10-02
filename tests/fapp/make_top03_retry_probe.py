#!/usr/bin/env python3
"""Generate bounded source-preserving retry research from the observed trial."""
import argparse,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('head',type=Path);p.add_argument('test',type=Path);a=p.parse_args()
subprocess.run([sys.executable,'tests/fapp/make_top03_terminal_trace_probe.py',str(a.head),'--strict-descent'],check=True)
s=Path('tests/fapp/test_sw_rib_top03_surface_transition.f90').read_text()
s=s.replace('do bottom_case=1,3','do bottom_case=1,1').replace('do profile=1,3','do profile=1,1').replace('do history=1,3','do history=3,3').replace('do level=0,12','do level=11,11')
needle='   call solver%solve(q,workspace,r)';assert s.count(needle)==1
s=s.replace(needle,'''   if(j==86)call research_retries(q,dt)
'''+needle)
needle='contains\n';assert s.count(needle)==1
s=s.replace(needle,needle+Path('tests/fapp/top03_retry_research.inc').read_text())
a.test.write_text(s)
