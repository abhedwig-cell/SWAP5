# PPA-WU05-MIGMAC02 timing contract

Date: 2026-10-02
Status: PREREGISTERED_IMPLEMENTATION_TIMING
Canonical parent: d92f1f8510300b34ee878fdbac237168c8fd7032

## Recovered nonlinear call semantics

The retained B1.11/A23 source path shows HeadCalc evaluating macropore rates
inside the nonlinear solve. On the active macropore route, HeadCalc calls the
rate path on the first iteration and again while the three-stage unsaturated
short-step policy has not frozen macropore rates. The derivative path is
likewise evaluated while that policy remains active.

The earlier source/state audits establish that VlMpDyCp is mutated by MPVOLUME
during trial evaluation and that legacy rollback was incomplete. Combined with
the E4 hysteresis result, this means dynamic crack volume is both:

- accepted continuation/history input to a new trial; and
- trial-local candidate state that may be refreshed from current nonlinear
  matrix moisture while macropore rates are being refreshed.

Therefore a production migration that computes shrinkage only once after
Richards convergence would not preserve the B1.11 coupling semantics.

## SWAP5 timing contract

For shrinkage-active source-backed configurations:

1. The committed macropore state, including accepted dynamic_volume_cp, is
   immutable for the duration of a trial.
2. Each macropore rate refresh receives current trial matrix theta and the
   accepted previous-step matrix theta.
3. The shrinkage operator computes a trial-local candidate dynamic_volume_cp
   using the accepted crack history as the hysteresis reference.
4. Derived geometry for that rate evaluation is recomputed from the trial-local
   candidate dynamic volume.
5. Macropore exchange and its derivative use that same candidate geometry.
6. When the existing B1.11 short-step policy freezes macropore rates, geometry
   and dynamic crack candidate are frozen with that rate receipt; they are not
   silently recomputed while the rate is frozen.
7. A rejected Richards/transaction trial discards the candidate crack state.
8. On accepted solve/transaction, the crack candidate associated with the
   accepted macropore receipt is published exactly once into the candidate
   continuation state.
9. Commit/restart then owns that accepted dynamic_volume_cp as ordinary
   macropore continuation state.

This reproduces the physical within-Newton feedback without reproducing legacy
module-global mutation or incomplete rollback.

## Derivative boundary

MIGMAC02 does not initially invent an analytic derivative of the shrinkage
transition with respect to pressure head.

The first implementation shall preserve the existing source decomposition:
geometry is refreshed with the rate evaluation, while the existing macropore
rate derivative contract remains the derivative authority. If qualification
shows that the missing geometry derivative prevents source-equivalent
convergence, that is a separate preregistered numerical question.

## First bounded production slice

Do not migrate all shrinkage input models at once.

The first slice shall implement one source-defined, valid shrinkage
parameterization with:

- nonzero opening/closing dynamic volume;
- hysteresis pair with identical current hydraulic state but different accepted
  crack history;
- geometry-displacement mass ownership;
- exact reject/replay/restart checks.

Clay + SWSHRINP=3 is explicitly excluded because the existing source audit
classifies that accepted combination as a likely B1.11 input-validation defect.

## Falsification

The timing contract is falsified if a source-backed capture demonstrates that
MPVOLUME candidate state used by a rate evaluation is not refreshed with the
current nonlinear matrix state, or that a different candidate is published at
accept than the one associated with the accepted rate receipt.
