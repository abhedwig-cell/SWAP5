# Research FCT with extracting roots and drainage

MC-SOL01 owns this isolated successor to PR1410/1411, based on canonical
`03c1c7a4`. Production source, defaults and public interfaces remain unchanged.
Affected invariants 3,5,7,13,21,23,25: explicit numerical predictor, paired
interior mass transfer, original physical laws and atomic whole-window commit.

For positive root/drainage sinks and TSCF in [0,1], reconstruct a private
advection-only carrier `theta_virtual = theta_previous + dt*div(q)/dz`.
This is NOT the accepted physical water state. The frozen advection FCT and
implicit upwind predictor use precisely that same carrier and no sinks. Their
paired conservative correction is limited against original total storage and
original-water maximum capacity, as in the admitted reactive successor. The
existing source-generated corrected implicit solver then uses the REAL ending
water, root sink, drainage, sorption, dispersion and decay together. All physical
receipts are calculated from that final candidate, never the virtual predictor.
The real carrier must close with divergence minus root and drainage. Negative
drainage (infiltration), upward flow and unsupported frozen FCT domains reject.
No final concentration cap is imposed: TSCF<1 can physically concentrate solute.
No sinks delegates the admitted reactive route exactly; OFF delegates production.

Qualification selection: small actual production-driver O0/O2 closure first,
Freundlich0.5/1/2, TSCF0/0.5/1, root-only/drain-only/mixed, no-flow algebraic
storage/sink oracles and nonzero advection/dispersion/decay finite-volume
equations. Assert nonmutation, invalid-carrier/domain rejection, exact OFF and
zero-sink delegation. Then actual Richards fixed extraction/drainage traces on
40/80 cells, two top fluxes, nonlinear sorption, both zero and unit uptake:
late rejection, exact retry and opaque checkpoint continuation. Explicit
prescribed extraction/positive drainage only; no crop root-demand generator,
head-dependent DRA/DIVDRA activation or new disk qualification is implied.
Expected small tests <10s, real joint build/run <180s. Full F-CI, native year,
RossFast and highest-low-air are NOT_SELECTED_IMPACT: no production change.
Current composed NUT owner/source/raw controls and predecessor capsule are
selected for final preservation. Seal source checkpoints, generated sources,
compile closure, actual raw outputs, failures and independent verification.
No production activation or full MC-SOL01 closure follows this research proof.
