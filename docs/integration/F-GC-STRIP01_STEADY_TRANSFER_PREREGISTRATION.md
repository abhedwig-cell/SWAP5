# STRIP01 stationary transfer reference preregistration

Research only, before stationary-transfer execution. The hydrostatic dry-vadose
initial case retains essentially all first-day rain in SWAP, and therefore
cannot yet test the far-cell-to-drain transfer within a small E2E period.
A separate physically wet stationary initial condition tests that route.
No terrain, interface, K, storage owner or forcing threshold changes.

MF confined T=2 m2/d, R=0.001 m/d, DRN=-5 m, C=100 m2/d. Construct the exact
50-cell stationary confined finite-volume profile: cell 1 H=stage+50R/C;
face j carries (50-j)R and H[j]-H[j-1]=q_face/T. Right boundary closed.

For each SWAP column independently solve constant downward vertical flux
0.1 cm/d using the qualified B01 provider and arithmetic face conductivity,
20 cm node spacing and a 10 cm bottom half-cell. Starting at the known bottom
head, solve each scalar upstream-face equation by bisection. This hydrological
oracle reuses the qualified constitutive provider but does not call Richards
or fit a simulated profile. Evaluate every face residual independently.
Initial water content comes from that provider; GWL is derived from the
pressure zero crossing, not supplied as a boundary. Set temporal derivative
history to zero because the declared initial state/forcing is stationary.

Run ten 0.1 d windows (one day) at the original strict numerical configuration,
then qualify an allocated variant only if needed, preserving failures. Require:
each accepted SWAP exchange positive and within 1e-10 m3/d of 0.001; MF head
within 1e-9 m of stationary confined oracle; drain ~0.05 m3/d within 1e-8;
unchanged per-column mass/combined volume gates, exact replay and one commit.
Track interface/MF head and SWAP pressure-zero GWL separately. Saturated Darcy
expectation GWL=(H+6*r)/(1-r), r=R_cm/Ksat_cm, predicts a small positive
head/GWL separation. Do not impose equality.

Negative control: disconnect cell 50's API source while retaining its real
SWAP exchange. Require rejection before any accepted coupled commit. The
independent MF matrix oracle must use actual published terms, not assume the
SWAP source reached MF. No full dynamic Hupsel or general restart claim follows
from stationary transfer qualification.
