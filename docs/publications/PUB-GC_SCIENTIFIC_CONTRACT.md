# PUB-GC scientific contract

Working title: **Replay-based conservative coupling of dynamic vadose-zone columns and groundwater flow over finite coupling windows**

Status: **research-design contract, not yet a manuscript claim**

Publication owner: `PUB-GC`

This document defines the scientific question, novelty boundary, minimum evidence and explicit exclusions for the groundwater-coupling publication line. It is intentionally narrower than the full SWAP5 groundwater roadmap.

## 1. Central research question

> How can independently time-integrating vadose-zone and groundwater models be coupled conservatively and reproducibly over finite coupling windows while retaining the native numerical integration of both subsystems?

The paper is about the **coupling method**. It is not primarily a software-architecture paper, solver-comparison paper, response-acceleration paper or regional upscaling paper.

## 2. Coupled problem formulation

For coupling window

```text
I_n = [t_n, t_{n+1}]
```

let `X_i^n` be the accepted state of SWAP column `i` and `G^n` the accepted groundwater state at the start of the window.

For an interface-head candidate `h_c^(k)`, define the SWAP whole-window operator

```text
S_i : (X_i^n, F_i, h_c^(k))
      -> (Q_i^(k), X_i_candidate^(n+1,k))
```

where

```text
Q_i^(k) = integral over I_n of q_bottom,i(t) dt
```

is the integrated lower-boundary exchange over the complete coupling window.

For an area-weighted set of columns mapped to one groundwater cell,

```text
V_c^(k) = sum_i A_i Q_i^(k)
```

is the volume transferred to the groundwater coupling operator. The groundwater operator then produces a groundwater candidate and an updated interface head.

The publication does not require a particular internal SWAP timestep or groundwater solver timestep. The coupling contract is defined at the finite-window interface.

## 3. Protected primary contribution

The candidate primary contribution is the **hydrologically explicit combination** of:

1. **same-origin replay**: each competing coupling candidate over a window is evaluated from the same accepted SWAP and groundwater origin, rather than continuing from the state produced by the previous candidate;
2. **whole-window exchange**: the exchanged water quantity is the integrated lower-boundary transfer over the coupling window, not a terminal instantaneous flux used as a surrogate for the whole interval;
3. **conservative action/reaction accounting**: SWAP and groundwater receive exactly opposite accepted interface exchange, with a coupled-system conservation residual that is explicitly checked;
4. **accepted-state publication**: trial calculations remain non-authoritative until the coupled acceptance criteria are satisfied and the SWAP, groundwater and interface-accounting states can be published consistently.

The paper must demonstrate numerical consequences of this formulation. Merely documenting that the software implements these concepts is insufficient for publication.

No priority statement such as "first-ever" is authorized by this contract. Any eventual priority claim requires a completed systematic literature review.

## 4. Existing SWAP5 authority that may be reused

The current admitted Groundwater Coupling v1 documentation already establishes a bounded scientific foundation that `PUB-GC` may reuse rather than rediscover:

- explicit hydraulic-head/pressure-head datum translation;
- explicit flux sign and unit translation;
- whole-window lower-boundary exchange;
- restricted predictor/corrector evaluation from the same accepted origin;
- rollback of predictor candidates before corrector evaluation;
- governed interface-head convergence;
- exact paired interface exchange and committed mass ledger;
- accepted-state publication after preflight;
- bounded MultiSWAP aggregation and transaction isolation;
- a structural external-groundwater gateway.

The existing Status-A route is deliberately narrower than this publication programme. In particular it does not itself establish a broad MODFLOW backend or an unlimited fixed-point coupling algorithm.

## 5. Novelty boundary against prior work

The novelty claim must remain narrower than the items below.

