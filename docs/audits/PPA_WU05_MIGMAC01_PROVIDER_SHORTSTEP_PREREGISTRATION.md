# PPA-WU05-MIGMAC01 provider short-step continuation preregistration

Date: 2026-10-02
Status: PREREGISTERED_FALSIFICATION_REPAIR
Owning head observed before preregistration: 5a57bdeebcf0bfff38386e7a9a2094fccf90460f
Scope: corrected source-backed IcTopMp > 1 Reference-Richards replay only

## Observation

After the typed physical carriers and G6 stable storage-increment repair, the
frozen corrected-source event still requests retry after 64 nonlinear iterations.

Persisted run 36987566375 shows:

- compartment balance gate passes: FMAX = 9.6664343196550817e-13;
- total balance gate fails: 5.6654011722830772e-12;
- head gate fails: maximum ratio = 10.409118;
- limiting head node = 22, old h = 0.66379434151739114 cm,
  delta h = -1.0409117339502867e-11 cm;
- one ULP at that head is 1.1102230246251565e-16 cm.

Therefore the remaining head failure is not a floating-point representability
floor. No tolerance relaxation or representability exception is permitted.

## Source-policy gap to falsify

B1.11 HeadCalc has a macropore-specific short-step iteration policy for
dt < 0.01 day. With legacy SWMACRO=1 it advances three unsaturated flags when
ponding balance permits and no saturated node simultaneously fails both the
compartment-balance and head criteria. Once flag 3 is active, the legacy
MACROPORE(2) rate refresh and MACROPORE(3) derivative refresh are suppressed;
the previously evaluated exchange is retained.

The explicit typed provider route deliberately keeps local SWMACRO=0 to avoid
legacy module-global ownership. Consequently it currently never enters that
short-step policy, and provider rate/derivative evaluation continues every
Newton iteration.

Hypothesis H1: this missing iteration-policy semantics, not a physical covering
formula or relaxed convergence criterion, explains the remaining source replay
failure.

## Bounded repair

Extend the existing short-step policy trigger to an active typed macropore
provider without setting SWMACRO=1.

When the third unsaturated flag is active on the typed provider route:

1. retain the last provider exchange rate rather than re-evaluating it;
2. do not add a fresh provider exchange derivative to the Jacobian;
3. preserve all ordinary compartment, total-balance and head convergence gates;
4. preserve explicit matrix-area ownership and keep all legacy module-global
   macropore calls disabled;
5. do not alter forcing, dt, tolerances, source reduction, covering physics or
   the frozen source fixture.

This is a source-policy migration, not a numerical shortcut invented for the
fixture.

## Falsification

Run the same frozen corrected-source diagnostic. H1 is supported only if the
provider route enters the historical three-stage short-step continuation and
the strict native solve converges without tolerance/input changes.

If it still rejects, retain the negative result and continue attribution. Do
not tune the fixture or relax gates.

Any converged result remains diagnostic only until exact covered-transfer
ownership, macro closure, reject/replay/restart and PERCH20/PERCH21, A9 and A10
preservation are rerun on the exact postimage.
