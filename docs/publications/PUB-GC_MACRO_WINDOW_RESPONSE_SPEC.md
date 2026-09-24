# PUB-GC macro-window SWAP response qualification specification

Status: **frozen before implementation**

Publication owner: `PUB-GC`

Affected experiments: `PUB-GC-E2`, `PUB-GC-E3`

Design authority:
`docs/publications/decisions/PUB-GC_E2_E3_MACRO_WINDOW_ADJUDICATION.md`

This specification defines research infrastructure only. It creates no H2 or H3 result.

## 1. Purpose

Provide a research-only SWAP response operator that retains native subsystem time integration **inside** an external coupling macro-window.

The operator must make these two time scales independent:

- coupling macro-window duration `DeltaT_c`;
- native SWAP integration intervals `delta_t_j`.

For one candidate interface head, the operator returns:

- the integrated lower-boundary exchange summed across native contributions;
- the final native lower-boundary flux;
- the physical endpoint state after the final native interval;
- provenance sufficient to prove same-origin replay and accepted-origin isolation.

No production source or production coupling policy is changed.

## 2. Frozen implementation base

Research branch to create:

`research/pub-gc-macro-window-response`

Base:

`research/pub-gc-reference-screening@c48ad3e09a7ab373e3ee424ae90fabbb65e83e4f`

Frozen production source tree:

`d7ef6c045263de821db7800459289efcd8a6420b`

Allowed mutations:

- `tests/publication/pub_gc/macro_window_response/**`
- `.github/workflows/pub-gc-macro-window-response-qualification.yml`

Forbidden mutations include:

- `src/**`;
- qualified `GW-A` bytes;
- qualified E1 origin/primary-engine bytes;
- qualified E2 comparator bytes;
- qualified `GC-REF-A` bytes;
- existing reference-screening bytes;
- existing transient-screening bytes.

The implementation may depend on qualified publication components but may not alter them.

## 3. State semantics

### 3.1 Authoritative macro origin

Input is an already accepted `kernel_committed_state_t` at macro time `t_n`.

The macro operator must never commit a native internal candidate to this authoritative object.

Before any candidate trajectory:

1. call the public committed-state `snapshot()`;
2. obtain the accepted committed time through the public API;
3. initialize a new disposable `kernel_committed_state_t` with:
   - a distinct positive research lineage;
   - the cloned dynamic transaction-state object;
   - the same committed time.

Because the snapshot preserves its dynamic type, a Richards temporal-indicator state retains its cloned continuation history.

No trusted reconstruction API is permitted.

### 3.2 Disposable native trajectory

The disposable committed state may advance through ordinary public transaction operations.

For internal interval `j`:

1. capture a checkpoint from the disposable state;
2. execute the already qualified serialized B1.10 trial for `[t_j,t_{j+1}]`;
3. use the same macro candidate interface head;
4. use the frozen forcing applicable to that native interval;
5. require valid whole-step mass/interface telemetry;
6. commit that candidate **only to the disposable lineage** through the normal commit-with-receipt route;
7. retain its lower-boundary exchange contribution and terminal lower-boundary flux.

Internal commits mean “accepted within this disposable subsystem integration trajectory”. They are not publication of coupled model state.

After the macro response has been extracted, the disposable lineage is discarded.

## 4. Macro response definition

For

`I_n = [t_n,t_n + DeltaT_c]`

partitioned into native intervals

`I_{n,j}`, `j=1,...,m`,

with

`sum_j delta_t_j = DeltaT_c`,

define:

```text
Q_whole = sum_j Q_j
```

where `Q_j` is the native SWAP `bottom_outward_exchange_native` for internal contribution `j`.

Define:

```text
q_terminal = q_terminal,m
```

from the final native contribution only.

For the existing E2 comparator:

```text
Q_terminal = q_terminal * DeltaT_c
```

The macro endpoint state is the physical/continuation endpoint of the disposable state after contribution `m`.

## 5. Required public result surface

The research component must make available, directly or through a returned result object:

- `completed`;
- `macro_t0`;
- `macro_t1`;
- `macro_duration_day`;
- `native_contribution_count`;
- each `delta_t_j`;
- each `Q_j`;
- each internal terminal flux;
- `Q_whole`;
- `q_terminal`;
- `Q_terminal`;
- `Q_whole - Q_terminal`;
- endpoint state snapshot;
- disposable lineage final revision;
- authoritative origin lineage/revision/time before and after;
- candidate interface head;
- required transaction retry/temporal diagnostics.

No hidden averaging of terminal flux is allowed.

## 6. Same-origin rule

Every macro candidate head evaluated for the same outer coupling window must create a fresh disposable trajectory from the same authoritative macro origin snapshot.

Candidate B may never start from the disposable endpoint of candidate A.

A/B/A replay from one accepted macro origin must therefore reproduce A exactly.

## 7. Qualification fixtures

Qualification fixtures are infrastructure-only and permanently excluded from later H2/H3 primary effect estimation.

### Q0 — one-contribution reduction

Use one native contribution over one macro-window.

Require bitwise identity between:

- the new macro response; and
- the pre-existing direct one-step SWAP trial,

for:

- endpoint state;
- `Q_whole`;
- `q_terminal`;
- mass/interface telemetry.

Also require `Q_whole = Q_terminal` for this fixture.

Purpose: prove that the new operator does not change one-step science.

### Q1 — sequential equivalence

Use at least four native intervals with constant candidate head.

Run the same native intervals through:

1. the macro operator; and
2. an independently coded disposable sequential reference path using the same public SWAP transaction contracts.

Require exact equality of:

- contribution sequence `Q_j`;
- final terminal flux;
- aggregate `Q_whole`;
- endpoint state;
- final disposable revision.

