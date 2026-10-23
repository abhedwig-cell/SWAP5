# Changing-storage flux-correction research

Baseline:22cdf5700,23October2026. Successor to the frozen FCT prototype;
research only, no production interface, native dispatch or default change.

The wrapper calls the actual positive implicit-upwind process. Internal face
transfers alone are corrected. Positive downward face fluxes and old/new water
storage must close each cell's accepted water balance without sinks. Uniform
cells, unchanged uniform material, Freundlich exponent0.5 through2, positive
water and advective CFL<=1 are required. Sources other than rain, dispersion,
decay, root uptake, drainage, pond, age and aquifer ownership are unsupported.
Boundary solute transfers and receipt contributions stay exactly those of the
low-order solve. OFF delegates without imposing the research restrictions.

The high-order predictor reconstructs limited old concentrations, advances total
cell mass for half a step with explicit advective fluxes, then partitions it
using the real production Freundlich inversion at midpoint water content.
It never differentiates the singular C**0.5 storage law at zero. Negative
predictor amounts reject the attempt; stocks are not clipped. Internal high/low
transfer differences are limited by outgoing stock and incoming room. The upper
mass bound is evaluated with the actual nonlinear storage law at NEW theta and
the preceding/boundary global maximum concentration, not a constant retardation
factor. The final partition uses the production inversion and normalized
physical fractions, retaining authoritative total mass and the existing2048eps
equilibrium and8192eps balance certificates. Candidates remain original on ANY
failure, including failure after a successful low-order solve.

Affected invariants:3,5,7,13,21,23,25,29. Compliant research scope. No persistent
workspace, water solver internals, shared interface or physical gate changes.

Selection: real7-provider checked O0/O2 single-step driver, independent Python
triangular low-order solve and full conservative predictor/limiter oracle,
constant-concentration/zero exact solutions, atomic unsupported/malformed-state
rejections, exact OFF delegation and source/raw controls. Expected cost<30s.
Current original source/raw owner and frozen prototype evidence remain required.
Full moving F-CI, annual/native/restart, RossFast and highest-low-air are
NOT_SELECTED_IMPACT/POLICY: no production code or accepted runtime change.

This qualifies prescribed water-balanced steps, not traces emitted by a real
accepted water solve, time-series accuracy, nonlinear pulse convergence or
native benefit. Those remain subsequent requirements before activation.
