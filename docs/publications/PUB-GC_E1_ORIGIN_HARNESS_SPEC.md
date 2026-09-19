# PUB-GC E1 origin-policy harness specification

Status: **frozen research-harness specification; implementation qualification pending**

Publication owner: `PUB-GC`

Purpose: define, before implementation and before any `PUB-GC-E1` claim run, how the real SWAP prescribed-head execution surface is evaluated under (a) correct same-origin replay and (b) a deliberately history-contaminated diagnostic policy.

This harness is publication research infrastructure only. It does not add a second production runtime, does not alter transaction or commit semantics, and does not create a supported coupling algorithm called “history contaminated”.

## 1. Authorities consumed

### Real prescribed-head SWAP primitive

Historical qualification authority:

- F-VQ26 candidate: `9b967d033be7c95690de621b2cb1768ba9224c7f`;
- test: `tests/fvq/test_fvq26_prescribed_bottom_head_runtime_v2.f90`;
- test blob: `05002e0e084c21f90e7a97351df3ff8143666948`;
- qualification branch/head: `qualification/f-vq26-fmr11-prescribed-bottom-head-runtime@a1d5ad9147e18301f68183822577b1ba8fca3de2`.

The qualified primitive uses the serialized B1.10 physical backend with bottom mode 5, a prescribed lower-boundary head, a reusable checkpoint, a real solver-produced lower-boundary result, and candidate discard. It includes A/B/A replay and verifies that discarded trials leave the committed origin unchanged.

### Reusable physical checkpoint / candidate snapshot semantics

Historical F-KT05 authority:

- source checkpoint commit: `278e1b0bf44a391059fdcdd72576e24e966e95f1`;
- tested postimage: `f7d2ee5e81f1d6686c96114984239e97ba6a8a8a`;
- qualification evidence: `6911549acbcb62ef8af9ae2d96d5b4f938daf1e2`;
- qualification run: `34125537033`.

The bounded admitted contract is:

- a checkpoint contains an immutable physical-state clone plus lineage/revision/time provenance;
- the same current checkpoint may seed repeated trials;
- checkpoint capture does not mutate committed state;
- a checkpoint cannot restore or publish committed state;
- candidate publication rules remain owned by F-KT;
- candidate physical state may be inspected only through its public cloned snapshot.

This specification does not promote F-KT05 beyond its qualified scope. In particular, its historical qualification was not itself a full real-B1.10 replay claim. E1 therefore independently qualifies the composed research harness against the current frozen source authority before any publication run.

### Transparent groundwater component

`GW-A` is frozen by `PUB-GC_GW-A_SPECIFICATION.md` and qualified by `PUB-GC-GW-A-QUAL-0001` at research head `8a090fc9228574525e599817771aadb8ae176047`.

## 2. Scientific object evaluated by E1

For one coupling window `I=[t0,t1]`, let the accepted SWAP physical state be `X0` and let `h_j` denote a prescribed groundwater/interface head candidate.

The correct SWAP response operator is

```text
R_same(h_j ; X0, I) -> (Q_j, X_j)
```

where every `h_j` is evaluated from the same immutable accepted origin `X0` over the same nominal window `I`.

`Q_j` is the authoritative whole-window lower-boundary exchange when available from the frozen runtime result. `X_j` is a cloned physical candidate endpoint used only for diagnostics and state-digest comparison unless a separately admitted production transaction commits it.

The deliberately contaminated diagnostic operator is recursive:

```text
X_diag,0 = X0
R_diag(h_1 ; X_diag,0, I) -> (Q_1, X_diag,1)
R_diag(h_2 ; X_diag,1, I) -> (Q_2, X_diag,2)
...
```

The crucial distinction is that `X_diag,j` is physically the previous candidate endpoint, but is relabelled as a fresh **research-only lineage at nominal t0** before evaluating the next candidate over `I`.

Therefore `R_diag` is not a physically valid repeated-time integration and not a production coupling algorithm. It is an adversarial diagnostic that makes candidate-history contamination explicit.

## 3. Stable policy identifiers

### `GC-ORIGIN-SAME`

For every candidate:

1. keep the original accepted SWAP committed carrier unchanged;
2. reuse one immutable checkpoint captured from that accepted origin, or capture an equivalent clone proven identical by the harness oracle;
3. set only the prescribed interface head for the candidate;
4. run the real prescribed-head physical trial over the same `[t0,t1]`;
5. record authoritative whole-window exchange and physical endpoint digest;
6. clone the candidate endpoint for diagnostics if required;
7. discard the candidate;
8. require committed lineage, revision, time and physical state to remain unchanged.

Candidate order may not alter `R_same(h_j)` except for explicitly bounded numerical roundoff/nonphysical worker-local warm-start effects. The harness qualification will use exact replay cases where bitwise identity is expected from the frozen route.

### `GC-ORIGIN-HISTORY-DIAG`

For candidate 1, start from the same accepted `X0` as `GC-ORIGIN-SAME`.

After candidate `j`:

1. obtain a physical clone only through `kernel_candidate_state_t%snapshot()`;
2. discard/retire the original candidate according to the normal transaction contract;
3. create a new research-only `kernel_committed_state_t` from that cloned physical state using the public initialization contract;
4. assign a new positive research lineage id;
5. bind its nominal committed time to the original `t0`, not to `t1`;
6. capture a checkpoint from that synthetic research origin;
7. evaluate candidate `j+1` over the same nominal `[t0,t1]`.

This is the only permitted temporal relabelling. It occurs by constructing a new research carrier from a cloned physical state. It must **not**:

- mutate the time/revision/lineage of an existing committed carrier;
- invoke a trusted persistence/reconstruction API to forge production provenance;
- publish a candidate through the production commit path merely to obtain the next diagnostic origin;
- access private candidate/checkpoint state;
- alter SWAP process equations, solver equations, forcing semantics or transaction semantics.

