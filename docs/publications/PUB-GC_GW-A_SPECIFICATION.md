# PUB-GC GW-A specification

Status: **frozen research-component specification; implementation and experiment evidence pending**

Publication owner: `PUB-GC`

Purpose: define the transparent conceptual groundwater component required by `PUB-GC-E1` through `PUB-GC-E4` before any primary same-origin, whole-window or coupling-convergence experiment is executed.

This is a publication research component. It is **not** a production groundwater backend, MODFLOW substitute, hydrologic calibration model or new SWAP5 production authority.

## 1. Decision: the historical F-GC21 dummy is not GW-A

The existing `dummy_groundwater_service_t` is retained as a transactional qualification test double and must not be relabelled as the publication groundwater reservoir.

Frozen evidence for this decision:

- F-GC21 fixture owner authority: `1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f`;
- fixture source: `tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90`;
- fixture blob: `d3cd07965f6fc0d0628557b18d65f3bbc9396888`;
- the independent F-VQ87 oracle reuses that fixture, but only as qualification infrastructure.

The decisive observations are:

1. `dummy_gw_trial` records `q_groundwater_m_per_s` in `last_q_groundwater_m_per_s`, but the returned head is not calculated from that exchange;
2. the returned head is scripted as `0.5 m`, or `0.7 m` for the selected nonconvergence mode, according to trial count and `response_mode`;
3. `dummy_gw_capture` returns an identity/revision token, but does not capture an explicit physical groundwater head/storage state from which a trial response is reconstructed;
4. commit advances time/revision, but there is no groundwater storage-capacitance relation connecting accepted exchange to accepted head.

Therefore the F-GC21 dummy is scientifically suitable for transaction/fail-closed tests, but unsuitable for testing the `PUB-GC` claim about dynamic vadose-groundwater coupling.

No result obtained with that dummy may be promoted to a `GW-A` head-response, coupling-accuracy or convergence result.

## 2. GW-A scientific role

`GW-A` is the smallest groundwater system that still has a real, auditable dynamic state.

It exists to separate coupling-method behaviour from MODFLOW-specific complexity. Its head response must be analytically transparent so that:

- every trial can be independently recomputed;
- same-origin replay can be distinguished from candidate-history continuation;
- coupling-window and outer-iteration effects can be studied without hidden groundwater numerics;
- a strict `GC-REF` can later be constructed cheaply;
- feedback strength can be varied through declared physical parameters rather than opaque scripted responses.

GW-A is intentionally a linear storage reservoir. Nonlinearity in early `PUB-GC` experiments is expected primarily from the dynamic SWAP response to groundwater head, not from an unnecessarily complex groundwater model.

## 3. Sign, unit and state conventions

The existing SWAP5 groundwater interface convention remains authoritative:

- `Q_swap_out_m > 0`: integrated water depth leaves SWAP through the lower boundary and enters groundwater;
- `q_groundwater_out_m_per_s > 0`: groundwater-side flux is outward from groundwater;
- therefore the accepted action/reaction relation is `q_groundwater_out = -q_swap_out` after consistent conversion to common units.

GW-A state is

```text
G = (h_m, t_day, revision, lineage)
```

where:

- `h_m` is groundwater hydraulic head in the common coupling datum, metres;
- `t_day` is canonical model time in days;
- `revision` is the accepted-state revision;
- `lineage` identifies one groundwater state lineage.

GW-A configuration contains at minimum:

```text
A_m2          cell/reference area [m2], A_m2 > 0
Sy            dimensionless drainable storage / specific yield, 0 < Sy <= 1
h_ref_m       fixed reference head used only to express storage volume
q_ext_in_mps  optional prescribed external source, positive into groundwater
```

For the initial E1 same-origin experiment, `q_ext_in_mps = 0` unless a later manifest explicitly declares otherwise.

The linear storage relation is

```text
C_gw = Sy * A_m2                         [m3 / m]
V_gw(h) = C_gw * (h_m - h_ref_m)         [m3]
```

Only storage differences are physically used. `h_ref_m` does not create or remove water.

## 4. Exact finite-window update

For a coupling window `[t0, t1]` in canonical days,

```text
dt_s = (t1 - t0) * 86400
```

and for a groundwater outward mean flux `q_groundwater_out_m_per_s`, the integrated groundwater volume change is

```text
DeltaV_gw = A_m2 * (q_ext_in_mps - q_groundwater_out_m_per_s) * dt_s
```

so the candidate head is

```text
h_candidate_m = h_origin_m + DeltaV_gw / (Sy * A_m2)
```

or equivalently

```text
h_candidate_m = h_origin_m
              + (q_ext_in_mps - q_groundwater_out_m_per_s) * dt_s / Sy
```

With no external source and exact action/reaction,

```text
h_candidate_m = h_origin_m + Q_swap_out_m / Sy
```

where `Q_swap_out_m` is the integrated SWAP lower-boundary transfer expressed as metres of water depth.

Consequences that must hold:

- positive recharge from SWAP raises GW-A head;
- capillary rise into SWAP lowers GW-A head;
- zero net exchange leaves head unchanged;
- area-normalized head response is independent of `A_m2`, while absolute transferred volume remains `A_m2 * Q_swap_out_m`.

There is no internal GW-A timestep. The finite-window storage update is analytic for the declared constant mean exchange over that trial.

## 5. Transactional candidate semantics

GW-A must implement accepted-state separation explicitly.

### Capture

A capture operation creates an immutable checkpoint containing at least:

```text
service_id
lineage_id
revision
accepted_h_m
accepted_t_day
configuration_identity
```

