# PUB-SQ publication experiment matrix

Status: **prospective experiment design**

Publication owner: `PUB-SQ`

Doctoral mapping: `RQ2 / REPLACE`

Primary purpose: convert the existing RossFast/reference implementation and qualification platform into publication-grade evidence about **scientifically admissible solver substitution**.

This matrix is subordinate to `PUB-SQ_SCIENTIFIC_CONTRACT.md` and uses the manifest rules in `EXPERIMENT_MANIFEST.md`.

## 1. Experimental principle

The central comparison is not:

```text
RossFast runtime versus Newton runtime
```

but:

```text
scientific error + model acceptance + robustness + computational cost
                         versus
                 state/regime/domain
```

A solver may be computationally fast yet scientifically inadmissible for a case. A solver may also be accurate but offer no practical computational advantage.

The primary output is therefore a **measured admissibility/performance surface**, not a universal winner.

## 2. Reference hierarchy

All experiments must distinguish:

- `REF-PROD`: the qualified production Reference Richards route;
- `REF-HIGH`: a stricter numerical reference constructed by timestep/refinement controls where feasible;
- `ROSS`: the qualified RossFast candidate route for the declared envelope.

`REF-PROD` is a model authority, not automatically numerical truth.

`REF-HIGH` must itself demonstrate refinement stability before being used as error denominator.

## 3. Factor families

The initial factor space is divided into five groups.

### A. Hydraulic state

Candidate levels, subject to exact admitted-envelope reconciliation:

- dry profile;
- intermediate profile;
- wet profile;
- profile close to steep hydraulic transition;
- state close to lower or upper RossFast head envelope.

Avoid inventing synthetic levels that are outside the actual admitted material/head contract merely to populate a balanced matrix.

### B. Soil/material response

Start with the six already qualified RossFast material identities:

- B01;
- B12;
- O01;
- O05;
- O14;
- O18.

These are the first controlled material axis. Broader material claims require separate scientific admission before inclusion.

### C. Forcing / boundary stress

Within the common admitted envelope:

- low-magnitude prescribed flux;
- moderate prescribed flux;
- high admissible prescribed flux;
- sign reversal where scientifically/contractually supported;
- abrupt forcing change across accepted steps.

Later expansion may include prescribed head, dynamic top boundary, roots/source-sinks or groundwater only after those RossFast domains are separately qualified.

### D. Duration / temporal demand

Use the admitted duration ladder first, supplemented by stricter reference subdivision.

For publication analysis classify cases by:

- short interval;
- medium interval;
- longest admitted interval;
- near temporal-certificate/acceptance boundary where available.

### E. Accuracy requirement

Define at least three application-relevant error classes after a separate tolerance rationale:

- strict;
- nominal;
- relaxed.

Do not invent these numeric thresholds inside this matrix. Their values must come from a documented accuracy authority or predeclared publication rationale.

## 4. Core experiment families

### SQ-E0 — Contract identity and fail-closed selection

Hypotheses: H2, H3.

Purpose: prove that the solver comparison takes place behind the same model-level contract and that solver identity cannot silently change.

Design:

- same accepted start state;
- same forcing and boundary request;
- explicit `REFERENCE_RICHARDS` versus explicit `ROSSFAST_D3R`;
- include supported Ross cases and deliberately unsupported Ross cases.

Primary metrics:

- candidate/accepted state lineage;
- solver identity provenance;
- accepted/rejected status;
- mass ledger;
- retry/rollback state identity;
- presence/absence of fallback.

Primary acceptance statement:

> explicit RossFast selection either returns a candidate under the admitted contract or fails closed before scientific publication; it does not silently become the Reference solver.

This family is primarily a methodological prerequisite and may become a table rather than a major results figure.

### SQ-E1 — Common-domain state/flux equivalence matrix

Hypothesis: H1.

Purpose: establish where both solvers produce model-relevant outcomes consistent with the same stricter numerical reference.

Initial matrix dimensions:

```text
material
x initial hydraulic state
x forcing level
x admitted duration
```

Primary metrics:

- max and mass-weighted pressure-head error versus `REF-HIGH`;
- water-content/storage error;
- integrated top transfer error;
- integrated bottom transfer error;
- total water-balance residual;
- accepted/rejected status.

Secondary metrics:

- reference nonlinear iterations;
- Ross work counters;
- internal/substep counts;
- temporal certificate diagnostics.

Analysis rule:

- compare `ROSS` and `REF-PROD` separately against `REF-HIGH`;
- never report only Ross-minus-Reference if both production methods differ materially from `REF-HIGH`.

Candidate figure ownership:

- `PUB-SQ-F01`: error distribution/surface across common admissible regimes.

### SQ-E2 — Admissibility-boundary probing

Hypotheses: H1, H3.

Purpose: test whether the declared RossFast envelope corresponds to a stable scientific/numerical applicability boundary rather than a benchmark convenience.

For each selected material/regime, construct paired cases:

- safely inside the domain;
- close to the boundary;
- just outside the domain where the API/contract permits fail-closed probing.

Primary metrics:

- preflight/admission outcome;
- failure classification;
- candidate mutation before rejection, expected absent where preflight owns the boundary;
- numerical error immediately inside the boundary;
- diagnostic/certificate behaviour.

Do not use unsupported cases to calculate performance speedups.

Candidate result:

- explicit regime/domain table showing supported, boundary-sensitive and rejected regions.

### SQ-E3 — Equal-error cost experiment

Hypothesis: H4.

Purpose: test computational advantage at comparable scientific error rather than identical nominal timestep settings.

