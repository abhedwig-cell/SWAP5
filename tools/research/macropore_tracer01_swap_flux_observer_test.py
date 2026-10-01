#!/usr/bin/env python3
from pathlib import Path
import importlib.util, sys
P=Path(__file__).with_name('macropore_tracer01_swap_flux_observer.py')
spec=importlib.util.spec_from_file_location('tracer01c',P)
m=importlib.util.module_from_spec(spec); sys.modules[spec.name]=m; spec.loader.exec_module(m)

start=(0.20,0.20,0.20); dz=(10.0,10.0,10.0); dt=0.1
qtop=-1.0; q=( -0.8,-0.5,-0.2 )
end=(
 start[0]+(q[0]-qtop)*dt/dz[0],
 start[1]+(q[1]-q[0])*dt/dz[1],
 start[2]+(q[2]-q[1])*dt/dz[2])
r=m.reconstruct_accepted_transfers(start,end,dz,dt,qtop,q[2])
assert r.valid
assert max(abs(a-b) for a,b in zip(r.interface_flux_cm_per_day,q))<1e-12
assert abs(r.bottom_flux_residual_cm_per_day)<1e-12

# Upward case reconstructs and reverses donors.
qtop=0.1; q=(0.2,0.3,0.4)
end=(
 start[0]+(q[0]-qtop)*dt/dz[0],
 start[1]+(q[1]-q[0])*dt/dz[1],
 start[2]+(q[2]-q[1])*dt/dz[2])
r=m.reconstruct_accepted_transfers(start,end,dz,dt,qtop,q[2])
assert r.valid
assert any(x.label=='interface-2-up' and x.donor==2 and x.receiver==1 for x in r.transfers)

# Source/sink terms close exactly.
source=(0.0,0.2,0.0); sink=(0.0,0.0,0.1)
qtop=-0.5; q1=-0.4; q2=-0.25; qbot=-0.10
end=(
 start[0]+(q1-qtop+source[0]-sink[0])*dt/dz[0],
 start[1]+(q2-q1+source[1]-sink[1])*dt/dz[1],
 start[2]+(qbot-q2+source[2]-sink[2])*dt/dz[2])
r=m.reconstruct_accepted_transfers(start,end,dz,dt,qtop,qbot,source,sink)
assert r.valid

# Wrong qbot fails closed.
bad=m.reconstruct_accepted_transfers(start,end,dz,dt,qtop,qbot+0.5,source,sink)
assert not bad.valid and 'bottom flux' in bad.reason

print('PASS F-MACRO-TRACER01-C accepted flux observer contract')
