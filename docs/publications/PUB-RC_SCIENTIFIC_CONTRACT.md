# PUB-RC scientific contract

Working title: **Response-assisted nonlinear coupling of dynamic vadose-zone and groundwater models**

Status: **initial research-design contract, not yet a manuscript claim**

Publication owner: `PUB-RC`

Doctoral mapping: `RQ4 / ACCELERATE`

Dependency: the base coupling semantics are owned by `PUB-GC`.

## 1. Central research question

> Can whole-window interface response information from the coupled subsystems reduce the cost or improve the robustness of nonlinear groundwater-vadose coupling without weakening conservation, accepted-state semantics or reproducibility?

The paper starts only after the base coupling problem has been defined independently. It is therefore not allowed to use response acceleration as evidence that the underlying coupling formulation is correct.

## 2. Coupled interface problem

For a scalar interface head `h`, let the dynamic SWAP subsystem evaluated over a fixed coupling window from accepted origin `X^n` return a whole-window exchange or its mean coupling flux:

```text
q = S(h; X^n, F, I_n)
```

Let the groundwater subsystem, evaluated from accepted groundwater origin `G^n` over the same coupling window, return the corresponding interface head:

```text
h_new = M(q; G^n, I_n)
```

A converged coupled state satisfies

```text
R(h) = h - M(S(h)) = 0
```

where sign conventions and whole-window/mean-flux translations remain those of `PUB-GC`.

If differentiable response information is available,

```text
dR/dh = 1 - (dM/dq) * (dS/dh)
```

provides a natural local interface Jacobian for Newton, quasi-Newton or safeguarded response-assisted updates.

For multiple cells/columns the same concept becomes a vector/matrix interface problem; scalar or block-diagonal approximations may be investigated before full cross-cell sensitivities.

## 3. Current SWAP5 basis

SWAP5 already contains an admitted optional F-GC29 groundwater response-sensitivity service extension. Its closed contract binds a groundwater trial, candidate and response sensitivity atomically; preserves exact service/lineage/origin/candidate/window provenance; prevents stale response leakage across retry/rejection; and fails closed for unavailable, unsupported, nonsmooth, provider-error or nonfinite derivative paths.

The current admitted derivative is groundwater-side:

```text
dh_groundwater / dq_groundwater
```

at the already evaluated groundwater trial point.

F-GC29 deliberately does **not** own coupling iteration policy, finite-difference production construction, commit/rollback or new groundwater physics.

This is therefore a useful building block for `PUB-RC`, but not yet the complete response-assisted coupling method. In particular, an equivalent qualified SWAP-side whole-window sensitivity `dS/dh` or a defensible interface approximation remains a separate research requirement.

## 4. Protected primary contribution

The candidate contribution is the use of **provenance-bound whole-window subsystem response information** to accelerate an otherwise already valid replay-based hydrologic coupling iteration.

The protected contribution is expected to combine:

1. response quantities attached to the exact subsystem trial that generated them;
2. whole-window rather than instantaneous interface response;
3. replay from the same accepted origin for every outer candidate;
4. safeguarded use of exact/approximate response information;
5. fallback to a valid non-response iteration when response is unavailable or nonsmooth, without changing accepted scientific semantics;
6. evaluation by convergence/error-versus-cost rather than iteration count alone.

General Newton, quasi-Newton, Aitken, waveform-relaxation and interface-Jacobian methods are not new and must be treated as prior numerical methodology.

## 5. Novelty boundary

### Iterative hydrologic coupling already exists

HYDRUS-MODFLOW and related work already use iterative head/flux feedback and relaxation. `PUB-RC` cannot claim iterative two-way feedback itself as new.

### Partitioned response acceleration already exists

General partitioned multiphysics literature includes Newton and quasi-Newton interface acceleration, waveform iteration, checkpoint/replay and multirate coupling. `PUB-RC` must therefore demonstrate a hydrologically specific contribution associated with finite-window vadose-groundwater response, provenance, nonsmooth handling and practical subsystem cost.

### Sensitivity analysis itself is not new