For a reduced but representative subset of SQ-E1 cases:

1. construct `REF-HIGH`;
2. run each production solver over a controlled ladder of its applicable time/accuracy controls;
3. interpolate or bracket configurations that achieve comparable endpoint/integrated-transfer error;
4. compare computational cost at those comparable errors.

Primary metrics:

- error versus CPU time;
- error versus wall time;
- error versus solver work count;
- retries/rejections;
- total model cost versus soil-water-solver cost.

Timing protocol:

- repeat each timing configuration multiple times;
- use balanced/randomized execution order;
- report median and dispersion;
- retain work counters so conclusions are not dependent on shared-runner noise.

Candidate figure ownership:

- `PUB-SQ-F02`: Pareto-style error-cost curves.

A speedup claim is not allowed unless the compared points satisfy the declared equivalent-accuracy rule.

### SQ-E4 — Whole-trajectory accumulation

Hypotheses: H1, H2, H4.

Purpose: determine whether small accepted-step solver differences accumulate into materially different hydrologic trajectories.

Design:

- multi-day or otherwise multi-step forcing sequence within the common admitted domain;
- identical accepted initial state;
- same surrounding SWAP time/retry/acceptance policy;
- Reference and RossFast selected explicitly in separate runs;
- `REF-HIGH` trajectory for a smaller number of representative cases.

Primary metrics over time:

- pressure-head profile error;
- storage difference;
- cumulative top/bottom transfer difference;
- mass residual;
- accepted timestep history;
- retry history;
- divergence/convergence of solver trajectories.

Candidate figure ownership:

- `PUB-SQ-F03`: cumulative trajectory error and cost.

### SQ-E5 — Scientifically expanded domain

Status: **blocked until solver-domain qualification exists**.

Potential dimensions:

- prescribed-head lower boundary;
- groundwater-sensitive states;
- dynamic atmospheric upper boundary;
- root uptake/source-sink;
- heterogeneous grid/profile.

Do not create publication claims from these dimensions before their RossFast capability is separately qualified and mapped to the same solver-independent contract.

## 5. Initial design reduction

The full Cartesian product of all factors is likely unnecessary and expensive.

Use a staged design:

### Stage A: screening

Run a broad deterministic screening matrix across all six materials with a small number of hydraulic states, forcing levels and durations.

Goal:

- identify regimes with near-zero difference;
- identify high-error/high-cost regimes;
- identify useful boundary cases;
- identify candidates for strict `REF-HIGH` construction.

These runs are `PROSPECTIVE_SUPPORTING` unless selected as primary before execution.

### Stage B: primary matrix

Freeze a smaller stratified matrix before primary runs, preserving:

- all six material classes or a documented scientifically representative subset;
- dry/intermediate/wet regimes;
- low/high admissible forcing;
- short/long admitted durations;
- at least one boundary-sensitive regime.

These runs become `PROSPECTIVE_PRIMARY`.

### Stage C: trajectory cases

Select cases from Stage B using predeclared rules, not by choosing only the largest favorable RossFast speedups.

## 6. Numerical-reference construction

For each primary case requiring `REF-HIGH`:

1. run the qualified Reference route with stricter temporal controls;
2. refine controls again;
3. quantify change in the primary state/transfer metrics;
4. declare the reference stable only if the second refinement changes those metrics below a predeclared fraction of the comparison tolerance.

If the Reference route cannot provide a stable `REF-HIGH` for a case, the case must be classified separately rather than treating its production answer as truth.

## 7. Required raw telemetry

In addition to the common manifest:

- solver request identity;
- actual solver identity executed;
- admitted-domain version;
- pressure-head and water-content vectors at start/end;
- top/bottom integrated transfers;
- storage change;
- mass residual;
- accepted timestep/duration;
- retry sequence;
- Reference Newton/backtracking/linear-solve statistics;
- RossFast internal substeps/work counters;
- temporal certificate/status;
- CPU time in soil-water solver;
- total model CPU/wall time.

## 8. Predeclared failure outcomes

The following are scientifically meaningful results:

- RossFast accurate but not faster at equivalent error;
- RossFast faster only in a narrow hydraulic regime;
- Reference production route less accurate than RossFast against `REF-HIGH` for selected cases;
- both production routes insufficient under a strict requirement;
- RossFast domain too narrow for broad operational relevance;
- adaptive retry policy dominates any raw solver speed advantage.

None of these should trigger post-hoc removal of the case.

## 9. Manuscript artifact plan

Candidate primary artifacts:

- `PUB-SQ-T01`: solver-independent contract and domain table;
- `PUB-SQ-F01`: common-domain error/admissibility surface;
- `PUB-SQ-F02`: equal-error cost curves;
- `PUB-SQ-F03`: whole-trajectory accumulation;
- `PUB-SQ-T02`: measured regime summary with admissibility and cost characteristics.

The final paper may use fewer artifacts. Ownership is reserved to `PUB-SQ` even if raw timing data are reused elsewhere.

## 10. Go/no-go after first primary tranche

Continue toward a standalone `PUB-SQ` manuscript only if the first primary tranche establishes at least one of:

- a nontrivial, reproducible domain in which substitution is scientifically equivalent and computationally different;
- a nontrivial domain boundary that demonstrates why explicit solver qualification matters;
- meaningful evidence that equal-error/model-level qualification leads to materially different conclusions than a conventional fixed-timestep solver benchmark.

If none is found, fold the solver work into `PUB-ME`/thesis infrastructure rather than forcing a separate publication.
