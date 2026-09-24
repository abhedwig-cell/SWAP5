# PUB-SQ scientific contract

Working title: **Scientific qualification of an alternative Richards solver inside an established process model**

Status: **initial research-design contract, not yet a manuscript claim**

Publication owner: `PUB-SQ`

Doctoral mapping: `RQ2 / REPLACE`

## 1. Central research question

> Under what conditions may an alternative numerical solver replace the established Richards solver in a process-based hydrological model without confusing numerical speed with scientific validity?

The paper is not about inventing the Ross scheme. It is about **solver substitution as a qualified scientific decision** inside a larger model whose forcing, state, mass accounting, retry and acceptance semantics remain externally owned.

## 2. Current SWAP5 basis

The frozen Status-A reference route remains the existing Newton-Raphson/HeadCalc Richards implementation. Its residual, Jacobian, backtracking, convergence tests, linear solve/fallback and candidate-state semantics are documented independently.

Post-Status-A work has introduced a typed `soil_water_solver_t` seam and an admitted restricted RossFast D3R production selection. F-ROSS12 deliberately keeps the surrounding SWAP transaction, forcing, mass, retry and commit lifecycle authoritative; explicit `ROSSFAST_D3R` selects a bounded alternative solver while blank/default and `REFERENCE_RICHARDS` preserve the reference path.

Current evidence therefore provides a strong experimental platform, but not yet a publication result.

## 3. Protected primary contribution

The candidate contribution is a **scientific solver-admission framework** for an established process model, combining:

1. a solver-independent physical/state/request-result contract;
2. a declared admissibility domain for each solver;
3. preservation of external mass, time, retry and commit semantics;
4. fail-closed rejection outside the admitted solver envelope;
5. comparison against an independently defined reference solver and model-level acceptance criteria;
6. accuracy, robustness and computational cost assessed jointly rather than speed used as the admission criterion.

The method should answer not simply "which solver is faster?" but:

> For which states, forcing regimes, boundary conditions and accuracy requirements is substitution scientifically defensible?

## 4. Novelty boundary

Richards-equation solver comparisons already exist. In particular, Maina and Ackerer (2017) compare Ross and Newton-Raphson schemes and time-stepping strategies for the mixed Richards equation. Numerical methods, adaptive time stepping and performance comparisons are therefore not new by themselves.

`PUB-SQ` must distinguish itself by embedding solver comparison in a **model-level qualification problem**:

- identical accepted scientific state and forcing contract;
- explicit solver domain;
- independent mass and temporal acceptance outside the solver;
- no silent fallback when the selected alternative solver is outside its admitted domain;
- preservation of model-level continuation semantics;
- a reproducible decision surface for admission rather than a single benchmark ranking.

The paper must not claim the Ross algorithm itself as novel.

## 5. Hypotheses

### H1. Solver equivalence is domain-dependent

Within a bounded admissibility domain, the alternative solver can reproduce model-relevant states and integrated water transfers within declared scientific/numerical tolerances relative to the qualified reference route.

Outside that domain, equivalence must not be assumed.

Evidence required:

- multi-dimensional regime matrix rather than one benchmark;
- state, flux, storage and mass comparison;
- declared tolerances tied to application/numerical requirements;
- explicit rejected/out-of-domain cases.

### H2. Model-level acceptance must remain solver-independent

A solver reporting numerical success is not sufficient to make its result accepted model state. Independent transaction, mass and temporal gates can reject a solver candidate without changing the scientific history.

Evidence required:

- candidate accepted/rejected examples for both solver routes;
- hard mass failures that cannot be overridden by solver success;
- retry/rollback continuation equivalence;
- no state contamination after rejected RossFast attempts.

### H3. Fail-closed selection protects scientific interpretation

Explicit solver selection with no automatic fallback prevents the model from silently changing the numerical method when the requested solver is unsupported or fails qualification.

Evidence required:

- out-of-envelope RossFast selection fails before accepted mutation;
- no hidden HeadCalc/reference fallback;
- user-visible/provenance-visible solver identity for accepted runs.

### H4. Computational advantage has a structured regime

Where RossFast is admissible, it may reduce computational work relative to the reference Newton route, but the benefit will vary with hydraulic regime, time-step policy and required accuracy.

Evidence required:

- work counters and wall/CPU time;
- error-versus-cost curves, not time alone;
- separation between solver work and total-model overhead;
- reporting of regimes where the alternative is slower, less robust or inapplicable.

## 6. Minimum experiment set

### E0. Contract and identity qualification

Demonstrate that both solvers consume/produce the same model-level request/result semantics for the common admissible envelope.

Preserve:

- exact initial accepted state;
- forcing;
- boundary type and values;
- duration;
- solver identity;
- returned candidate state;
- mass transfers;
- diagnostic certificate/status.

### E1. Restricted D3R reproduction matrix

Use the currently admitted RossFast D3R envelope as the first controlled benchmark surface. Vary the dimensions already scientifically meaningful within that envelope, including hydraulic state and forcing intensity.

Compare:

- endpoint pressure head;
- water content/storage;
- top and bottom integrated transfers;
- mass residual;
- temporal certificate/accepted time policy where applicable;
- solver work.

### E2. Boundary-of-admissibility tests

Probe states immediately inside and outside the declared RossFast envelope.

