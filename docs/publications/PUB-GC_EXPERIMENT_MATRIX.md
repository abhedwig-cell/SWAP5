# PUB-GC publication experiment matrix

Status: **prospective experiment design**

Publication owner: `PUB-GC`

Doctoral mapping: `RQ3 / COUPLE`

Primary purpose: convert the existing Groundwater Coupling v1 capability into publication-grade evidence about **finite-window, same-origin, conservative coupling**.

This matrix is subordinate to `PUB-GC_SCIENTIFIC_CONTRACT.md` and uses the manifest rules in `EXPERIMENT_MANIFEST.md`.

## 1. Experimental principle

The method must be tested on three distinct questions:

1. **semantic correctness**: do both subsystems exchange exactly the intended amount of water and publish only accepted state?
2. **numerical consistency**: does the coupled solution approach a stable numerical reference when coupling controls are refined?
3. **practical relevance**: are there scientifically relevant feedback regimes in which the proposed coupling semantics materially outperform looser alternatives?

A regional demonstration cannot substitute for these controlled tests.

## 2. Methods to compare

Use stable method identifiers.

### GC-M0 — loose sequential baseline

One-way/sequential exchange over each coupling window using the accepted start state and one subsystem update order, without same-window replay iteration.

Exact formulation must be frozen before use. This method is a comparator, not an intentionally broken strawman.

### GC-M1 — terminal-flux exchange comparator

Where scientifically implementable, use a terminal/instantaneous lower-boundary flux as the exchange surrogate for the window.

Purpose: isolate the scientific effect of whole-window integrated exchange.

Do not combine this comparator with unrelated changes in coupling order.

### GC-M2 — restricted replay predictor/corrector (`pc1`)

The currently admitted bounded SWAP5 route:

- predictor from accepted origin;
- discard/rollback predictor candidate;
- corrector from same accepted origin;
- whole-window exchange;
- governed head residual;
- atomic accepted-state publication.

### GC-M3 — converged replay-based fixed point

Repeated same-origin subsystem evaluation until a declared interface criterion is satisfied.

This method is a publication target, not assumed current production authority. It must be separately implemented/qualified before primary runs.

### GC-M4 — relaxed established-style iterative comparator

A literature-aligned relaxed head/flux iteration, such as a Zeng-style comparator, if it can be represented with equivalent subsystem semantics.

This comparator should be included only if the implementation is scientifically fair and not artificially disadvantaged.

Response/tangent acceleration is excluded from primary `PUB-GC` results and belongs to `PUB-RC`.

## 3. Controlled groundwater models

### GW-A — transparent conceptual reservoir

A minimal dynamic groundwater component with analytically transparent storage/head response.

Purpose:

- isolate coupling behaviour;
- make strict numerical reference construction cheap;
- allow deliberate control of feedback strength.

Suggested state equation form, without freezing exact parameters here:

```text
S_gw * A * dh/dt = external_source - vadose_exchange
```

The exact model and discretisation must be documented before experiments.

### GW-B — minimal MODFLOW 6 model

A small MODFLOW 6 configuration with:

- one or few groundwater cells;
- simple, auditable storage and boundary conditions;
- no unnecessary regional complexity;
- external control through a scientifically admitted SWAP5 gateway/backend.

Purpose: prove transfer from transparent test system to a real 3-D groundwater solver.

### GW-C — realistic demonstration case

A compact shallow-groundwater case with actual vadose-groundwater feedback.

Purpose: relevance, not method identification.

## 4. Factor families

### A. Coupling-window duration

Use a logarithmic or otherwise broad ladder, for example from very small reference-like windows to windows long enough to stress loose coupling.

Exact durations are case-specific and must be frozen before primary runs.

### B. Feedback strength

Construct at least three regimes:

- weak feedback;
- intermediate feedback;
- strong feedback.

For GW-A this can be controlled directly through groundwater storage and depth parameters.

For GW-B/C use physical case parameters rather than artificial numerical scaling where feasible.

### C. Hydrologic forcing regime

At minimum:

- recharge/wetting pulse;
- drying/evapotranspiration period;
- capillary-rise dominated interval;
- forcing reversal or transition.

### D. Vadose-zone hydraulic response

Use contrasting soil profiles/materials spanning:

- relatively fast response;
- slower/high-storage response;
- strongly nonlinear near-water-table response.

Exact selections should be documented and preferably reuse already qualified SWAP material authorities.

### E. Groundwater depth

At least:

- deep enough for weak coupling;
- intermediate;
- shallow enough for strong bidirectional feedback.

## 5. Core experiment families

### GC-E0 — Interface semantics and atomic conservation

Hypotheses: H1, H2.

System: qualified SWAP + controlled groundwater service/fixture.

Purpose: establish the exchange contract before temporal/coupling accuracy analysis.

Cases:

- positive recharge;
- capillary rise;
- zero exchange;
- rejected SWAP candidate;
- rejected groundwater candidate;
- stale/mismatched lineage/revision where applicable.

