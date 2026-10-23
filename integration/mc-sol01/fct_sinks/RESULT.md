# Extracting roots and drainage: bounded research qualification

162 checked real-process O0/O2 cases pass with Freundlich0.5/1/2,
TSCF0/0.5/1, root-only, two-level drain-only and combined extraction.
Independent scalar bisection verifies no-flow storage/extraction; independent
finite-volume equations verify advection, mechanical/molecular dispersion,
decay and extracting sinks. The largest equation residual is5.480e-15 and
scalar-oracle error7.328e-15. Water-only root extraction correctly increases
concentration; full-concentration extraction preserves a uniform concentration.
Both OFF and sink-free predecessor delegation remain exact. All3240 invalid
process trials leave the original state unchanged.

48 real40/80cell Richards joint cases at O0/O2 pass:4668 primary accepted
substeps,960 atomic rejected windows,192 exact retries and96 exact opaque
checkpoint continuation windows. Accepted traces supply the actual root and
positive drainage sinks. Their separately reported chemical exports are included
once in total output. Maximum whole mass residual1.220e-14mg/cm2; maximum
O0/O2 numerical difference5.968e-16. A complete round took110.146s. Failed
compiler-launch rounds and the incomplete first joint round are retained,
not counted as complete qualification; the runner repairs executable mode on
its own new build artifacts and captures subsequent launch errors.

Nine new evidence controls pass, including rebound-hash negative mass,
equilibrium-preserving wrong extraction, omitted compiled-source binding and
missing drainage execution. Qualification-time current owner179 controls and
all eight predecessor pulse/restart controls pass. Source checkpoints, generated
modules, actual ordered11/176source closures, compiler identities, raw streams
and failed/incomplete rounds are sealed in the indexed capsule.

Only a private numerical predictor uses the sink-free virtual carrier. Final
physics always uses real ending water and the original implicit physical laws.
No production source, dispatch, default or persistent schema is changed. The
contract's bounded domain is not crop root-demand/DRA generation, new disk
restart proof for sinks, general nonlinear/full coupled-PDE accuracy or complete
MC-SOL01 closure. Current reconciliation and actual canonical admission are
separate authorities; qualification alone is not admission.
