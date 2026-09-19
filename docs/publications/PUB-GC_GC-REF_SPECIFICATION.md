# PUB-GC GC-REF numerical-reference specification

Status: **frozen construction rule before implementation and before any E2/E3 primary reference run**

Publication owner: `PUB-GC`

Applies first to: `SWAP + GW-A`

Future extension: a separately qualified `GC-REF-B` may apply the same principles to a minimal MODFLOW 6 backend after that backend is scientifically admitted.

Purpose: define a numerical reference for finite-window vadose-groundwater coupling that is independent of the production comparator methods being evaluated.

This specification creates no H2 or H3 result.

## 1. Reference object

For accepted SWAP state `X_n`, accepted groundwater state `G_n`, forcing `F_n` and coupling window

```text
I_n = [t_n,t_{n+1}]
```

define the same-origin SWAP window response

```text
S_n(h) -> (Q(h), X_candidate(h))
```

where every evaluation starts from the same accepted `X_n` and uses the same forcing and window.

For GW-A define

```text
M_n(Q) -> (h_gw(Q), G_candidate(Q))
```

from the same accepted `G_n`.

The scalar coupled residual is

```text
R_n(h) = h - h_gw(Q(h))
```

with all datum, sign and unit conversions governed by the already qualified coupling contracts.

A converged reference window satisfies the frozen interface residual criteria and is published only after the final accepted candidate pair has been reconstructed from the unchanged accepted origins.

## 2. Stable method identifier

The controlled GW-A reference method is:

```text
GC-REF-A
```

It is a research numerical oracle, not a production coupling method.

`GC-REF-A` uses:

- real qualified SWAP prescribed-head execution;
- same-origin replay for every residual evaluation;
- authoritative whole-window SWAP exchange `Q_whole`;
- qualified GW-A from one accepted groundwater checkpoint;
- a derivative-free bracketed scalar root solve;
- accepted-state advancement only after window convergence;
- coupling-window refinement across the full simulated trajectory.

Response/tangent information is forbidden in `GC-REF-A`; those methods belong to `PUB-RC`.

## 3. Derivative-free outer root solve

### 3.1 Frozen bracket

Each reference case manifest must freeze a physically defensible head bracket

```text
[h_lo, h_hi]
```

before the reference run.

The first two residual evaluations must establish either:

```text
R(h_lo) = 0
R(h_hi) = 0
```

or

```text
R(h_lo) * R(h_hi) < 0
```

within the declared arithmetic-zero rule.

If the frozen bracket does not contain a root, the reference attempt fails closed. The primary case may not silently enlarge or move the bracket after observing the failed result.

A new bracket requires a new manifest or a separately labelled screening/reference-construction run.

### 3.2 Bisection oracle

For qualification and primary reference construction use deterministic bisection.

For every midpoint `h_mid`:

1. evaluate SWAP from the unchanged accepted SWAP origin;
2. obtain `Q_whole(h_mid)`;
3. evaluate GW-A from the unchanged accepted GW-A origin using exact action/reaction;
4. compute `R(h_mid)`;
5. discard both candidates;
6. update only the research root bracket, never the accepted physical state.

The root solver contains no secant, Newton, tangent, Broyden, Aitken or response-derived acceleration.

### 3.3 Window convergence

A coupling window is reference-converged only when all frozen criteria are satisfied.

At minimum the manifest must freeze:

- head residual tolerance `tau_R_h_m`;
- final bracket-width tolerance `tau_bracket_h_m`;
- exchange-bracket tolerance `tau_Q_cm` based on the two retained bracket responses;
- maximum outer evaluations.

The final root estimate must satisfy both the residual and bracket criteria. Reaching the iteration limit is a reference failure, not permission to accept the best-so-far candidate.

Mass/action-reaction closure remains an independent invariant and cannot be traded against head convergence.

## 4. Reconstruction before accepted-state advancement

Residual-search candidates are diagnostic and discarded.

After the root is accepted:

1. retain the accepted root head `h_star`;
2. rerun SWAP once from the original accepted SWAP checkpoint at exactly `h_star`;
3. obtain the authoritative whole-window exchange and physical endpoint state;
4. rerun GW-A once from the original accepted groundwater checkpoint using exactly the paired exchange;
5. require the reconstructed residual and all acceptance checks to satisfy the frozen criteria;
6. only then advance the research accepted state for both subsystems to `t_{n+1}`.

The reconstructed accepted pair, not an arbitrary bisection candidate object, becomes the origin for the next coupling window.

If reconstruction changes the residual beyond tolerance, the window fails closed.

## 5. Whole-trajectory reference refinement

A single tightly converged coupling window is not sufficient to define the paper reference.

For every primary reference case, freeze a coupling-window ladder with at least three nested levels:

```text
L0: DeltaT
L1: DeltaT / 2
L2: DeltaT / 4
```

or a stricter predeclared nested sequence.

All levels cover exactly the same physical start/end interval and forcing chronology.

Each level independently uses the strict root criteria in Section 3.

The candidate numerical reference is the finest completed level, normally `L2`.

No Richardson extrapolation or fitted asymptotic correction is permitted unless introduced by a later separately frozen reference specification.

## 6. Reference stability adjudication

