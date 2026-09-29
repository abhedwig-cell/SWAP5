# F-PE-NLGLOB14U preregistration — accepted-state moving-interface evolution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority rechecked before this write:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14T: `QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL`;
- parent branch postimage: `research/f-pe-nlglob14t-transactional-split-shadow@9d529e71cb02283f3599d3203a51d38e88cf7347`;
- NLGLOB14S mechanical split feasibility remains prerequisite;
- NLGLOB14N3 saturation-root retry-bracket semantics and refined first-retreat event timing remain unchanged;
- whole-column first-retreat TG release remains falsified.

## Purpose

NLGLOB14T proved one finite split shadow interval can close transactionally. NLGLOB14U asks the next question:

can those split endpoints be accepted into a private research accepted state for multiple consecutive intervals while the ownership interface moves only in response to the accepted physical saturated set?

No production state or production source is changed.

## Frozen fixtures

Use the same 12 O05 trajectories:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- start from the first accepted 14 -> 13 retreat state;
- unchanged dry forcing;
- unchanged qbot;
- persistent-KLAG trajectory remains the external control trajectory.

The research split trajectory may advance at most until the original 0.05 d horizon or a preregistered safety cap of 512 accepted split intervals, whichever comes first.

## Accepted-state ownership rule

After each accepted split endpoint, derive the saturated set from the accepted physical state only.

A moving-interface split remains applicable only when the accepted saturated set is a contiguous lower block `k:16` with an unsaturated upper block `1:k-1`.

Then:

- upper nodes `1:k-1` use TG temporal treatment;
- lower nodes `k:16` use saturated/full-Richards temporal treatment;
- the ownership interface is the single face `k-1/k`;
- exactly one time-integrated interface exchange authority is used in both subdomain balances.

If the accepted lower saturated block retreats from `k:16` to `k+1:16`, ownership moves one face downward on the next accepted interval.

No fitted h, theta, saturated-count threshold or hysteresis is permitted. Saturation is the same physical constitutive condition used by the research state.

## Endpoint solve

Generalize the qualified NLGLOB14T coupled residual.

For each trial interval:

1. compute one constitutive state and one Darcy face-flux field from the trial heads;
2. compute the moving-interface face once;
3. upper TG nodes use origin/endpoint trapezoidal physical storage balance;
4. lower saturated-owned nodes use endpoint/full-Richards storage balance;
5. the interface node equations share one time-integrated interface flux;
6. top and bottom flux forcing remain the accepted-origin dry forcing for this bounded workunit.

A converged candidate is accepted only if all transaction, mass and domain gates pass.

## Transaction semantics

For every interval:

- accepted state is immutable until candidate acceptance;
- rejected candidate state is discarded;
- retry/timestep tuning is not introduced in this workunit;
- if a candidate fails, record exact rollback to the last accepted split state and stop that fixture;
- accepted accounting advances only with an accepted candidate.

## Frozen chatter definition

Under the unchanged dry forcing, physical retreat is expected to be monotone.

Classify `INTERFACE_CHATTER` if after a previously accepted retreat the saturated-block top moves upward again, or if ownership alternates between two faces.

A saturated set that ceases to be a single contiguous lower block classifies `NONCONTIGUOUS_SATURATED_SET`.

## Frozen gates

A fixture qualifies multi-interval moving-interface accepted evolution if all executed split intervals satisfy:

1. finite converged endpoint;
2. max node residual <= 1e-10;
3. physical mass ledger <= 5e-8 cm per interval;
4. cumulative physical mass ledger <= 5e-8 cm over the bounded split sequence;
5. exact single-interface cancellation <= 1e-12 cm;
6. accepted state changes only after passing gates;
7. any failed candidate rolls back exactly;
8. upper TG-owned nodes remain unsaturated at acceptance, except a genuine ownership-boundary event handled by recomputing the accepted saturated set;
9. saturated set remains a contiguous lower block while split ownership is active;
10. interface motion is monotone under dry forcing;
11. no independent interface fitting, threshold or residual redistribution is used.

A fixture may also finish positively if the saturated block disappears. In that case record `WHOLE_COLUMN_TG_ELIGIBLE_AFTER_SATURATED_BLOCK_DISAPPEARANCE`, but do not actually switch to production whole-column TG in this workunit.

## Required diagnostics

Record per fixture:

- accepted split interval count;
- final accepted time;
- every interface face;
- every saturated-block top node;
- interface transition count and transition steps;
- minimum and maximum saturated-node count;
- chatter count;
- noncontiguous-set count;
- upper-domain saturation events;
- lower-block retreat events;
- per-interval and cumulative mass ledgers;
- max residual;
- rollback differences for any rejected trial;
- nonlinear work count;
- matched-time differences against persistent-KLAG control where a control state exists;
- whether the saturated block disappears.

## Frozen aggregate classifications

Positive:

`QUALIFIED_MOVING_INTERFACE_ACCEPTED_STATE_EVOLUTION_RESEARCH`

if all 12 fixtures complete the bounded sequence without chatter, transaction leakage, interface inconsistency, domain failure or mass failure.

If the interface itself cannot remain single-valued:

`NLGLOB14U_INTERFACE_COUPLING_NOT_PERSISTENT`.

If saturated-block treatment cannot sustain accepted evolution:

`NLGLOB14U_SATURATED_BLOCK_EVOLUTION_NOT_PERSISTENT`.

If upper TG ownership becomes inadmissible:

`NLGLOB14U_UPPER_TG_OWNERSHIP_NOT_PERSISTENT`.

If accepted-state, rollback or accounting semantics fail:

`NLGLOB14U_TRANSACTION_INCONSISTENT`.

If interface reverses/oscillates:

`NLGLOB14U_INTERFACE_CHATTER`.

If the physical saturated set becomes noncontiguous:

`NLGLOB14U_NONCONTIGUOUS_SATURATED_SET`.

Otherwise:

`NLGLOB14U_MIXED_MOVING_INTERFACE_RESULT`.

## Interpretation boundary

A positive NLGLOB14U result is still research-only.

It would qualify bounded multi-interval accepted split evolution and ownership-face motion, not production admission.

A later successor would still be required for:

- broader materials/forcing;
- timestep-controller integration;
- event treatment exactly at ownership changes;
- transition to whole-column TG after complete desaturation;
- production architecture and independent qualification.

## Stop rules

Do not:

- return to first-retreat whole-column TG;
- fit release thresholds;
- introduce hysteresis;
- tune MAXIT/BALTOL or forcing;
- freeze lower heads;
- fit interface heads or separate interface fluxes;
- redistribute residual mass;
- modify production `src/**`.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14U

BASELINE: `9d529e71cb02283f3599d3203a51d38e88cf7347`

BRANCH: `research/f-pe-nlglob14u-moving-interface-accepted-state`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: generalize the NLGLOB14T split residual to a moving interface, accept qualified endpoints into private research state, and run the bounded 12-case sequence.

## Production boundary

Research only. No production source or numerical default is changed. `LEGACY_NUMERICS` remains production default.
