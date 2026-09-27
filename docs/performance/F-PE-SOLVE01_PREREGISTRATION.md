# F-PE-SOLVE01 — bounded discarded-trial Richards solve elimination

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent:
`F-PE-PROFILE06 / PR #640`

Parent head at branch creation:
`1ad0958abbe3d5503069d431fe03b45fe824731f`

Branch:
`work/f-pe-solve01-discarded-trial-elimination`

## Strategic trigger

PROFILE06 established that the retained practical stack is already materially speed-positive on difficult Richards work, while the dominant remaining cost is the physical Reference Richards solve itself.

A1 already reuses most repeated tangent evaluations. A2C can reduce nonlinear/backtracking effort on difficult trajectories. Yet every same-origin corrector trial still executes a physical SWAP solve.

Therefore SOLVE01 does not target another tangent micro-optimization or another constitutive kernel refinement.

The workunit asks whether discarded coupling trials can avoid full Richards solves while preserving exact ownership at commit.

## Primary question

Can at least half of the full Richards solves used only to serve discarded same-origin coupling trials be eliminated, while retaining an exact final SWAP solve before any candidate state is committed?

This is an application-level performance question.

The workunit is deliberately not a production-admission study.

## Governing semantic split

SOLVE01 distinguishes two classes of information.

### Intermediate coupling response

A discarded corrector response may be approximate.

It is advisory information used only to steer the external groundwater corrector.

It must not:

- commit an approximate SWAP state;
- mutate accepted SWAP state;
- advance the mass ledger;
- change accepted-state storage;
- become an implicit substitute for final validation.

### Commit-worthy candidate

Before a coupling interval is committed, the selected final head must be evaluated by a real SWAP Richards solve from the captured origin.

Only that exact final candidate may:

- become accepted state;
- update storage;
- update the exchange ledger;
- participate in committed mass accounting.

Thus approximation is confined to discarded coupling trials, not to accepted model state.

## Baseline

The baseline is the current retained practical stack on the PROFILE06 lineage.

Use the production-shaped accepted-direction route and the already qualified practical mechanisms available on that lineage.

Do not compare against an obsolete historical Reference implementation in order to manufacture speedup.

Primary baseline behavior:

- every requested same-origin corrector receives a full Richards evaluation;
- current practical tangent reuse remains available where already qualified;
- current practical difficult-solve acceleration remains available where already qualified;
- final transaction/commit semantics remain unchanged.

## Frozen first experiment

Use the difficult production-shaped same-origin origins already qualified in PROFILE06 and the repeated corrector structures already used in the practical performance line.

Do not open a broad calibration program in P0.

P0 is a falsification experiment.

### Arm E0 — exact-every-trial

Every corrector executes a full Richards solve.

This is the baseline.

### Arm E2 — one skipped solve between exact refreshes

At most one intermediate corrector may be answered without a full Richards solve before a fresh exact response is required.

The final selected head always receives an exact validation solve.

### Arm E4 — up to three skipped solves between exact refreshes

Up to three intermediate correctors may be answered from the bounded local response before exact refresh.

The final selected head always receives an exact validation solve.

### Arm EH — bounded head-window refresh

A local response may be reused while the requested head remains within a preregistered displacement window around its exact anchor.

Crossing the window forces an exact refresh.

The final selected head always receives an exact validation solve.

### Arm EF — aggressive research-only final-validation arm

The first requested response is exact.

Intermediate discarded correctors may be served without new Richards solves.

The final selected head receives an exact validation solve.

EF exists to estimate the upper bound on solve-elimination benefit.

It is not a production candidate in SOLVE01.

## Response representation

P0 must start with the cheapest response representation already available from the exact anchor.

The first implementation choice should remain deliberately simple.

Allowed P0 representations:

1. existing local published linear response;
2. secant from two exact anchor responses where two anchors are available.

Do not introduce a learned surrogate, ROM, quadratic fit or multi-parameter calibrator in P0.

If simple local response cannot produce a useful solve-count reduction, SOLVE01 should close before opening a more elaborate representation line.

## Measurements