The checkpoint is a state snapshot, not merely a positive token.

### Trial

A trial:

1. validates that the checkpoint belongs to the same service/lineage/configuration;
2. validates that the window begins at the checkpoint time;
3. computes `h_candidate_m` from the checkpoint state and the declared window exchange;
4. creates a candidate object/token bound to that checkpoint and window;
5. does **not** mutate accepted `h_m`, `t_day` or `revision`.

Repeating the same trial from the same checkpoint with the same exchange must produce bitwise-identical or explicitly roundoff-equivalent candidate state according to the implementation contract.

### Discard

Discard removes only the candidate. Accepted state remains unchanged.

### Prepare and commit

Prepare validates candidate ownership and publication readiness without changing accepted state.

Commit of a prepared candidate atomically publishes:

```text
h_m      := h_candidate_m
t_day    := t1
revision := revision + 1
```

A candidate may be committed at most once. Rejected, discarded or superseded candidates may never change accepted state.

## 6. Same-origin mode and diagnostic contaminated mode

The normal `GW-A` service implements only correct same-origin transactional semantics.

The deliberately history-contaminated comparator required by `PUB-GC-E1` is a **research harness policy**, not an alternative groundwater production service.

Stable identifiers:

- `GC-ORIGIN-SAME`: every competing SWAP and GW-A candidate over one accepted window starts from the frozen accepted `(X^n, G^n)` origin;
- `GC-ORIGIN-HISTORY-DIAG`: candidate `k+1` deliberately starts from the endpoint state generated by candidate `k`, without accepting that state as the coupled solution.

`GC-ORIGIN-HISTORY-DIAG` exists only to expose what operator is evaluated when candidate history is allowed to contaminate the state. It must never be described as a recommended coupling algorithm.

For a fair E1 comparison:

- the candidate-head sequence is identical between origin policies;
- forcing, SWAP parameters, GW-A parameters and window are identical;
- only the origin policy changes;
- at least one repeated candidate appears after a different preceding candidate;
- candidate order is permuted in a second sequence;
- no diagnostic-history result is committed to production/canonical state.

## 7. Minimum GW-A qualification before E1

Before any `PUB-GC-E1` run is labelled prospective primary evidence, a research-only GW-A implementation must independently establish:

1. zero exchange leaves `h` exactly unchanged;
2. positive groundwater-outward exchange lowers `h` by the analytic amount;
3. negative groundwater-outward exchange raises `h` by the analytic amount;
4. positive SWAP-outward exchange and paired groundwater exchange satisfy exact action/reaction accounting;
5. repeated trial from one immutable checkpoint gives identical candidate head;
6. trial/discard does not mutate accepted head/time/revision;
7. prepare without commit does not mutate accepted state;
8. one prepared commit advances head/time/revision exactly once;
9. stale revision/lineage/configuration checkpoint is rejected fail-closed;
10. O0/O2 builds produce identical scientific-oracle output where the surrounding research harness uses compiled Fortran.

These checks qualify the research component. They do not themselves support H1, H2, H3 or H4 as publication results.

## 8. E1 pre-registration boundary

`PUB-GC-E1` may be preregistered only after all of the following exist:

- a frozen GW-A implementation commit and source blob;
- green GW-A research-component qualification evidence;
- an explicit research harness capable of evaluating both `GC-ORIGIN-SAME` and `GC-ORIGIN-HISTORY-DIAG` without modifying production semantics;
- a frozen SWAP authority and case/input authority;
- a frozen candidate-head sequence and order permutation;
- declared primary metrics and null/falsifying interpretation.

The first E1 run must not be used to choose the candidate sequence or stress case after inspecting the outcome. Exploratory case-finding, if needed, must be separately labelled supporting/screening evidence.

## 9. E1 primary metrics

For each candidate evaluation preserve at minimum:

```text
accepted_origin_id
origin_policy
candidate_sequence_id
candidate_index
prescribed_interface_head_m
SWAP_whole_window_exchange_m
SWAP_endpoint_state_digest
GW_A_origin_head_m
GW_A_candidate_head_m
GW_A_integrated_volume_change_m3
head_residual_m
candidate_accepted_or_discarded
```

Primary H1 discriminants are:

- difference in SWAP whole-window exchange for the same prescribed interface head after different candidate histories;
- difference in endpoint SWAP state for the same prescribed interface head after different candidate histories;
- candidate-order dependence under the history-contaminated diagnostic policy;
- repeatability/order independence under `GC-ORIGIN-SAME`.

GW-A head is a transparent consequence of the corresponding exchange and provides an independent analytic check, not an extra source of opaque nonlinearity.

## 10. Null and falsifying outcomes

The design explicitly permits unfavorable outcomes.

Examples:

- if same-origin and history-contaminated evaluations are numerically indistinguishable in all predeclared transient regimes, the practical H1 claim must be narrowed;
- if differences arise only because the diagnostic comparator changes more than origin state, the experiment is invalid rather than supportive;
- if GW-A itself cannot reproduce its analytic storage relation under the research harness, E1 is blocked;
- if meaningful discrimination requires response/tangent acceleration, that result belongs to `PUB-RC`, not to a rewritten `PUB-GC` H1 claim.

## 11. Explicit nonclaims

GW-A does not establish:

- field realism or groundwater-model calibration;
- MODFLOW 6 correctness or transferability;
- superiority of SWAP5 architecture;
- Newton versus RossFast solver performance;
- hydrologic value of N:1 heterogeneity;
- regional groundwater-flow behaviour;
- publication support for H1 merely because the GW-A component qualification passes.

Those questions remain owned by their existing publication or capability workstreams.