The novelty cannot be "we computed a derivative". The scientific question is whether local dynamic subsystem response over a coupling window is sufficiently informative, stable and affordable to improve the accepted coupled solve.

## 6. Hypotheses

### H1. Local interface response predicts coupling stiffness

The product

```text
K_interface = (dM/dq) * (dS/dh)
```

contains useful information about local coupling strength and fixed-point convergence behaviour.

Evidence required:

- measured tangents at representative accepted/trial states;
- comparison with observed contraction/divergence of plain fixed-point iteration;
- regimes spanning weak and strong groundwater-vadose feedback;
- explicit treatment of sign and units.

### H2. Response-assisted updates reduce expensive subsystem evaluations

A safeguarded response-assisted method can reach the same coupled acceptance criteria using fewer SWAP/MODFLOW trial evaluations than plain fixed-point or relaxed iteration in at least some relevant strong-feedback regimes.

Evidence required:

- equal final head/exchange tolerance;
- counts of both subsystem solves;
- wall/CPU time;
- response-evaluation overhead;
- accepted/rejected update history.

### H3. Whole-window response is more useful than terminal-response surrogates for finite coupling windows

When forcing or lower-boundary exchange varies strongly within the coupling window, a response tied to the integrated window operator should better predict the actual coupled residual than a derivative of only the terminal instantaneous flux/state.

Evidence required:

- transient stress cases;
- prediction quality of local linear models;
- convergence comparison using alternative response definitions where scientifically implementable.

### H4. Response unavailability can be handled without weakening correctness

Nonsmooth, unavailable or invalid sensitivity information can trigger a conservative fallback/step safeguard while preserving the base `PUB-GC` coupling result.

Evidence required:

- deliberately nonsmooth or unavailable response cases;
- no stale derivative reuse;
- no forced acceptance caused by response logic;
- convergence to the same accepted result as the base method when fallback succeeds.

## 7. Minimum experiment set

### E0. Tangent correctness and provenance

For simple smooth groundwater and SWAP subsystem cases, compare provided tangents with high-quality qualification-only finite differences.

Do not use structural finite difference as the production response mechanism if the method claims analytic/provider response.

Check:

- derivative value;
- sign and unit;
- exact window/origin/candidate identity;
- no mutation during response evaluation;
- invalid/nonsmooth fail-closed paths.

### E1. Scalar synthetic coupling

Use one SWAP column and a minimal dynamic groundwater reservoir so the interface residual can be visualized directly.

Compare:

1. plain fixed-point replay;
2. relaxed fixed-point;
3. Aitken or another established low-information accelerator;
4. response-assisted Newton/quasi-Newton candidate method.

Purpose: understand mechanism before MODFLOW complexity.

### E2. Strong-feedback regime matrix

Vary:

- water-table depth;
- soil hydraulic response;
- forcing pulse strength;
- coupling-window length;
- groundwater storage/conductance response;
- proximity to nonsmooth boundary/process transitions.

Primary outputs:

- accepted outer iterations;
- subsystem trial counts;
- rejected/safeguarded updates;
- final error against the same numerical reference;
- response overhead;
- total cost.

### E3. One-column MODFLOW 6 coupling

Repeat the most informative regimes with a real MODFLOW 6 backend.

The method must use the same `PUB-GC` conservation and acceptance criteria for all compared algorithms.

### E4. Approximate versus exact response

Where exact/analytic response is available, compare it with practical approximations such as secant, Broyden or other quasi-Newton updates.

Scientific question: is the cost of obtaining explicit response justified relative to derivative-free interface acceleration?

### E5. Multi-interface scaling

Only after scalar evidence is clear, investigate multiple SWAP columns/cells.

Candidate strategies:

- independent diagonal tangents;
- aggregated N:1 response;
- block-local response;
- limited-memory quasi-Newton history.

Full dense global Jacobians are not assumed necessary and should not be introduced without evidence.

## 8. Safeguarding requirements

Any response-assisted production method should have explicit safeguards for:

- nonfinite derivatives;
- unavailable/nonsmooth response;
- near-singular `dR/dh`;
- update sign reversal or implausibly large step;
- residual increase;
- leaving the subsystem admissibility domain;
- candidate provenance mismatch;
- retry/window reduction.

