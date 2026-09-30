# PPA-WU05-A3 preregistration — macropore physical decomposition and corrected reference model

Date: 2026-09-30

Status: `PREREGISTERED / RESEARCH_ONLY / HELD_ON_A2_QUALIFICATION`

Baseline: `PPA-WU05-A2@4d297b72e41089321572ce15ad078bf65cf398ee`

Canonical reconciled through: `integration/f-ci-canonical@f9133b92cd7d128838029a162ee607bb8ba69689`

## Purpose

Begin the scientific macropore research phase only after source authority, state ownership, rollback semantics and restart boundaries have been made explicit.

A3 is not a blind SWAP 4.3.1 port. It decomposes the B1.11 macropore equations into physically interpretable process contracts, separates documented reference behaviour from undefined legacy behaviour, and builds a minimal corrected reference model suitable for falsification.

A3 must not enter production admission before A2 is qualified.

## Upstream authority

PPA-WU05-A1 established exact B1.11 source authority and proved:

- seven physical/history continuation fields;
- incomplete legacy rollback;
- internal matrix/macropore exchange ownership;
- rapid drainage external ownership;
- the B1.11 `icgwl` undefined-index defect in `MACROSTATE`.

PPA-WU05-A2 is establishing typed committed/candidate/restart ownership for those seven fields.

A3 inherits those findings and does not reopen them unless contradictory source-bound evidence appears.

## Research principle

A3 follows:

`explain -> reproduce -> correct -> falsify -> only then migrate`

Legacy behaviour is not automatically correct merely because it is historical. Conversely, a difference from legacy is not accepted as an improvement without a physically explicit reason and evidence.

## Process decomposition

The B1.11 macropore system shall be decomposed into explicit process blocks:

1. surface-to-macropore vertical inflow;
2. lateral/ponding inflow into macropores;
3. static macropore storage geometry;
4. dynamic crack-volume geometry;
5. vertical redistribution within macropore domains;
6. saturated matrix/macropore exchange;
7. unsaturated matrix absorption/sorptivity exchange;
8. internal catchment-domain exchange;
9. rapid drainage;
10. accepted storage update and history update.

For each process block A3 shall record:

- inputs;
- immutable parameters;
- committed history dependencies;
- candidate-mutated history;
- output rates/state;
- sign convention;
- mass owner;
- event/time-step dependency;
- exact B1.11 source locator;
- whether behaviour is scientifically defined, implementation-dependent, or undefined.

## Corrected-reference policy

A3 shall maintain three conceptual reference levels:

### R0 — exact B1.11 where defined

Exact legacy equations and state semantics, excluding execution paths whose output depends on undefined behaviour.

### R1 — minimally corrected B1.11

R0 plus only source-proven corrections required to make the physical calculation deterministic and well-defined.

The first known R1 correction candidate is the `icgwl` defect. A3 must derive the physically intended saturated/unsaturated partition index from source context and test alternatives. It may not silently choose an index.

### R2 — decomposed SWAP5 research formulation

A structurally clearer formulation with explicit state and mass ownership. R2 may be algebraically reorganized but must initially preserve R1 process semantics unless a separately preregistered hypothesis is being tested.

## Core hypotheses

### H1 — seven-field state sufficiency

The seven A1 continuation fields are sufficient physical/history state for deterministic macropore continuation when all other geometry/rate quantities are recomputed from current hydraulic state and immutable parameters.

Falsification: a future process output depends on an additional prior-call quantity not reproducible from the seven fields plus current state/configuration.

### H2 — derived geometry can be recomputed

`VlMp`, `VlMpDm`, `ZBtDm`, `ZWaLevDm`, `ICpTpWaSrDm`, `FrMpWalWet`, `ArMpTp`, `ArMpTpDm` and related views need not be persistent continuation state.

Falsification: recomputation from identical committed state changes a subsequent physical result.

### H3 — matrix/macropore exchange is internally conservative

Gross exchange terms cancel exactly or to roundoff in whole-column accepted mass when booked once on each side.

Falsification: whole-column storage/flux closure requires an unexplained residual exchange source/sink.

### H4 — rejected trials leave no macropore memory

With A2 ownership, an intentionally rejected trial followed by retry from the same accepted state produces identical macropore state/rates to a clean run from that state.

### H5 — dynamic crack-volume history is materially active only in identifiable regimes

`VlMpDyCp` should materially affect response only when shrinkage/crack activation conditions are active. Outside those regimes, perturbing its accepted history within a physically bounded range should not materially alter flow.

### H6 — sorptivity history creates measurable event memory

`SorpDmCp`, `ThtSrpRefDmCp`, and `TimAbsCumDmCp` produce a distinguishable response between otherwise identical wetting events with different antecedent event histories.

### H7 — deterministic correction of `icgwl` is locally bounded

A physically justified R1 replacement for the undefined `icgwl` path should remove bounds/undefined behaviour without creating discontinuous whole-column mass or grossly changing unaffected regimes.

## Minimal experiment matrix

A3 starts with controlled single-column experiments before full realistic cases.

### E0 — macropores disabled

Purpose: negative control.

Requirement: R1/R2 macropore contribution exactly zero and no macropore state mutation.

