# PPA-WU05-MIGMAC02 preregistration — dynamic shrinkage/crack geometry

Date: 2026-10-02
Status: PREREGISTERED_SOURCE_RECONCILIATION
Canonical base: b2b758d878656c579e64c8de878d83cfdb628944
Parent authority: integration/audits/PPA_WU05_MACROPORE_MIGRATION_GAPS.json

## Scope

MIGMAC02 owns only the remaining standard-route gap:
dynamic shrinkage/crack-geometry feedback.

It does not reopen MIGMAC01 covering-layer physics, PERCH21 perched exchange,
A9 surface ownership, A10 rapid drainage, RossFast execution, or parallel
MultiSWAP execution.

## Current SWAP5 state

SWAP5 already has typed mutable geometry carriers in
macropore_continuation_state_t:

- dynamic_volume_cp;
- volume_domain_cp;
- icp_bottom_domain.

evaluate_macropore_geometry() already maps a supplied dynamic_volume_cp onto
total/domain geometry and compose_macropore_candidate() already returns water
displaced by geometry shrinkage/deactivation to the matrix with explicit mass
ownership.

This is infrastructure, not proof that B1.11 shrinkage physics is migrated.

The production single-column runtime currently calls
evaluate_macropore_geometry() with accepted_macro%dynamic_volume_cp and then
requires the derived domain geometry to match the accepted carrier before the
Richards solve. Therefore no production owner currently computes a new
source-faithful dynamic crack volume from matrix state during the trial.

## Source questions to resolve before implementation

1. What B1.11 variables determine VlMpDyCp and at what call sites?
2. Which inputs are immutable parameters and which are accepted physical state?
3. Is dynamic geometry evaluated once from the accepted matrix state, during
   nonlinear iteration, after Richards convergence, or in more than one stage?
4. Does B1.11 geometry use current theta/head, previous accepted theta/head,
   shrinkage history, or another carrier?
5. When geometry shrinks, is displaced macropore water returned to the matrix,
   surface, drainage, or another owner, and at what timing?
6. Which geometry fields must survive reject/replay/restart?
7. Does geometry change feed back into matrix area FrArMtrx in the same trial,
   and if so which source value owns that relation?

No within-Newton mutation is authorized unless exact source authority requires it.

## Required evidence

A source-backed fixture must contain a nonzero change in dynamic crack volume,
not merely a pre-populated dynamic_volume_cp.

Qualification must prove:

- source-backed dynamic-volume update;
- domain geometry and bottom-domain update where physically triggered;
- exact water ownership for geometry displacement;
- matrix/macropore total mass closure;
- rejected candidate does not mutate committed geometry;
- deterministic replay;
- persistence/restart identity;
- preservation of MIGMAC01, A9, A10 and PERCH20/PERCH21.

## Initial hypothesis

The existing SWAP5 state and geometry composer are likely reusable. The missing
production seam is expected to be the source-faithful operator that computes
the candidate dynamic crack volume and its exact accepted-state timing.

This hypothesis is explicitly falsifiable by the B1.11 source audit.

## Reconciliation addendum (2026-10-05)

The preregistration is retained as the original scope/questions record. The
corrected source audit did not establish exact B1.11 constitutive equations or
complete call timing: the recovered `macropore.f90` donor has SHA-256
`1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b`, while
authority pins B1.11 to `f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f`.
Therefore the previous intention to select a “source-defined” operator is
unfulfilled, and no donor-transcribed equation is admitted. See
`PPA_WU05_MIGMAC02_SOURCE_RECONCILIATION.md` and
`PPA_WU05_MIGMAC02_CLOSEOUT.md` for the superseding evidence boundary.


## Source-recovery addendum (2026-10-05)

The source blocker described above is resolved for clay option-1 and
`MPVOLUME(1)`: B1.11 was reconstructed from verified B0 plus the pinned
SWAP-001 patch and the SHA-256 matches authority. See
`PPA_WU05_MIGMAC02_SOURCE_RECONCILIATION.md`. Full qualification remains open;
in particular subsidence-adjusted dynamic surface area, rate-receipt identity,
retry/restart and mass closure need a passing runtime fixture. The earlier
source blocker text above is retained as preregistration history, not current
status.

## Runtime qualification addendum (2026-10-05)

The final qualification uses the existing A9 fixture in static and dynamic modes,
compiled once per optimization level. The dynamic mode must publish positive
crack history/capacity together, close the existing total-water ledger, discard A,
produce identical smaller B with reused and fresh backends, reproduce A after B,
and reproduce the next accepted candidate after persistence/restart. No tolerance
is relaxed. An independent two-domain storage oracle adds unchanged geometry,
dry-to-wet capacity loss/deactivation, exact per-domain matrix return, wet-to-dry
capacity gain and candidate history publication. Preservation includes MIGMAC01,
A8/A9/A10 and PERCH20. Broad peat/alternate parameter fitting and whole-model legacy
output parity are separate constitutive/input qualification claims.
