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