The response layer must not override hard mass, domain or accepted-state gates from `PUB-GC`.

## 9. Telemetry to preserve now

In addition to `PUB-GC` telemetry preserve:

- response provider identity/version;
- `dS/dh` where available;
- `dM/dq` where available;
- units and sign convention;
- response availability/nonsmooth/error outcome;
- predicted residual slope;
- proposed interface update;
- safeguard/damping factor;
- actual residual reduction;
- response-evaluation cost;
- secant/quasi-Newton history used;
- rejected response updates;
- fallback method activated.

## 10. Primary result forms

Preferred publication figures include:

- observed fixed-point contraction versus predicted interface response product;
- subsystem solves versus coupling-window duration;
- accepted error versus total computational cost;
- convergence traces for representative weak/strong feedback cases;
- benefit map showing where explicit response adds value over established relaxation/quasi-Newton alternatives.

A raw speedup number is insufficient.

## 11. Falsification criteria

`PUB-RC` must be weakened, redirected or collapsed into `PUB-GC` if:

1. plain or relaxed fixed-point converges in very few trials for nearly all relevant cases;
2. response acquisition costs as much as or more than the saved subsystem trials;
3. local response is too noisy/nonsmooth to predict useful updates;
4. derivative-free Aitken/Broyden methods achieve equivalent robustness and cost with less complexity;
5. benefits appear only for unrealistic coupling windows that should simply be reduced;
6. response-assisted updates materially compromise robustness or require hidden solver/model assumptions;
7. the contribution reduces to a direct application of standard partitioned quasi-Newton methods without a distinct hydrologic or whole-window insight.

Negative results should be retained because they directly inform the PhD synthesis about the limits of scientific composability.

## 12. Hard publication firewall

Inherited, not re-claimed:

- same-origin replay, whole-window exchange and interface conservation: `PUB-GC`;
- generic transaction architecture: `PUB-ME`;
- RossFast/reference solver qualification: `PUB-SQ`.

Owned by `PUB-RC`:

- response/sensitivity formulation for the outer coupling problem;
- acceleration algorithm and safeguards;
- convergence/cost consequences of using response information.

Hydrologic consequences of large-scale N:1 heterogeneity remain `PUB-SG`.

## 13. Candidate manuscript structure

1. Nonlinear cost of strongly coupled vadose-groundwater models
2. Base finite-window coupling problem inherited from `PUB-GC`
3. Whole-window subsystem response and interface Jacobian
4. Response provenance and safeguarding
5. Synthetic scalar experiments
6. MODFLOW 6 experiments
7. Exact versus approximate response
8. Computational benefit domains and failure regimes
9. Discussion and limitations
10. Conclusions

## 14. Publication-admission gates

- [ ] base `PUB-GC` coupling method is sufficiently stable and defined to serve as comparator;
- [ ] at least one SWAP-side response or defensible response approximation exists;
- [ ] F-GC29 groundwater-side response semantics are reconciled with the paper method;
- [ ] tangent correctness is independently checked;
- [ ] established acceleration comparators are implemented fairly;
- [ ] response overhead is included in total cost;
- [ ] strong and weak feedback regimes are both represented;
- [ ] nonsmooth/unavailable response paths are tested;
- [ ] final accepted error/conservation is held comparable across methods;
- [ ] benefit survives transition from synthetic groundwater to MODFLOW 6.

## 15. Initial literature anchors

The eventual review should include:

- iterative HYDRUS-MODFLOW coupling and relaxation methods, including Zeng et al. (2019), DOI 10.5194/hess-23-637-2019;
- partitioned multiphysics Newton/quasi-Newton and waveform-iteration literature, including Rüth et al. (2021), DOI 10.1002/nme.6443;
- MODFLOW 6 API/XMI work enabling tightly controlled external nonlinear coupling;
- hydrologic response/sensitivity and Schur-complement/interface-Jacobian methods where directly relevant.

No priority claim is authorized until this boundary is systematically reviewed.