### E1 — direct surface bypass pulse

Dry profile, short intense top input, matrix absorption deliberately weak.

Observe:

- partition into macropores;
- vertical domain flux;
- macropore storage;
- arrival at rapid-drain/bottom pathway;
- matrix exchange.

### E2 — matrix absorption dominated

Macropores receive water but drainage route is suppressed/weak and matrix is strongly absorptive.

Observe sorptivity-rate evolution and whole-column internal-exchange cancellation.

### E3 — antecedent-history pair

Two cases with identical current hydraulic state and forcing but distinct admissible sorptivity-history states.

Purpose: quantify true event memory.

### E4 — crack opening/closing pair

Two antecedent shrinkage histories with identical current forcing.

Purpose: isolate `VlMpDyCp` hysteretic effect.

### E5 — rapid drainage activation

Construct conditions that cross rapid-drain activation threshold.

Observe onset continuity, sign, ownership and storage response.

### E6 — near-saturated profile

Stress saturated/unsaturated interface partition and the corrected `icgwl` logic.

This is the primary source-bound defect characterization experiment.

### E7 — groundwater-interface sweep

Move groundwater level through the macropore-active depth while holding other inputs fixed.

Purpose: test continuity of exchange/storage transitions.

### E8 — reject/retry experiment

Run an event that mutates all seven continuation fields, reject deliberately, retry from accepted state, and compare against a clean one-attempt execution.

Required equality: exact state identity where deterministic arithmetic permits, otherwise preregistered roundoff-only tolerance for derived rates.

### E9 — extreme rainfall stress

Large but physically plausible precipitation intensity.

Purpose: expose sign, storage, activation, and timestep pathologies without using it as a calibration target.

## Primary observables

Every active experiment shall record at minimum:

- all seven continuation fields before/after accepted step;
- macropore storage by domain and total;
- `QInTopVrtDm`;
- `QInTopLatDm`;
- each gross matrix/macropore exchange component;
- signed `QExcMtxDmCp`;
- `QExcMpMtx`;
- `QMaPo`;
- `QOutDrRapCp`;
- `QRapDra`;
- matrix storage change;
- whole-column storage change;
- top and bottom external receipts;
- accepted/rejected status;
- timestep and nonlinear iteration count when coupled execution is later enabled.

## Mass checks

For each accepted experiment:

1. gross internal exchange must cancel in whole-column mass;
2. `QMaPo` must never be counted as an additional external flux;
3. top macropore inflow must be a partition of the top-boundary receipt, not an extra source;
4. rapid drainage must appear exactly once as external outflow;
5. rejected attempts publish no accepted flux receipt or continuation state;
6. unexplained residuals are failures, not tolerances to be widened.

## `icgwl` adjudication

A3 shall reconstruct the intended meaning of `icgwl` from:

- surrounding `MACROSTATE` source;
- `ICpTpWaSrDm` construction;
- domain geometry and water-level definitions;
- neighbouring saturated/unsaturated partition loops;
- historical documentation/comments if available;
- controlled E6/E7 behaviour.

Candidate interpretations must be enumerated before selecting one.

Selection criteria:

- physically interpretable;
- deterministic;
- index-valid;
- consistent with storage geometry;
- mass conservative;
- minimally disruptive outside the defect path.

No candidate wins merely by matching one legacy crash-free compiler realization.

## Comparison hierarchy

For each experiment report:

- R0 result where defined;
- R1 result;
- R2 result;
- absolute and relative flux/storage differences;
- state differences;
- conservation residual;
- event-memory differences;
- numerical effort if applicable.

R0 is omitted, not fabricated, where undefined behaviour controls the result.

## Numerical coupling boundary

A3 initially keeps Richards coupling observational/minimal.

The first research implementation may compute macropore candidate rates against prescribed matrix hydraulic states. Full coupled nonlinear integration belongs to the later transactional-integration slice unless required to falsify a specific A3 hypothesis.

This avoids conflating physical decomposition errors with solver/timestep interaction.

## No-calibration rule

A3 is not a parameter calibration study.

Parameters may be varied for controlled sensitivity experiments, but no parameter set may be tuned merely to make R2 match R0/R1. Calibration/identifiability is a later research question.

## Exit criteria

A3 may close as one of:

- `QUALIFIED_PHYSICAL_DECOMPOSITION_AND_CORRECTED_REFERENCE_READY`;
- `QUALIFIED_DECOMPOSITION_REFERENCE_DEFECT_REQUIRES_FOLLOWON`;
- `STATE_SURFACE_FALSIFIED_RETURN_TO_A2`;
- `MASS_OWNERSHIP_FALSIFIED_RETURN_TO_A1`;
- `REFERENCE_PHYSICS_UNDERDETERMINED`.

A3 does not itself admit active macropore production physics.

## Hold condition

Implementation beyond research scaffolding is held until PPA-WU05-A2 obtains a green current-head qualification gate.

## First executable step after A2 PASS

Build the E0–E2 research harness against prescribed matrix states and materialize an exact source-to-process map for surface input, absorption, storage and rapid drainage before implementing the corrected `icgwl` path.
