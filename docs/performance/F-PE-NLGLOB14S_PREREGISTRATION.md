# F-PE-NLGLOB14S preregistration — first-retreat split-domain temporal-ownership feasibility

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14N3: first-retreat event is temporally localized;
- NLGLOB14P: full-column TG predictor is locally admissible at the first-retreat origin;
- NLGLOB14Q: one full-column TG shadow interval is admissible;
- NLGLOB14R-R3: stable full-column TG continuation is not recovered under the bounded transaction retry policy;
- NLGLOB14R4: `NLGLOB14R4_INVALID_BRACKET_IS_ALREADY_SATURATED_OVERSHOOT`.

## Purpose

R4 falsifies first retreat as a stable full-column TG release rule because the lower saturated block remains physically present.

NLGLOB14S begins the alternative ownership route observationally.

It asks whether the qualified first-retreat state can be decomposed into two temporal domains with one conservative interface:

- unsaturated upper domain: nodes 1:3, candidate owner TG;
- saturated lower domain: nodes 4:16, candidate owner saturated treatment;
- interface: between nodes 3 and 4.

No split-domain solver is implemented in NLGLOB14S.

## Frozen fixtures

Use the same 12 six-level O05 first-retreat trajectories:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- first accepted 14 -> 13 retreat state;
- dry forcing;
- surface-flux route at the handoff state;
- NLGLOB14N3 saturation-entry retry semantics;
- persistent-KLAG control remains the accepted trajectory.

## Frozen partition

At `RETREAT_HANDOFF_ORIGIN` require:

- nodes 1:3 unsaturated under both existing indicators;
- nodes 4:16 saturated under both existing indicators;
- lower saturated set contiguous to node 16;
- state finite and mass-clean.

The partition is therefore fixed for this workunit:

- upper U = nodes 1:3;
- lower L = nodes 4:16.

Do not move the interface inside NLGLOB14S.

## Frozen interface flux

Compute the physical 3|4 interface flux from the same accepted state and constitutive provider using the existing SWAP sign convention and conductivity mean.

Call it:

`q_34`.

The same scalar `q_34` must be used:

- as the lower boundary flux of U;
- as the upper boundary flux of L.

No independently fitted or reconstructed interface flux is permitted.

## Upper-domain TG feasibility

Using:

- accepted top flux;
- internal fluxes 1|2 and 2|3;
- shared interface flux q_34;
- accepted provider capacity on nodes 1:3;

derive the physical upper-domain moisture derivative.

Form the ordinary head-space TG predictor on U only:

`h_dot = theta_dot / C`

`h_tilde = h + dt*h_dot`.

Upper-domain TG is observationally admissible only if for nodes 1:3:

- C finite and >0;
- theta_dot finite;
- h_dot finite;
- h_tilde finite;
- predicted conductivity finite and >0;
- predicted theta remains strictly below theta_s.

No lower saturated-node capacity participates in this upper TG probe.

## Lower-domain saturated ownership feasibility

For nodes 4:16 record:

- lower-block storage;
- shared top interface flux q_34;
- bottom flux;
- storage tendency implied by accepted control-state flux divergence;
- saturated-node contiguity;
- finite state.

Lower saturated ownership is observationally feasible only if:

- the lower block is contiguous and finite;
- q_34 is finite;
- bottom flux is finite;
- the lower-domain physical flux divergence is finite;
- no independent upper/lower interface-flux mismatch exists.

This does not qualify a standalone lower-block KLAG solve.

## Split mass identity

For the accepted state, compute separate instantaneous storage tendencies:

`dS_U/dt`

and

`dS_L/dt`.

Require the shared interface flux to cancel exactly in the combined balance so that:

`dS_U/dt + dS_L/dt`

matches the full-column physical storage tendency derived from top and bottom fluxes, within `1e-12 cm/d`.

Also require direct equality of the U-lower and L-upper interface-flux representation within `1e-15 cm/d`.

## Frozen classifications

### SPLIT_TEMPORAL_OWNERSHIP_OBSERVATIONALLY_FEASIBLE

Require all:

1. frozen 3|4 partition valid;
2. upper TG predictor admissible;
3. lower saturated ownership diagnostics valid;
4. one shared finite interface flux;
5. split instantaneous mass identity closes;
6. accepted control state remains finite and mass-clean.

### UPPER_TG_PARTITION_NOT_ADMISSIBLE

Classify if partition and lower block are valid but upper U fails the frozen TG predictor gate.

### LOWER_SATURATED_PARTITION_NOT_ADMISSIBLE

Classify if upper U is admissible but the lower block or shared interface diagnostics fail.

### SPLIT_INTERFACE_MASS_INCONSISTENT

Classify if interface cancellation or split/full tendency identity fails.

### SPLIT_PARTITION_STATE_INCONSISTENT

Classify if the frozen 3|4 partition itself is absent or saturation indicators disagree.

## Frozen aggregate interpretation

If 12/12 classify `SPLIT_TEMPORAL_OWNERSHIP_OBSERVATIONALLY_FEASIBLE`:

`NLGLOB14S_SPLIT_TEMPORAL_OWNERSHIP_FEASIBLE`.

If 12/12 fail on the same upper or lower mechanism, preserve that mechanism-specific aggregate conclusion.

If any interface/mass inconsistency occurs:

`NLGLOB14S_SPLIT_INTERFACE_MASS_INCONSISTENT`.

Otherwise:

`NLGLOB14S_MIXED_SPLIT_FEASIBILITY`.

## Consequence

A positive result may authorize a separately preregistered transactional split-domain shadow experiment.

That successor must still prove:

- an actual upper-domain TG solve can be composed without lower saturated capacities;
- lower saturated treatment can share the same interface flux;
- rejected split trials rollback exactly;
- moving-interface ownership can update only after accepted state changes.

NLGLOB14S itself does not implement or accept split temporal evolution.

## Stop rules

Do not:

- implement a split solver;
- move the 3|4 interface;
- change interface flux;
- change provider capacity;
- change retry scale/budget;
- change forcing, dt or first-retreat event;
- change mass gates;
- modify production source.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: observational diagnostics only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14S

BRANCH: `research/f-pe-nlglob14s-split-domain-feasibility`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: evaluate the frozen 3|4 partition, shared interface flux, upper-only TG predictor and split instantaneous mass identity on the 12 first-retreat origins.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
