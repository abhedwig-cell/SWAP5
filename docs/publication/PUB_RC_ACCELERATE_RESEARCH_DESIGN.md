# PUB-RC / ACCELERATE research design

## Status

**CONDITIONAL PUBLICATION CANDIDATE**

Default disposition:

- results belong in **PUB-GC / COUPLE** unless the ACCELERATE-specific novelty gates below are passed;
- do not treat ACCELERATE as an independently justified manuscript merely because F-GC30 exposes or uses a coupling response coefficient;
- this document records research governance and does not change SWAP5 production code, coupling semantics or F-GC30 admission.

Established from the literature and novelty review completed on 2026-09-18.

## Working title

**Minimum sufficient response information for iterative coupling of independently time-integrating hydrological models**

Alternative:

**When is supplied hydrological response information worth more than black-box interface history?**

## Refined research question

> Under which hydrological and numerical conditions does explicitly provided finite-window response information reduce the total cost or enlarge the convergence domain of partitioned coupling beyond what can be achieved from black-box interface histories alone, while each component retains independent time integration?

The research question is deliberately narrower than the original ACCELERATE concept. The broader propositions that derivative-informed coupling, autonomous component solvers, multirate integration, interface Jacobians, surrogate-assisted quasi-Newton methods, or hydrological state-dependent response coefficients are novel do not survive the prior-art review.

## Publication boundary

ACCELERATE is not the general SWAP5-MODFLOW6 coupling paper.

**PUB-GC / COUPLE owns:**

- physical and numerical correctness of the SWAP5-MODFLOW6 coupling;
- the fixed coupling plane and hydraulic-head semantics;
- the distinction between q_bot and q_u;
- conservative whole-window exchange;
- transaction, retry, rollback and commit semantics;
- the scientific interpretation and qualification of the F-GC30 response/storage coefficient u;
- scalable SWAP5-MODFLOW6 coupling architecture.

**PUB-RC / ACCELERATE may own only if demonstrated:**

- the incremental computational value of explicitly supplied finite-window hydrological response information relative to a strong black-box multisecant baseline;
- the conditions under which fresh supplied response information is more valuable than re-learning the interface response from current and previous coupling evaluations;
- a generalizable information-value result, not merely a faster SWAP5 implementation.

**PUB-SG / SCALE owns:**

- physical transferability of spatial aggregation or equivalent unsaturated-zone columns;
- errors introduced by heterogeneous forcing, soils and groundwater dynamics when many land-surface units are represented more coarsely.

ACCELERATE must not use spatial aggregation as its primary novelty.

## Explicit non-novelty claims

Do **not** claim novelty from any of the following:

- plain fixed-point, Gauss-Seidel or under-relaxed partitioned coupling;
- Aitken acceleration;
- Newton or quasi-Newton interface coupling;
- IQN-ILS or Anderson/multisecant black-box acceleration;
- reuse of interface history from previous time steps/windows;
- component-provided interface Jacobians or directional derivatives;
- FMI-style derivatives while a component retains its own internal solver;
- waveform relaxation or multirate partitioned time integration;
- autonomous component time integration;
- surrogate-assisted or physics-assisted quasi-Newton coupling;
- dynamic hydrological storage/specific-yield response;
- providing recharge plus a storage-response coefficient to MODFLOW;
- generic regime analysis showing that coupling convergence depends on hydraulic, state or discretization parameters;
- the abstract existence of a finite-window head-to-flux response operator;
- low-rank or approximate response information as a general numerical concept.

These are all substantially covered by prior art recorded in `PUB_RC_ACCELERATE_LITERATURE_REGISTER.md`.

## Information hierarchy

A response-information ladder may be used as an analytical framework, not as a novelty claim.

For one accepted component state S_n and coupling window W:

```text
R0  function evaluation only
    y = R_W(u)

R1  selected directional response
    y plus D R_W(u)[v]

R2  compact local response operator
    y plus a scalar, diagonal or low-rank approximation to D R_W

R3  local reduced finite-window response model
    approximation to R_W(u + delta u) over a bounded validity domain
```

Aitken, IQN-ILS and Anderson acceleration are **coupler algorithms**, not levels in this ladder. In particular, IQN/Anderson may infer response information from R0 evaluations without extra information being exposed by the component.

## Formal response quantities

For one accepted SWAP state S_n, forcing F_W and coupling window W, define the head-driven SWAP response:

```text
V_u(H) = R_W(S_n, F_W; H)
```

where V_u is the accepted-sign, whole-window SWAP-to-groundwater transfer.

The finite-window interface response is:

```text
J_R = d V_u / d H
```

Define the SWAP storage response:

```text
J_S = d DeltaS / d H
```

and, for the remaining whole-window water-balance terms B:

```text
DeltaS(H) = B(H) - V_u(H)

therefore

J_R = J_B - J_S
```

after consistent sign normalization.

This distinction is mandatory. A storage coefficient is not automatically identical to the actual coupling Jacobian if other whole-window fluxes respond to H.

## Relationship to F-GC30 u