Primary metrics:

- SWAP outward integrated exchange;
- groundwater outward integrated exchange;
- action/reaction residual;
- committed exchange before/after rejection;
- accepted lineage/revision.

Primary result:

```text
Q_swap_committed + Q_groundwater_committed = 0
```

within the declared arithmetic tolerance for every accepted window, while rejected trials produce no committed interface transfer.

Candidate manuscript artifact:

- `PUB-GC-T01`: interface semantics and conservation invariants.

### GC-E1 — Same-origin replay versus candidate-history contamination

Hypothesis: H1.

System: SWAP + GW-A.

Purpose: directly demonstrate why replay from one accepted origin matters.

Compare:

- `GC-M2`/`GC-M3` same-origin replay;
- an explicitly labelled diagnostic history-contaminated variant in which candidate `k+1` starts from candidate `k` rather than the accepted origin.

The contaminated variant is a diagnostic experiment only, not a recommended production method.

Design:

- choose at least one transient case where interface candidates materially differ;
- execute candidate heads in at least two different orders;
- repeat identical candidates from identical origins.

Primary metrics:

- returned whole-window exchange for identical interface candidate;
- endpoint SWAP state;
- order dependence;
- coupled fixed-point residual.

Expected discriminant:

- same-origin evaluation produces candidate response independent of candidate-evaluation history;
- continuation-from-candidate evaluation may produce path-dependent responses because it no longer represents the same subsystem operator.

Candidate figure:

- `PUB-GC-F01`: candidate response versus iteration/history.

If no meaningful distinction can be demonstrated even in deliberately strong transient cases, narrow the associated novelty claim.

### GC-E2 — Whole-window exchange versus terminal-flux surrogate

Hypothesis: H2.

System: SWAP + GW-A first, later selected GW-B cases.

Compare:

- `GC-M2` whole-window integrated exchange;
- `GC-M1` terminal-flux-based exchange with all other semantics matched as closely as possible.

Stress cases:

- sharp recharge pulse within a coupling window;
- capillary-rise transition;
- forcing reversal;
- long coupling window relative to vadose response time.

Primary metrics:

- cumulative interface-transfer error versus `GC-REF`;
- groundwater-head error;
- coupled mass residual;
- sensitivity to sampling location/time of terminal flux.

Candidate figure:

- `PUB-GC-F02`: whole-window versus terminal-flux exchange error across window duration.

### GC-E3 — Coupling-window convergence

Hypothesis: H3.

System: SWAP + GW-A, then a reduced subset with GW-B.

Methods:

- GC-M0;
- GC-M2;
- GC-M3 when qualified;
- GC-M4 where fair.

Reference: `GC-REF`.

`GC-REF` is constructed by:

- very small coupling windows;
- strict outer convergence;
- independently qualified subsystem solvers;
- one additional refinement demonstrating stability.

Primary metrics:

- max/terminal groundwater-head error;
- time-integrated or cumulative interface-exchange error;
- selected SWAP state/profile error;
- combined mass residual;
- failed/retried windows.

Independent variable:

- coupling-window duration.

Stratification:

- weak/intermediate/strong feedback;
- wetting/drying/capillary cases.

Candidate figure:

- `PUB-GC-F03`: error versus coupling-window duration by coupling method and feedback regime.

### GC-E4 — Method domain and robustness

Hypothesis: H4.

Purpose: identify when loose/restricted coupling ceases to be adequate.

For selected feedback regimes, increase coupling-window duration until methods show one of:

- convergence failure;
- repeated window reduction;
- materially excessive head error;
- materially excessive exchange error.

Primary outputs:

- largest tested window meeting declared accuracy criteria;
- retry/window-reduction count;
- number of subsystem evaluations;
- failure classification.

Do not define `pc1 sufficient` solely from convergence. It must also satisfy declared accuracy criteria versus `GC-REF`.

Candidate figure/table:

- `PUB-GC-T02`: measured validity/robustness domain by method.

### GC-E5 — Minimal MODFLOW 6 transfer experiment

Hypotheses: H2, H3, H4.

System: SWAP + GW-B.

Purpose: show that the controlled findings survive integration with a real MODFLOW 6 groundwater solver.

Use a deliberately small geometry so `GC-REF` remains affordable.

Required cases:

- recharge-dominated;
- capillary-feedback case;
- at least two coupling-window durations;
- at least GC-M0 and GC-M2, plus GC-M3 if admitted.

Primary metrics:

- groundwater head;
- whole-window exchange;
- head residual per coupling iteration;
- coupled mass residual;
- SWAP and MODFLOW trial counts;
- retries/window reductions.

Runtime is descriptive only in `PUB-GC`.

Candidate figure:

- `PUB-GC-F04`: MODFLOW 6 head/exchange trajectory versus numerical reference.

### GC-E6 — Bounded N:1 conservation

Hypotheses: H2 only within `PUB-GC`.

System: multiple SWAP columns mapped to one groundwater cell.

