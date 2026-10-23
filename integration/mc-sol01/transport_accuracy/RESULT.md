# Separate space and time accuracy of implicit upwind transport

Qualified bounded research, 23 October 2026. This does not qualify the spatial
accuracy of the native 41-cell historical-weather year or nonlinear Freundlich
transport. Production, defaults and tolerances are unchanged.

The actual six-provider production process is compiled O0/O2 with runtime checks.
A Gaussian cell-average pulse traverses a 40-cm constant-water column for two days:
theta=0.25, downward q=0.25 cm/day, bulk density=1.3, decay=0.05/day. The two cases
use (Kf, dispersivity)=(0,0.01 cm) and (0.2,0.02 cm), with linear sorption. No
molecular diffusion, root/drain sink or surface solute stock is active. The
Gaussian starts at 15 cm with unit standard deviation. Inlet concentration is
zero and the outlet is convective; infinite-line Gaussian boundary concentrations
are below 1e-40 during this short experiment. The small finite-boundary mismatch
is retained as a limitation, not asserted exactly zero.

For R=theta+rho*Kf, the independent continuum equation is
R*C_t=alpha*q*C_zz-q*C_z-lambda*R*C. The analytic cell averages use the translated
Gaussian, variance 1+2*alpha*q*t/R and amplitude factor exp(-lambda*t).
An independently assembled constant finite-volume mass matrix, exponentiated
with SciPy, supplies the solution continuous in time on each fixed grid.
A separate dense backward-Euler solution checks the coarse-time production
trajectory to 1e-12. These numerical oracles are independent of production
solver implementation; they are floating-point evaluations, not exact arithmetic.

Four grids (40,80,160,320 cells) use a fixed 0.002-day step. Five time steps
(0.2,0.1,0.05,0.025,0.0125 day) use a fixed 80-cell grid. The 36 actual profiles
include both physical cases and both compiler optimizations. O0/O2 profiles
agree within 1e-12. Stocks remain nonnegative and the maximum recorded per-step
mass residual is 1.950e-15 mg/cm2, rounded upwards; the maximum cumulative
residual is 3.553e-15 mg/cm2. The separate time error decreases at observed orders
0.92 to 1.00. Spatial orders increase from 0.59 to 0.92 as the mesh is refined;
all separate and combined space errors decrease. On the space sequence, the
time error is below 1.5% of the space error.

| Cells | Width (cm) | Peak deficit, Kf=0 | Peak deficit, Kf=0.2 |
| --- | --- | --- | --- |
| 40 | 1 | 32.2% | 18.5% |
| 80 | 0.5 | 26.1% | 15.4% |
| 160 | 0.25 | 17.3% | 9.7% |
| 320 | 0.125 | 10.2% | 5.4% |

Deficits compare the numerical and analytic cell-average maxima on the same
grid, at the fixed 0.002-day step. They are specific to this narrow pulse,
travel time and physical parameters. They are not error estimates for the
native year. They demonstrate that closed mass and positive concentrations
can coexist with appreciable numerical spreading. The leading spatial
modified-equation dispersivity of first-order upwind is dx/2: even dx=0.125 cm
adds 0.0625 cm against the physical 0.01 or 0.02 cm in these cases. Reducing
the time step alone cannot remove that spatial contribution.

Evidence and exact reproduction are owned by STATUS.json and run.py. The
98-member capsule retains both final checked builds, all streams/profiles,
executed source inputs, the execution checkpoint and initial development
results. Six corruption/source/build/negative-stock controls pass. The current
saturated-flux source/raw owner and its 18 controls pass, including validation
of its retained predecessor147/concurrent163-control records. These old native
executions are inherited evidence, not new repetitions in this study.

The next scientific step is profile-accuracy qualification for the actual
coupled native trajectory, or a separately qualified less diffusive numerical
policy. No universal grid criterion or full SOL/NUT closure follows here.