| Prior work / system | What is already established | Consequence for `PUB-GC` |
| --- | --- | --- |
| Twarakavi et al. (2008), HYDRUS-based flow package for MODFLOW, DOI 10.2136/vzj2007.0082 | 1-D Richards vadose-zone profiles coupled to 3-D MODFLOW for groundwater-vadose interaction | Do not claim that coupling dynamic 1-D vadose-zone models to MODFLOW is new |
| Xu et al. (2012), SWAP-MODFLOW, DOI 10.1016/j.jhydrol.2011.07.002 | direct SWAP and MODFLOW integration with two-way shallow-groundwater interaction | Do not claim that SWAP-MODFLOW coupling itself is new |
| Van Walsum and Groenendijk (2008), MetaSWAP, DOI 10.2136/vzj2007.0146 | efficient quasi-steady unsaturated-zone representation derived from SWAP concepts for regional groundwater modelling | Distinguish full dynamic SWAP replay from MetaSWAP's reduced/quasi-steady formulation |
| Van Walsum and Veldhuizen (2011), SIMGRO, DOI 10.1016/j.jhydrol.2011.08.036 | shared phreatic state, iterative subsystem integration, N:1 SVAT-to-groundwater linkage | Do not claim shared-state coupling, outer iteration or N:1 linkage as new by themselves |
| Beegum et al. (2018), HYDRUS-MODFLOW update, DOI 10.2136/vzj2018.02.0034 | coupling modifications to reduce spurious bottom-flux behaviour caused by groundwater-head updates | Explicitly benchmark temporal-interface error, not only mass closure |
| Zeng et al. (2019), iterative HYDRUS-MODFLOW, DOI 10.5194/hess-23-637-2019 | iterative head/flux feedback, relaxed coupling and multi-scale interface water balance | Do not claim iterative feedback coupling itself as new; include it as a methodological comparator where feasible |
| Hughes et al. (2022), MODFLOW API, DOI 10.1016/j.envsoft.2021.105257 | external control and tight nonlinear coupling through MODFLOW 6 API/XMI | Do not claim external runtime control of MODFLOW 6 as new |
| Rüth et al. (2021), partitioned multiphysics waveform/quasi-Newton coupling, DOI 10.1002/nme.6443 | time-window partitioned coupling, multirate integration, iteration replay/checkpointing and quasi-Newton acceleration in general multiphysics | Do not claim checkpoint/replay or partitioned time-window coupling as a general computational-science invention |

### Candidate novelty statement

Subject to further literature review and experimental support, the defensible novelty direction is:

> a conservative hydrologic partitioned-coupling formulation in which full dynamic SWAP columns are repeatedly evaluated over a finite coupling window from the same accepted origin, exchange an integrated whole-window water amount with the groundwater model, and publish the next state only after coupled interface acceptance.

The contribution is therefore expected to lie in the **specific hydrologic formulation, proof through experiments and its consequences for coupling error and conservation**, not in the isolated existence of SWAP, MODFLOW, N:1 mapping, iteration, checkpointing or an API.

## 6. Hypotheses

### H1. Same-origin evaluation

For deterministic subsystem solvers, replay from the same accepted origin defines a reproducible subsystem response for each interface candidate and prevents candidate-history contamination.

Evidence required:

- repeatability of candidate response from identical checkpoint and forcing;
- a deliberately constructed comparison in which continuing from a previous candidate produces a different result or demonstrably changes the evaluated operator;
- provenance showing all compared candidates share the same accepted origin.

### H2. Whole-window conservative exchange

Using the integrated lower-boundary exchange over the coupling window provides a conservative interface transfer that is independent of an arbitrary terminal-flux sample.

Evidence required:

- exact or roundoff-bounded action/reaction closure at the interface;
- comparison with at least one terminal/instantaneous-flux exchange formulation under transient conditions;
- component and combined-system mass balances reported separately.

### H3. Coupling convergence

As the coupling window and/or outer coupling residual are tightened, the coupled solution approaches a stable numerical reference for head and exchange.

Evidence required:

- convergence curves against a declared numerical reference;
- at least groundwater-head and cumulative interface-exchange errors;
- sensitivity across multiple strength-of-feedback regimes.

### H4. Practical robustness

The method remains usable when groundwater-vadose feedback is strong enough that simple loose sequential exchange becomes inaccurate or unstable at practically relevant coupling windows.

Evidence required:

- at least one nontrivial stress regime where method choice materially affects the solution;
- explicit failure/retry/window-reduction reporting;
- no claim of superiority if all methods behave indistinguishably in the relevant regime.

## 7. Minimum experiment set

The paper is not admissible on a single regional case. It requires a controlled numerical ladder.

### E0. Interface semantics and conservation

Purpose: prove the basic exchange contract independently of complex regional behaviour.

Test:

- known lower-boundary exchange and datum values;
- bidirectional exchange including recharge and capillary rise;
- exact sign/unit conversion checks;
- action/reaction interface ledger closure;
- rejected candidate must not alter committed exchange.

Primary outputs:

- SWAP-side exchange;
- groundwater-side exchange;
- combined residual;
- committed versus rejected exchange history.

Owner: `PUB-GC`.

### E1. One SWAP column plus a minimal dynamic groundwater reservoir

Purpose: isolate the nonlinear coupling behaviour before MODFLOW-specific complexity is introduced.

The groundwater component should have transparent storage/head dynamics so that reference behaviour can be obtained with very small windows and strict convergence.

Stress dimensions should include:

- shallow versus deeper groundwater;
- wetting/recharge pulse;
- drying/evapotranspiration/capillary-rise period;
- contrasting soil hydraulic response;
- coupling-window duration.

Compare at minimum:

1. loose/sequential exchange;
2. restricted `pc1` replay route;
3. converged replay-based outer iteration when available.