Purpose:

- verify the envelope is a scientific/numerical boundary rather than an implementation accident;
- identify failure modes and nonsmooth transitions;
- prevent benchmark-only overgeneralization.

### E3. Accuracy-versus-cost curves

For common admissible cases, vary the relevant time/accuracy controls and construct error-versus-cost curves against a declared high-accuracy numerical reference.

Report separately:

- accepted model error;
- solver iterations/work;
- total model time;
- retries;
- rejected candidates.

### E4. Hydrologically diverse model cases

Move beyond the restricted synthetic kernel only when the alternative solver envelope has scientifically justified expansion.

Candidate dimensions include:

- wetting fronts;
- drainage;
- capillary rise;
- contrasting soil hydraulic functions;
- stronger forcing transitions;
- prescribed-head versus prescribed-flux boundaries where supported;
- root uptake/source-sink effects only after separate qualification.

The paper must not imply support for combinations that remain outside the admitted solver domain.

### E5. Whole-model preservation test

For cases where both routes are admissible, compare complete accepted trajectories rather than isolated solver calls.

Purpose: determine whether small per-step differences accumulate into materially different hydrologic outcomes under adaptive time stepping and retries.

## 7. Reference hierarchy

Three distinct references must not be conflated:

1. **scientific/model reference**: the qualified SWAP reference route for the applicable process envelope;
2. **high-accuracy numerical reference**: stricter time/solver controls used to assess both production solvers where feasible;
3. **alternative solver candidate**: RossFast or a future solver under qualification.

The legacy/reference solver must not automatically be called numerical truth. Where both solvers deviate from a stricter reference, that result must be reported.

## 8. Candidate decision surface

A useful publication output would be an admissibility/performance map of the form:

```text
(state, soil, forcing, boundary, dt, accuracy requirement)
                    |
                    v
     REF required / both admissible / alternative preferred
```

However, the paper must avoid turning this into an oversimplified winner ranking. The decision surface should report measured properties and admissibility conditions, not a universal "best solver" conclusion.

## 9. Telemetry to preserve now

For every comparison preserve:

- exact code/ref commits;
- solver identity;
- admitted-envelope version;
- start state and forcing fingerprint;
- boundary configuration;
- attempted and accepted time step;
- endpoint heads/water contents;
- integrated top/bottom transfer;
- mass residual;
- temporal/application certificate values;
- nonlinear/linear iterations for reference solver;
- RossFast work counters;
- retries and failure reason;
- CPU/wall time;
- accepted/rejected status;
- any fallback attempt, expected to remain absent for explicit RossFast selection.

## 10. Falsification criteria

`PUB-SQ` must be narrowed or abandoned as a standalone methods paper if:

1. RossFast is admissible only in a trivial envelope with little practical relevance;
2. its performance advantage disappears when compared at equal accepted error;
3. scientific equivalence cannot be established even inside the claimed domain;
4. the contribution reduces to a conventional Ross-versus-Newton benchmark already covered by the literature;
5. the admissibility framework cannot be separated from SWAP-specific governance terminology;
6. solver-independent mass/time/transaction gates provide no material methodological distinction from ordinary convergence checking.

A negative conclusion, such as a narrow RossFast domain, remains scientifically valuable if rigorously established.

## 11. Hard publication firewall

Excluded from `PUB-SQ` primary claims:

- general SWAP5 modernization method: `PUB-ME`;
- groundwater coupling method: `PUB-GC`;
- response/tangent acceleration of groundwater coupling: `PUB-RC`;
- regional heterogeneity/upscaling: `PUB-SG`.

Groundwater-coupled workloads may later be used as demanding solver benchmarks, but their coupling conclusions must not migrate into this paper.

## 12. Candidate manuscript structure

1. Solver substitution as a scientific qualification problem
2. SWAP Richards reference and alternative solver seam
3. Solver-independent model contract and admissibility concept
4. Experimental domains and numerical references
5. Equivalence and failure-boundary results
6. Accuracy-versus-cost results
7. Whole-model trajectory consequences
8. Discussion: when numerical substitution is scientifically defensible
9. Conclusions

## 13. Publication-admission gates

- [ ] literature review covers Ross/Newton Richards comparisons and solver-verification practice;
- [ ] admissibility domain is scientifically defined, not just coded;
- [ ] equal-error or equivalent-accuracy comparisons exist;
- [ ] mass and temporal acceptance remain independent of solver self-report;
- [ ] failure/out-of-domain cases are included;
- [ ] whole-model accumulation effects are tested;
- [ ] no automatic fallback contaminates solver identity;
- [ ] results report negative regimes as well as favorable regimes;
- [ ] primary conclusions are independent of `PUB-ME` and `PUB-GC`.

## 14. Initial literature anchors

- Maina, F. H. and Ackerer, P. (2017). *Ross scheme, Newton-Raphson iterative methods and time-stepping strategies for solving the mixed form of Richards' equation*. Hydrology and Earth System Sciences, 21, 2667-2683. DOI: 10.5194/hess-21-2667-2017.
- Earlier computational/algorithmic comparisons of Richards-equation solution methods should be included in the systematic numerical-method review.
- Verification literature should be used to distinguish code/algorithm correctness, solution accuracy and empirical hydrologic validation.

This starting set does not authorize a novelty or superiority claim.