Every synthetic lineage is diagnostic and disposable.

## 4. Why a new lineage is mandatory

The diagnostic deliberately combines a physical endpoint associated with `t1` with the nominal time label `t0`. Reusing the original lineage would falsely imply that F-KT accepted this state as a legitimate revision of the same physical history.

A new research lineage makes the discontinuity explicit and ensures that production stale-revision/time guards are not weakened to support the experiment.

The harness must preserve a telemetry flag:

```text
synthetic_origin = true
synthetic_origin_reason = HISTORY_CONTAMINATION_DIAGNOSTIC
source_candidate_sequence_index = j
```

No synthetic origin is eligible for production publication.

## 5. Real SWAP execution surface

The harness shall reuse the existing public prescribed-head route rather than introduce a duplicate Richards implementation.

Minimum frozen semantics:

- serialized reference physical backend;
- prescribed bottom head, existing mode-5 semantics;
- existing physical parameter/state/forcing types;
- existing kernel/FMR checkpoint and trial route;
- real solver execution, not a scripted response;
- whole-window bottom exchange from the runtime result when the frozen current source exposes `bottom_interface_exchange_available` / `bottom_outward_exchange_native`;
- terminal bottom flux retained only as diagnostic/comparator telemetry, not substituted for whole-window exchange;
- physical endpoint extracted only through the public candidate snapshot.

Any current-source drift relative to F-VQ26 must be reconciled and frozen in the harness qualification receipt. Historical F-VQ26 evidence is design precedent, not automatic qualification of a later moving source head.

## 6. Harness qualification before screening or E1 preregistration

A research-only implementation must establish all of the following on one frozen source head:

1. `GC-ORIGIN-SAME` A/B/A produces the same response for repeated A from the same accepted origin;
2. the accepted SWAP committed state remains bitwise/contract-identical after all same-origin trials;
3. candidate endpoint snapshots are physical clones and changing/discarding the candidate cannot mutate an already captured clone;
4. construction of a synthetic diagnostic carrier uses only public snapshot + initialize APIs;
5. every synthetic diagnostic carrier has a distinct research lineage and nominal time exactly `t0`;
6. no production commit is invoked in the history-diagnostic path;
7. production `src/**` is unchanged by the research work unit;
8. unsupported or unavailable prescribed-head execution fails closed;
9. authoritative whole-window exchange is available and finite for every admitted harness trial used later by E1;
10. O0/O2 scientific-oracle output is identical where exact identity is supported by the frozen route, otherwise any accepted difference must be frozen before publication runs and justified numerically;
11. GW-A remains independently qualified and is consumed without modification of its scientific equation;
12. the history diagnostic is explicitly labelled invalid for production/physical trajectory interpretation in machine-readable output.

These checks qualify the ability to run the comparison. They do not establish H1.

## 7. Screening boundary

After harness qualification, a separately labelled screening phase may search for a transient real-SWAP case that produces measurable state/history sensitivity.

Screening may vary, within predeclared broad physical bounds:

- accepted initial pressure-head profile;
- wetting/drying forcing;
- coupling-window duration;
- candidate-head spacing;
- GW-A `Sy` / feedback strength if GW-A is already part of the screening loop.

Screening results may select the later E1 stress regime but are not primary evidence.

The final primary candidate sequence, order permutation, case/input authority and metrics must be frozen in a new manifest **after screening and before primary execution**.

## 8. Minimum primary sequence design

The future primary E1 manifest must include at least:

```text
Sequence S1: A, B, A, C
Sequence S2: A, C, A, B
```

or an equivalent predeclared permutation with:

- at least three distinct candidate heads;
- one candidate repeated after a different preceding candidate;
- identical candidate values under both origin policies;
- identical physical forcing/configuration/window under both origin policies.

The exact numeric heads are intentionally **not** frozen by this harness specification. They belong to the later post-screening primary manifest.

## 9. Primary E1 observables

For each candidate evaluation preserve:

```text
run_id
case_id
source_head
origin_policy
sequence_id
candidate_index
prescribed_interface_head
accepted_origin_lineage
accepted_origin_revision
accepted_origin_time
synthetic_origin
synthetic_source_candidate_index
whole_window_bottom_outward_exchange
terminal_bottom_outward_flux
candidate_endpoint_digest
candidate_mass_residual
solver_iterations
candidate_disposition
GW_A_origin_head
GW_A_candidate_head
```

Primary H1 discriminants remain:

1. same prescribed head after different prior candidates: difference in whole-window SWAP exchange;
2. same prescribed head after different prior candidates: difference in endpoint SWAP physical state;
3. order dependence of those quantities under `GC-ORIGIN-HISTORY-DIAG`;
4. repeatability/order independence under `GC-ORIGIN-SAME`.

## 10. Interpretation guardrail

A positive E1 result means only that evaluating candidate responses from different physical origins can produce path-dependent coupling responses, while same-origin replay evaluates a well-defined response of one accepted state.

It must not be phrased as evidence that the deliberately contaminated diagnostic algorithm is a realistic or commonly used groundwater-coupling method.

A null result is admissible. If the predeclared transient cases show negligible differences, H1 must be narrowed to the formal reproducibility/operator-definition claim or the practical claim must be dropped.

## 11. Publication firewall

This harness does not claim:

- novelty of generic checkpoint/replay architecture;
- superiority of SWAP5 software architecture;
- Newton versus RossFast performance;
- response/tangent acceleration;
- MODFLOW 6 transferability;
- N:1 hydrologic heterogeneity value;
- that synthetic diagnostic lineages are valid hydrologic trajectories.

Those remain outside `PUB-GC-E1` or belong to the other publication lines.