The finest trajectory becomes `GC-REF-A` evidence only if the last refinement step is stable according to predeclared tolerances.

At minimum compare `L1` versus `L2` for:

- maximum and terminal groundwater-head difference;
- cumulative whole-window interface exchange difference;
- selected SWAP endpoint state/profile norm;
- total SWAP water-storage difference;
- combined interface/mass residual diagnostics.

The case manifest must freeze numerical stability tolerances before execution.

Where primary publication accuracy thresholds already exist, reference stability thresholds must be materially tighter. Default design rule:

```text
reference stability tolerance <= 0.1 * smallest corresponding primary accuracy tolerance
```

unless a stricter case-specific rule is preregistered.

If the last refinement is not stable, `L2` is not called the numerical reference. Additional refinement requires a new, prospectively recorded reference-construction step.

## 7. Independence from methods under test

`GC-REF-A` must not be defined by agreement with `GC-M0`, `GC-M1`, `GC-M2` or any future `GC-M3`.

In particular:

- `GC-M2/pc1` cannot serve as its own reference;
- terminal flux cannot define reference exchange;
- production convergence flags cannot substitute for the reference residual oracle;
- agreement between two tested methods is not reference convergence;
- response/tangent acceleration cannot define the reference root;
- a small interface residual alone is insufficient without temporal refinement.

The reference may use the same independently qualified subsystem physics because the scientific question concerns coupling semantics, not replacing subsystem equations.

## 8. Qualification requirements before primary use

A research-only `GC-REF-A` implementation must be qualified before any E2/E3 primary run.

Minimum qualification:

1. analytic synthetic residual with known root is recovered within frozen tolerance;
2. bracket with no sign change fails closed;
3. repeated residual evaluation at the same head from the same origins is identical;
4. search candidates do not mutate accepted SWAP or GW-A state;
5. accepted reconstruction is executed from the original window origins;
6. reconstructed result satisfies the same convergence criteria as the root search;
7. whole-window exchange is used, never terminal-flux surrogate;
8. action/reaction closes for the reconstructed accepted pair;
9. three-level trajectory refinement bookkeeping is deterministic;
10. an intentionally under-refined trajectory is rejected by the stability adjudicator;
11. O0/O2 scientific-oracle output is identical where exact identity is supported;
12. production `src/**`, qualified GW-A, E1 harness/engine and E2 comparator bytes remain unchanged.

Qualification proves the reference machinery, not H2/H3.

## 9. Publication use

### PUB-GC-E2

After comparator qualification and `GC-REF-A` qualification, E2 may compare whole-window and terminal-flux exchange against the same reference trajectory.

The terminal arm remains a comparator only. It does not alter the reference.

### PUB-GC-E3

E3 varies production/test coupling-window duration and evaluates convergence toward `GC-REF-A`.

The primary E3 inference is about observed convergence with coupling-window refinement, not about the internal efficiency of the bisection oracle.

### PUB-RC firewall

The number of reference residual evaluations may be reported as provenance/cost context, but no solver-acceleration conclusion is owned by PUB-GC.

Any derivative-assisted reduction in coupling evaluations belongs to `PUB-RC`.

## 10. Reference telemetry

Persist per residual evaluation:

```text
reference_id
case_id
trajectory_level
window_index
window_t0
window_t1
origin_SWAP_lineage_revision
origin_GW_lineage_revision
outer_evaluation_index
h_candidate_m
R_h_m
Q_whole_cm
GW_candidate_head_m
bracket_lo_m
bracket_hi_m
candidate_disposition
SWAP_endpoint_digest
SWAP_mass_residual
```

Persist per accepted reference window:

```text
h_star_m
reconstructed_R_h_m
accepted_Q_whole_cm
accepted_SWAP_endpoint_digest
accepted_GW_head_m
outer_evaluations
action_reaction_residual
```

Persist per trajectory level:

```text
DeltaT
number_of_windows
cumulative_Q_whole
terminal_GW_head
max_GW_head
selected_SWAP_state_metrics
combined_mass_diagnostics
runtime_context
```

## 11. Failure classifications

Use explicit failure classes:

- `REF_BRACKET_INVALID`;
- `REF_OUTER_NOT_CONVERGED`;
- `REF_RECONSTRUCTION_MISMATCH`;
- `REF_SUBSYSTEM_TRIAL_FAILED`;
- `REF_MASS_INVARIANT_FAILED`;
- `REF_TEMPORAL_REFINEMENT_UNSTABLE`;
- `REF_AUTHORITY_DRIFT`.

A failed reference case is not silently dropped from a frozen primary matrix.

## 12. Explicit nonclaims

This specification does not establish:

- H2 or H3;
- that bisection is an efficient production coupling algorithm;
- practical coupling-window limits;
- MODFLOW 6 transferability;
- that the finest currently affordable trajectory equals physical truth;
- general superiority of whole-window exchange;
- response/tangent acceleration performance.

The reference is a demonstrably refined numerical comparator, not truth.

## 13. Next permitted action

1. implement `GC-REF-A` only in research/publication paths;
2. preregister and run its qualification suite;
3. persist an immutable qualification receipt;
4. define publication accuracy thresholds and the first screening/reference cases;
5. freeze E2/E3 primary matrices only after the qualified reference machinery and case-specific reference stability criteria exist.