### Q2 — aggregate/terminal selectivity

Use a qualification-only forcing schedule that changes across native intervals.

Require:

- at least two finite native exchange contributions;
- `Q_whole` exactly equals the explicit sum of `Q_j`;
- returned `q_terminal` exactly equals the last contribution's terminal flux;
- `Q_terminal = q_terminal * DeltaT_c`;
- `abs(Q_whole-Q_terminal)` exceeds a qualification-only numerical discrimination floor frozen in the qualification manifest.

The numeric values observed here may not be reused to select primary stress amplitudes.

### Q3 — same-origin A/B/A

From one authoritative macro origin:

- evaluate candidate head A;
- discard its disposable trajectory;
- evaluate B;
- discard;
- evaluate A again.

Require bitwise identical A responses and endpoint snapshots.

### Q4 — authoritative-origin isolation

Before and after every qualification response, require exact equality of authoritative:

- lineage;
- revision;
- committed time;
- physical/continuation snapshot.

### Q5 — continuation-history preservation

Use an authoritative origin whose dynamic state is `fmr_b110_temporal_indicator_state_t` with available nontrivial temporal history.

Clone through public `snapshot()` and `initialize()`.

Require that the disposable first native trial is equivalent to a separately executed same-origin trial that uses the authoritative continuation state.

A qualification implementation may additionally inspect temporal-history availability through its public snapshot API, but it may not access private state.

### Q6 — failure isolation

Demonstrate fail-closed behavior for at least:

- nonpositive macro duration;
- nonpositive native interval;
- native intervals that do not sum to the macro duration within a frozen arithmetic tolerance;
- nonfinite candidate head;
- a native SWAP trial failure;
- a failed internal commit receipt.

No partial macro response may be marked complete.

### Q7 — O0/O2 identity

All qualification oracle output must be byte-identical under O0 and O2.

## 8. E2 composition qualification

After Q0-Q7 pass, compose the macro response with the already qualified terminal-flux comparator and GW-A.

For one qualification-only multi-contribution response require:

- whole arm uses `Q_whole`;
- terminal arm uses `q_terminal * DeltaT_c`;
- both groundwater trials begin from the same GW-A macro checkpoint;
- neither groundwater arm commits;
- whole-arm action/reaction closes exactly;
- terminal-arm signed interface mismatch equals `Q_whole-Q_terminal`;
- accepted SWAP macro origin remains unchanged.

This qualification demonstrates wiring only.

## 9. GC-REF-B composition rule

The existing derivative-free `GC-REF-A` bisection algorithm may be reused unchanged as a root-search algorithm.

For `GC-REF-B`, each residual evaluation must call the macro response:

```text
S_macro(h) -> Q_whole(h), X_endpoint(h)
```

then evaluate GW-A from the unchanged macro checkpoint using `Q_whole(h)`.

Every residual evaluation starts from the same accepted SWAP and GW macro origins.

Only after the root is accepted may the macro endpoint and paired groundwater candidate be published into the **research reference trajectory**.

No tangent, Newton, secant, Broyden or Aitken method is permitted in GC-REF-B. Response acceleration belongs to `PUB-RC`.

## 10. Native integration adequacy gate

A macro operator can separate time scales only if the internal SWAP policy is itself frozen independently of the H2 effect.

Before new E2/E3 scientific screening, run a separately preregistered supporting study:

`PUB-GC-NATIVE-TIME-0001`.

Its purpose is **not** to maximize `Q_whole-Q_terminal`.

It must choose a native integration policy using subsystem-state/exchange convergence only.

The study must:

1. use qualification/screening cases that are permanently ineligible for H2/H3 primary evidence;
2. freeze an internal-step ladder before execution;
3. compare endpoint SWAP state and integrated exchange across that ladder under prescribed macro head/forcing histories;
4. freeze accuracy thresholds before execution;
5. select the coarsest internal policy that satisfies all frozen adequacy criteria, or fail closed if none does;
6. never use terminal-surrogate mismatch as the selection objective.

The selected policy is then frozen for the principal E2/E3 coupling-window ladder.

## 11. E3 temporal isolation

Once the native policy is qualified, future H3 screening must vary `DeltaT_c` while preserving that internal policy.

Coupling windows should be integer compositions of qualified native intervals where practical.

Forcing switch times must remain common across all coupling-window levels.

Any separate internal-step sensitivity analysis must be reported as such and not interpreted as coupling-window convergence.

## 12. Qualification telemetry

Persist:

```text
qualification_id
research_head
source_tree
macro_t0
macro_t1
candidate_head
native_interval_count
native_interval_durations
per_interval_Q
per_interval_terminal_flux
Q_whole
q_terminal
Q_terminal
whole_minus_terminal
endpoint_state_digest_or_exact_oracle
authoritative_origin_lineage_before_after
authoritative_origin_revision_before_after
authoritative_origin_time_before_after
disposable_lineage
disposable_final_revision
transaction_retries_per_interval
O0_output_hash
O2_output_hash
```

## 13. Admission boundary

A PASS qualifies only the research macro-window response infrastructure.

It does **not** establish:

- H2;
- H3;
- practical coupling-window limits;
- whole-window superiority;
- any MODFLOW 6 result;
- production admission of a new SWAP execution path;
- response/tangent acceleration;
- a new Richards solver result.

## 14. Next permitted action after this specification

1. create `research/pub-gc-macro-window-response` from the frozen base;
2. implement only the macro response and independent qualification oracle;
3. qualify Q0-Q7 under O0/O2;
4. persist a qualification receipt;
5. then freeze `PUB-GC-NATIVE-TIME-0001` before any new E2/E3 screening.