Purpose: verify conservative aggregation and transaction isolation, not hydrologic upscaling benefit.

Use at least:

- two contrasting columns;
- unequal area fractions;
- both recharge and capillary exchange cases;
- caller-order permutation.

Primary relation:

```text
V_groundwater = sum_i A_i Q_i
```

Primary metrics:

- aggregated transfer residual;
- per-column ledger closure;
- caller-order sensitivity;
- transaction failure atomicity.

Candidate artifact:

- `PUB-GC-T03`: bounded N:1 conservation demonstration.

Any result about whether the heterogeneous columns are hydrologically necessary belongs to `PUB-SG`.

### GC-E7 — Realistic demonstration

System: GW-C.

Status: later-stage supporting experiment.

Purpose: demonstrate scientific relevance after the controlled method evidence exists.

Selection criteria should favor:

- shallow groundwater;
- measurable or interpretable two-way feedback;
- heterogeneity sufficient to stress coupling but not so much that method interpretation disappears;
- manageable computational size.

Do not use this experiment to rescue a method that fails GC-E1 to GC-E5.

## 6. Primary versus supporting matrix

### Phase A — reference and comparator construction

- define/freeze GW-A;
- define GC-M0/GC-M1 fairly;
- implement/qualify GC-M3 if in scope;
- establish `GC-REF` construction procedure;
- run exploratory sweeps to locate weak/strong feedback regimes.

Evidence class: mainly `SHARED_INFRASTRUCTURE` and `PROSPECTIVE_SUPPORTING`.

### Phase B — frozen primary matrix

Before running, freeze a stratified subset covering:

- three feedback regimes;
- at least three coupling-window durations plus reference;
- recharge and capillary/drying dynamics;
- at least two contrasting SWAP hydraulic responses;
- the declared comparator methods.

Evidence class: `PROSPECTIVE_PRIMARY`.

### Phase C — MODFLOW transfer

Freeze a smaller matrix selected by predeclared rules from Phase B, including at least one easy and one difficult case.

Evidence class: `PROSPECTIVE_PRIMARY` for the transfer claim, not for re-estimating all controlled method effects.

## 7. Accuracy criteria

The publication needs predeclared tolerances for:

- groundwater-head error;
- cumulative exchange error;
- optional SWAP profile/state error;
- conservation residual.

These thresholds should be scientifically motivated and fixed before the primary matrix.

Do not use the coupling tolerance itself as the only accuracy criterion. A small interface residual does not prove proximity to the numerical reference.

## 8. Required raw telemetry

In addition to the common manifest:

- SWAP accepted-origin lineage/revision;
- groundwater accepted-origin lineage/revision;
- interface candidate index;
- prescribed SWAP interface head;
- whole-window SWAP exchange;
- groundwater candidate head;
- groundwater exchange;
- head residual;
- exchange/mass residual;
- coupling method identity;
- relaxation factor if applicable;
- accepted/rejected status;
- rejection reason;
- requested window reduction;
- SWAP internal accepted/rejected time steps;
- groundwater nonlinear/linear iterations;
- subsystem CPU time and total wall time;
- N:1 tile IDs/areas where relevant.

## 9. Predeclared null or unfavorable outcomes

Scientifically meaningful possible outcomes include:

- same-origin replay is conceptually clean but numerically indistinguishable in all practical regimes;
- whole-window exchange differs from terminal flux only for unrealistically large windows;
- restricted `pc1` is sufficient almost everywhere;
- full replay iteration is needed only in shallow/high-feedback states;
- an established relaxed comparator performs equivalently to the proposed method;
- coupled convergence is dominated by subsystem temporal error rather than outer coupling method.

These outcomes must be reported rather than filtered out.

## 10. Manuscript artifact plan

Candidate primary artifacts:

- `PUB-GC-T01`: interface semantics/conservation;
- `PUB-GC-F01`: same-origin versus history-contaminated response;
- `PUB-GC-F02`: whole-window versus terminal-flux exchange;
- `PUB-GC-F03`: coupling-window convergence curves;
- `PUB-GC-T02`: robustness/validity domain;
- `PUB-GC-F04`: minimal MODFLOW 6 transfer case;
- `PUB-GC-T03`: bounded N:1 conservation.

The final manuscript should probably use fewer, stronger artifacts. Primary ownership remains `PUB-GC`.

## 11. Go/no-go after controlled primary experiments

Continue toward a standalone `PUB-GC` methods paper only if the controlled experiments establish at least one nontrivial methodological consequence of the proposed formulation, for example:

- same-origin replay measurably prevents candidate-history contamination;
- whole-window exchange materially improves temporal/interface consistency;
- the method permits larger coupling windows at comparable error;
- restricted predictor/corrector has a clearly measurable validity domain;
- the coupled solution demonstrates systematic convergence to a declared numerical reference.

If none of these are found and the method is numerically indistinguishable from established coupling practice, narrow or merge the paper rather than relying on implementation novelty.