F-GC30 v0.1 constructs from three prescribed-bottom-flux trials:

```text
q_1 = q_0 - delta_q
q_2 = q_0 + delta_q

u_FD = ((q_2 - q_1) * DeltaT) / (H_2 - H_1)
```

Locally this approximates:

```text
u_FD ~= DeltaT * (d H_end / d q_bot)^(-1)
```

This is not automatically equal to:

```text
J_R = d V_u / d H
```

because F-GC30 explicitly distinguishes q_bot from q_u and because storage and other whole-window flux responses may differ.

The first scientific requirement for ACCELERATE is therefore an identity/interpretation study of:

```text
u_FD
J_S
J_R
```

from exactly the same accepted origin and coupling window.

## Response-characterization quantities

### Tangent validity

For a reference head H_0 and perturbation radius r:

```text
N(r) =
  max over |deltaH| <= r of
  |V_u(H_0 + deltaH) - V_u(H_0) - J_R * deltaH|
  /
  max(|V_u(H_0 + deltaH) - V_u(H_0)|, V_scale)
```

Define a linear-response radius:

```text
r_lin = max { r : N(r) <= N_tol }
```

The tolerance must be set from repeatability and numerical noise before interpreting results.

### Response drift

For consecutive accepted windows:

```text
D_n =
  |J_R,n+1 - J_R,n|
  /
  max(|J_R,n|, J_scale)
```

D is response drift, not a generic "hydrological memory" variable. Within one window every F-GC30 trial starts from the same complete accepted state, so the relevant memory is already represented in S_n. D becomes relevant when response information or secant history is reused across windows.

### Path dependence

The correct dynamic map may be waveform-valued:

```text
V_u = R_W[H(t)]
```

rather than only terminal-head dependent.

For two trajectories with the same endpoints:

```text
P_path =
  |V_u[H_1(t)] - V_u[H_2(t)]|
  / V_scale
```

If P_path is material at operational window lengths, a scalar terminal-head response is insufficient and the comparison must acknowledge waveform-level coupling.

### Coupling strength

SWAP response alone does not define coupling strength. For a groundwater response G:

```text
H = G(V_u)
```

the scalar local fixed-point factor is:

```text
C = |(dH/dV_u) * J_R|
```

For a vector interface, use the coupled Jacobian and an appropriate spectral/norm analysis rather than forcing a single scalar interpretation.

## Cost model

Iteration count is diagnostic only. The primary performance quantity is total equivalent component work at the same physical convergence tolerance.

Let:

```text
N_F     number of full SWAP-window evaluations
kappa_R response-information acquisition cost
W       N_F + kappa_R
```

with kappa_R expressed in equivalent full SWAP-window evaluations.

For the current centered finite-difference F-GC30 predictor, response construction requires two additional perturbation solves beyond the central predictor:

```text
kappa_FD ~= 2
```

If the response is refreshed only every m windows and reuse is scientifically admissible:

```text
kappa_FD,amortized ~= 2 / m
```

A response-informed method provides genuine SWAP-side computational acceleration relative to a black-box comparator only when:

```text
N_response + kappa_R < N_blackbox
```

at equal convergence, mass-closure and physical-solution criteria.

## Central hypotheses

### H-A - valid-history regime

When finite-window response changes slowly between accepted windows, history reuse in a well-configured black-box multisecant method can make component-provided response information largely redundant.

### H-B - information-scarcity regime

When response changes strongly between windows but is locally regular within the new window, fresh component-provided response information can have high value because old secant information is stale while a new local response is immediately useful.

Expected signature:

```text
D high
r_lin large relative to actual coupling correction
```

### H-C - changed and strongly nonlinear regime

When response drift is high and the new finite-window response is strongly nonlinear over the required correction distance, both historical secants and a single supplied tangent lose validity rapidly. No systematic response-information advantage is expected without richer or refreshed response information.

### H-D - weak-coupling null hypothesis

A large part of the operational hydrological domain may be sufficiently weakly coupled that plain or lightly accelerated fixed-point iteration already requires little work. In that case ACCELERATE solves no material computational problem even if a sophisticated response contract is available.

This null hypothesis must be actively tested.

## Minimal comparator set

Use the smallest set that can falsify the claim without benchmark inflation:

1. **FP** - plain fixed-point coupling;
2. **Aitken** - dynamic relaxation baseline;
3. **IQN/Anderson multisecant** - strong black-box baseline;
4. **response-informed coupling** - supplied J_R or the qualified F-GC30 response if its identity is established.

For the black-box multisecant comparator distinguish:

```text
IQN_cold  no usable prior interface history
IQN_warm  scientifically admissible reuse from previous windows
```

Filtering/reset rules must be credible. ACCELERATE must not obtain an artificial advantage by forcing an otherwise avoidable stale-history failure.

## Oracle experiment

Before implementing a production response-acceleration path, construct an offline, high-quality finite-window response estimate:

```text
J_R,oracle
```

from a qualified perturbation study and temporarily treat its acquisition cost as zero.

Compare:

```text
FP
Aitken
IQN_cold
IQN_warm
Oracle-response
```

at exactly the same coupled solution tolerances.

This is an upper-bound falsification test.

If cost-free, high-quality response information does not provide a material advantage over the black-box multisecant comparator, a practical response that has non-zero acquisition cost cannot justify an independent ACCELERATE paper.

## Response-characterization pre-study

Before the oracle coupling comparison, use one SWAP column and no production MODFLOW backend.

For each accepted state and window:

1. verify deterministic replay from the accepted origin;
2. estimate J_R from symmetric head perturbations over a geometric deltaH sequence;
3. estimate u_FD over a geometric deltaq sequence;
4. estimate J_S and close the differentiated whole-window water balance;
5. determine the numerical derivative plateau;
6. estimate r_lin;
7. test response drift across accepted windows;
8. test path dependence with controlled head trajectories sharing the same endpoints.

Candidate first perturbation sequence, subject to physical admissibility and numerical-noise qualification:

```text
deltaH =
0.00125, 0.0025, 0.005, 0.01, 0.02, 0.04, 0.08 m
```

No individual value is authoritative before repeatability and regime-specific admissibility are established.

## Minimal regime set

Do not start with a large soil catalogue. Begin with deliberate contrasts:

1. weak, stable coupling as negative control;
2. strong but stable coupling;
3. abrupt response change followed by locally regular response;
4. abrupt response change plus strong local nonlinearity.

Start with one relatively fast-response soil profile and one slower/finer profile. Expand only if a reproducible information-value mechanism appears.

## Primary outcomes

At minimum record:

- full SWAP-window evaluations;
- groundwater solver evaluations;
- response-acquisition work;
- wall-clock time;
- coupled residual history;
- accepted head and exchange;
- mass closure;
- non-convergence/failure;
- u_FD, J_S and J_R;
- r_lin;
- response drift D;
- path-dependence metric where relevant.

The final accepted physical solution and tolerances must be common across algorithms.

## Novelty gates

### RC-1 - response identity

Pass only if:

- a reproducible finite-window J_R exists on a non-trivial domain;
- the meaning of F-GC30 u relative to J_R and J_S is empirically and physically understood;
- numerical noise and perturbation dependence are characterized.

If not, ACCELERATE stops and the response question remains in PUB-GC.

### RC-2 - oracle value

Pass only if zero-cost high-quality supplied response information materially reduces total component work or enlarges the convergence domain relative to a credible IQN/Anderson baseline.

If not:

**close ACCELERATE as an independent publication line.**

### RC-3 - acquisition economics

Pass only if the advantage survives realistic response-information acquisition cost, or if the oracle result demonstrates a sufficiently large margin that a credible cheap analytic/trajectory response could retain net benefit.

If not, the response contract remains an implementation choice or PUB-GC result.

### RC-4 - information-scarcity mechanism

Pass only if the advantage can be tied to a reproducible mechanism, for example:

- stale/insufficient black-box history;
- rapid inter-window response drift;
- local regularity of the newly supplied response;
- enlarged convergence robustness.

An isolated speedup case is insufficient.

### RC-5 - generalization

Pass only if the mechanism persists across multiple soil states, groundwater regimes, forcing transitions and coupling-window lengths.

Only after RC-1 through RC-5 should ACCELERATE be treated as a standalone manuscript.

## Current novelty judgement

As of 2026-09-18:

```text
A. New in SWAP/MODFLOW:
   likely for several implementation details, but this belongs primarily to PUB-GC.

B. New in hydrological model coupling:
   still plausible only for the narrow supplied-versus-learned finite-window
   information-value question.

C. New in environmental modelling:
   not established and currently considered unlikely as a broad claim.

D. Methodologically new outside the application domain:
   not supported.
```

Current disposition:

> **Default to integration in PUB-GC unless RC-1 through RC-5 reveal a reproducible information-value regime in which fresh component-provided finite-window hydrological response outperforms state-of-the-art black-box multisecant learning after acquisition cost is included.**

## Candidate journals if the line survives

Journal choice depends on the eventual result:

- **Environmental Modelling & Software** if the contribution is a generalizable model-coupling/information-interface result;
- **Geoscientific Model Development** if reproducible coupling method, implementation and model analysis dominate;
- **Journal of Hydrology**, **Hydrology and Earth System Sciences**, or **Advances in Water Resources** if the principal contribution is hydrological mechanism and regime interpretation.

Journal selection must not drive the novelty claim.

## Related repository documents

- `docs/science/modflow6-tangent-coupling-proposal.md`
- `docs/integration/F-GC30_MODFLOW6_TANGENT_COUPLING_CONTRACT.md`
- `docs/publication/PUB_RC_ACCELERATE_LITERATURE_REGISTER.md`
- `docs/publication/PUBLICATION_PROGRAMME.md`

## Provenance

This research design records the adversarial novelty review performed on 2026-09-18. The review deliberately searched for prior art that could invalidate the strongest ACCELERATE claims. Absence of an identified paper is not evidence of absence. Literature watch must continue before manuscript drafting.