A Zeng-style relaxed iterative approach should be considered as a literature-based comparator where implementation can be made scientifically equivalent.

Owner: `PUB-GC`.

### E2. One SWAP column plus MODFLOW 6

Purpose: demonstrate that the same coupling semantics survive transition to a real 3-D groundwater solver controlled through an admitted external gateway/backend.

Keep geometry deliberately small enough that strict reference runs are affordable.

Required outputs:

- interface-head residual per outer iteration;
- cumulative whole-window exchange;
- groundwater head trajectory;
- total coupled mass residual;
- number of SWAP trials and MODFLOW trials;
- retry/window-reduction history;
- wall/CPU time as descriptive diagnostics only.

Runtime performance is not a primary `PUB-GC` conclusion.

### E3. Coupling-window convergence matrix

Purpose: establish temporal/coupling consistency.

For selected feedback regimes, vary coupling-window duration over a sufficiently broad range and compare against a strict numerical reference.

Primary figures should report, as functions of coupling-window duration:

- groundwater-head error;
- cumulative exchange error;
- combined water-balance residual;
- number of failed/retried coupling windows where applicable.

This experiment should determine the practical domain in which restricted `pc1` is sufficient and the domain in which fuller iteration is required.

Owner: `PUB-GC`.

### E4. Bounded N:1 conservation demonstration

Purpose: establish that multiple SWAP columns can be conservatively mapped to one groundwater cell without turning `PUB-GC` into an upscaling paper.

Use a small number of heterogeneous columns and verify:

```text
V_groundwater = sum_i A_i Q_i
```

within the declared arithmetic/mass-accounting contract.

Only conservation, mapping semantics and transaction isolation belong in `PUB-GC`.

Any conclusion about whether explicit heterogeneity is hydrologically important belongs to `PUB-SG`.

### E5. Realistic demonstration case

Purpose: show relevance beyond synthetic tests.

The case must contain actual two-way groundwater-vadose feedback, but it need not be a national or very large regional model. A compact, well-observed or otherwise well-characterized shallow-groundwater case is preferable to a huge model that obscures numerical interpretation.

The case is a demonstration, not the sole validation of the method.

## 8. Numerical reference definition

The paper should avoid using the word "truth" for a model-model comparison.

A numerical reference should be constructed from:

- substantially smaller coupling windows than the tested production settings;
- strict outer interface convergence;
- independently qualified subsystem solvers;
- conservation checks that are at least as strict as those used in the tested methods.

Reference convergence itself must be demonstrated by an additional refinement step or equivalent evidence.

## 9. Telemetry to preserve now

Publication-quality diagnostics should be persisted during development rather than reconstructed later. For every coupling-window trial, preserve at least:

- run/case identifier;
- SWAP and groundwater implementation commit identifiers;
- coupling-window start/end/duration;
- accepted-origin lineage/revision for both subsystems;
- outer iteration / predictor-corrector stage;
- prescribed SWAP interface head;
- returned groundwater head;
- head residual and governing tolerance provenance;
- integrated SWAP lower-boundary exchange;
- paired groundwater exchange;
- interface conservation residual;
- candidate accepted/rejected status;
- reason for rejection;
- requested window reduction/retry;
- number of internal SWAP time steps and relevant solver statistics;
- groundwater nonlinear/linear iteration counts where available;
- SWAP CPU time, groundwater CPU time and total wall time;
- mapping identifiers and areas for N:1 cases.

Performance telemetry may later become shared infrastructure for `PUB-RC`, `PUB-SQ` or `PUB-SG`; the coupling-error/conservation inference remains owned by `PUB-GC`.

## 10. Falsification criteria

The research design must be capable of weakening or rejecting the proposed contribution.

`PUB-GC` must be reframed or abandoned as a standalone methods paper if, after fair comparison:

1. same-origin replay produces no measurable or conceptual distinction from existing hydrologic coupling methods in the regimes of interest;
2. whole-window exchange provides no demonstrable consistency/conservation advantage over the appropriate established comparator;
3. the proposed method fails to approach a stable numerical reference as coupling controls are tightened;
4. the method only becomes usable after introducing response/tangent acceleration, in which case the core result may belong in `PUB-RC` instead;
5. the final novelty reduces to generic partitioned-coupling checkpoint/rollback already established in the general multiphysics literature;
6. a close existing SWAP/MODFLOW, HYDRUS/MODFLOW, SIMGRO or related method is found to implement the same finite-window same-origin exchange semantics with equivalent evidence.

Negative or null findings should be retained as evidence rather than hidden by changing the comparator or test regime.

## 11. Hard publication firewall

### Excluded from `PUB-GC` primary claims

The following belong elsewhere even if the code appears in the same experiments:

- SWAP5 transactional architecture as a general model-modernization contribution: `PUB-ME`;
- SWAP4.3.1 to SWAP5 behavior-preserving migration methodology: `PUB-ME`;
- Newton versus RossFast accuracy, robustness, speed or admissibility maps: `PUB-SQ`;
- response derivative `dQ/dh`, quasi-Newton acceleration or response-assisted reduction in expensive subsystem reruns: `PUB-RC`;
- hydrologic importance of explicit heterogeneous N:1 representation versus an effective/homogenized column: `PUB-SG`;
- regional parallel speedup as a standalone contribution: outside `PUB-GC` unless needed only as descriptive feasibility evidence.

### Reusable but not re-claimable

`PUB-GC` may reuse:

- qualified SWAP5 transaction/checkpoint services;
- a qualified reference or RossFast soil-water solver;
- generic benchmark/timing infrastructure;
- MODFLOW API/XMI functionality;
- shared cases and forcing datasets.

The paper must cite or reference those capabilities as prerequisites, not present them again as its own scientific novelty.

## 12. Candidate manuscript structure

1. Introduction and precise research gap
2. Existing coupling approaches and novelty boundary
3. Finite-window coupling formulation
4. Same-origin replay and accepted-state semantics as numerical requirements
5. Whole-window exchange and conservation formulation
6. Numerical experiments and reference construction
7. Results: conservation, temporal error and convergence
8. MODFLOW 6 demonstration
9. Bounded N:1 conservation demonstration
10. Discussion, limitations and relation to SIMGRO/MetaSWAP/HYDRUS-MODFLOW
11. Conclusions

The implementation architecture should be described only to the extent required to reproduce the coupling method.

## 13. Publication-admission gates

Before `PUB-GC` can be treated as manuscript-ready, all of the following must be satisfied:

- [ ] systematic literature review has tested the candidate novelty statement;
- [ ] concrete MODFLOW 6 backend has scientific/unit/datum/temporal conformance evidence;
- [ ] E0 interface/conservation evidence is green;
- [ ] E1 controlled subsystem benchmark is reproducible;
- [ ] E2 MODFLOW 6 benchmark is reproducible;
- [ ] E3 demonstrates convergence toward a declared numerical reference;
- [ ] the numerical reference itself has a refinement/strictness check;
- [ ] at least one scientifically relevant regime distinguishes the coupling formulations;
- [ ] N:1 claims in the paper remain bounded to mapping/conservation unless transferred to `PUB-SG`;
- [ ] all primary figures/tables have a single publication owner;
- [ ] no primary result duplicates `PUB-ME`, `PUB-SQ` or `PUB-RC`;
- [ ] exact source, configuration, input and result provenance is frozen for the submitted experiments.

Until these gates are satisfied, the novelty language in this document remains a research hypothesis rather than an admitted publication claim.

## 14. Initial reference set

- Twarakavi, N. K. C., Simunek, J., and Seo, S. (2008). *Evaluating interactions between groundwater and vadose zone using the HYDRUS-based flow package for MODFLOW*. Vadose Zone Journal. DOI: 10.2136/vzj2007.0082.
- Van Walsum, P. E. V., and Groenendijk, P. (2008). *Quasi steady-state simulation of the unsaturated zone in groundwater modeling of lowland regions*. Vadose Zone Journal. DOI: 10.2136/vzj2007.0146.
- Van Walsum, P. E. V., and Veldhuizen, A. A. (2011). *Integration of models using shared state variables: Implementation in the regional hydrologic modelling system SIMGRO*. Journal of Hydrology. DOI: 10.1016/j.jhydrol.2011.08.036.
- Xu, X. et al. (2012). *Integration of SWAP and MODFLOW-2000 for modeling groundwater dynamics in shallow water table areas*. Journal of Hydrology. DOI: 10.1016/j.jhydrol.2011.07.002.
- Beegum, S. et al. (2018). *Updating the coupling algorithm between HYDRUS and MODFLOW in the HYDRUS package for MODFLOW*. Vadose Zone Journal. DOI: 10.2136/vzj2018.02.0034.
- Zeng, J. et al. (2019). *Capturing soil-water and groundwater interactions with an iterative feedback coupling scheme: new HYDRUS package for MODFLOW*. Hydrology and Earth System Sciences. DOI: 10.5194/hess-23-637-2019.
- Rüth, B. et al. (2021). *Quasi-Newton waveform iteration for partitioned surface-coupled multiphysics applications*. International Journal for Numerical Methods in Engineering. DOI: 10.1002/nme.6443.
- Hughes, J. D. et al. (2022). *The MODFLOW Application Programming Interface for simulation control and software interoperability*. Environmental Modelling & Software. DOI: 10.1016/j.envsoft.2021.105257.

This list is a starting set, not a completed systematic review.