Per corrector sequence record at minimum:

- requested corrector count;
- exact Richards solve count;
- approximate intermediate response count;
- exact refresh count;
- exact final-validation solve count;
- temporal retries;
- solver retries;
- tangent fresh/reuse counts where applicable;
- total wall-clock;
- wall-clock per completed coupling interval;
- final selected head;
- final exact q;
- final exact candidate state diagnostics;
- integrated exchange;
- storage change;
- mass/ledger diagnostics.

Also record whether approximation changes the number of external corrector requests required to reach the selected endpoint.

## Primary performance metrics

Solve-count ratio:

`R_solve = N_Richards(candidate) / N_Richards(E0)`

Runtime ratio:

`R_time = T(candidate) / T(E0)`

Speedup:

`S = T(E0) / T(candidate)`

Do not infer end-to-end gain by adding microbenchmark percentages.

## Physical comparison

Intermediate approximate q values are not required to reproduce exact discarded-trial q values within a production-grade tolerance.

Those trials are not committed.

The authoritative comparison is at the exactly validated final candidate and over the completed coupling interval.

Record at minimum:

- final q difference;
- final storage/state difference;
- integrated groundwater exchange difference;
- mass-balance difference;
- change in selected coupled endpoint;
- change in external corrector count.

## P0 success gate

A candidate arm is worth further development only if, on the frozen difficult matrix:

1. full Richards solve count is reduced by at least 50% on the sequences where reuse is applicable;
2. median end-to-end wall-clock is reduced by at least 30% relative to E0;
3. every committed candidate comes from an exact final validation solve;
4. no approximate intermediate state is committed;
5. no mass/ledger ownership violation occurs;
6. exact final validation succeeds without systematic extra retry amplification;
7. external corrector count does not increase enough to erase the wall-clock gain.

These are research-advancement gates, not production-admission tolerances.

## Strong-signal criterion

A result is considered a strong performance signal if the same experiment shows approximately 2x or greater end-to-end speedup while final exact validation and ledger ownership remain intact.

This is not required for P0 continuation.

## Stop conditions

Close SOLVE01 without refinement if:

- the solve count cannot be reduced materially;
- 50% solve elimination yields less than 30% median end-to-end gain and the missing gain cannot be localized to a clear removable cost;
- approximation consistently causes enough extra external correctors to erase the saved solves;
- exact final validation frequently lands on a different physical branch or requires large recovery work;
- mass, state or ledger ownership cannot remain strictly exact at commit;
- only elaborate surrogate fitting appears capable of making P0 work.

In the last case, any surrogate research belongs in a separate workunit and must be justified by SOLVE01 evidence first.

## Explicit non-goals

SOLVE01 does not:

- repair TEMPORAL06 tangent semantics;
- admit c=0.65;
- redefine the MODFLOW-facing derivative;
- relax committed-state mass balance;
- modify Richards physics;
- replace exact final validation;
- optimize individual constitutive kernels;
- pursue another exact directional-cost micro-optimization.

Those questions remain separate.

## Relation to TEMPORAL06

TEMPORAL06 remains valid evidence that temporal policy can materially affect retry burden and repeated-sequence runtime.

Its tangent-authority failure blocks production admission of that temporal policy.

It does not block SOLVE01, because SOLVE01's first question is whether discarded coupling trials can avoid physical solves at all.

No TEMPORAL06 result may be silently reclassified as a pass inside SOLVE01.

## Decision rule after P0

If no arm passes the P0 success gate:

`CLOSE_SOLVE_ELIMINATION_NOT_YET_JUSTIFIED`

If at least one arm passes:

`ADVANCE_BOUNDED_SOLVE_ELIMINATION`

Only then may a successor refine:

- head-window size;
- age/refresh policy;
- secant versus tangent response;
- interaction with temporal policy;
- broader material/regime coverage;
- large-N MultiSWAP/MODFLOW scale behavior.

## Strategic hierarchy

For the practical MultiSWAP performance line, the intended optimization order is:

`remove full solves > make retained solves cheaper > micro-optimize kernels`

SOLVE01 exists to test the first term directly.
