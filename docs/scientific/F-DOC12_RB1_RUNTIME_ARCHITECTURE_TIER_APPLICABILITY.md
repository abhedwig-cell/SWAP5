# F-DOC12 — RB1 Runtime Architecture T0–T7 Applicability & State-Transition Authority

## Scope

F-DOC12 is a documentation-only follow-on to `F-DOC11@df438f8d0eaa4117e3e6df13a7061985fe233a16`. F-DOC11 decomposed the remaining controlled-theory/formal gap and classified nine RB1 capabilities as `RUNTIME_ARCHITECTURE`, while deliberately resolving zero T0–T7 tiers itself.

F-DOC12 reviews exactly those nine runtime capabilities:

- `RB1-CORE-INTERVAL`;
- `RB1-CORE-DATA`;
- `RB1-CORE-TRANSACTION`;
- `RB1-CORE-DIAGNOSTICS`;
- `RB1-STANDALONE-N1`;
- `RB1-MULTISWAP-SERIAL`;
- `RB1-MULTISWAP-PARALLEL-V1`;
- `RB1-RESTART-SERIAL`;
- `RB1-RESTART-PARALLEL`.

It does not address the physical-science, numerical-method or hybrid families. It changes no production source, reference data, physics, solver, scientific tolerance, mass criterion, temporal acceptance or performance policy.

The machine-readable authority is `docs/scientific/registries/rb1-runtime-architecture-tier-applicability.json`.

## Applicability rule

F-DOC01 defines a mandatory T0–T14 spine and explicitly permits `NOT_APPLICABLE` only with rationale. F-DOC12 applies that rule rather than forcing runtime infrastructure into a fictitious physical-science chain.

For pure runtime topology, data ownership, persistence and observability capabilities:

- T0 and T1 are `NOT_APPLICABLE` when the capability introduces no physical phenomenon or scientific theory. Physical science is inherited from the composed process capabilities and is not duplicated here.
- T2 and T3 can be applicable where the runtime capability has a controlled conceptual model, ownership model, state-transition system or formal identity/isolation invariant.
- T4 and T5 are `NOT_APPLICABLE` where runtime composition selects or changes no physical formulation.
- T6 is applicable when the runtime capability defines interval partitioning, batching, worker partitioning or committed split-run boundaries. This does not reclassify runtime scheduling as physical discretisation.
- T7 is applicable only if the capability itself defines a numerical acceptance or solver method. Worker-count admission, deterministic scheduling and persistence are runtime policy and may not silently become numerical-method authority.

This distinction preserves the architecture invariant that physical options and solver policy remain separate.

## Four carried core capabilities

F-DOC03 already contained explicit T0–T7 dispositions for four runtime capabilities. F-DOC12 does not rewrite their scientific meaning.

`RB1-CORE-INTERVAL` retains T0–T5 as not applicable, T6 as the controlled generic `[t0,t1]` interval partition (`SW5-DISC-7301`) and T7 as not applicable because acceptance/retry policy is owned elsewhere.

`RB1-CORE-DATA` retains T0–T7 as not applicable: explicit state/forcing/numerical-config/result ownership is architecture, not a new physical or numerical method.

`RB1-CORE-TRANSACTION` retains T0–T6 as not applicable and T7 as the controlled checkpoint/trial/reject/retry/commit acceptance method (`SW5-NUM-7301`).

`RB1-CORE-DIAGNOSTICS` retains T0–T7 as not applicable: deterministic diagnostics observe execution and numerical behaviour but do not define new physics or a solver.

These are carried dispositions from `F-DOC03@0c25d97bd180378a916fbb14a1e45768af9ec63a`, not new scientific claims.

## Standalone N=1 and serial MultiSWAP

The frozen RB1 runtime represents standalone N=1 as cardinality one of the same serialized physical MultiSWAP path. `fmr_logical_column_t` keeps column, template, parameter, state and forcing identities explicit. `fmr_run_serialized_physical_multiswap` executes a deterministic ordered set of logical columns over caller-supplied `[t0,t1]` and partitions that order into batches.

Therefore F-DOC12 resolves:

- T2 as the logical-column composition model;
- T3 as explicit identity/isolation/equivalence invariants;
- T6 as deterministic runtime partitioning over generic model time.

T0/T1/T4/T5 remain not applicable, and T7 is not applicable to the topology because the numerical solver and transaction acceptance method are inherited from the composed kernel capabilities.

This confirms that N=1 is not a separate SWAP kernel.

## Parallel MultiSWAP V1

The parallel worker pool keeps logical-column identity and authoritative committed state separate from worker-local execution resources. RB1 admits the restricted 2/4-worker route. Assignment and publication are deterministic, and each worker executes the admitted serialized physical column route with worker-owned backend/transaction context.

F-DOC12 therefore resolves:

- T2 as worker/column ownership and shared-reference composition;
- T3 as unique state ownership, deterministic assignment/publication and equivalence invariants;
- T6 as the admitted deterministic 2/4-worker execution partition and batch barriers over generic `[t0,t1]`.

T7 remains not applicable to the parallel topology itself. The worker-count restriction is an admitted runtime policy, not a new Richards/nonlinear/linear solver or scientific tolerance.

No parallel speedup or throughput superiority is claimed.

## Serial and parallel restart

`mod_fmr_committed_restart` defines a serialization-neutral continuation representation. The persistent record contains committed physical continuation state plus stable identity. Immutable parameter payloads, forcing, worker scratch, Newton vectors, Jacobians and warm starts are excluded. Restore validates schema, template, parameter and state-family identity into candidate states and publishes the target registry only after all records succeed.

F-DOC12 resolves for serial restart:

- T2 as the compact committed-continuation concept;
- T3 as sufficiency/identity/atomic-publication invariants;
- T6 as a split-run boundary at committed model time, independent of calendar-day boundaries.

For parallel restart the same continuation state is independent of worker identity. RB1 qualification already includes admitted 2→4 and 4→2 continuation. Thus T2/T3/T6 additionally cover worker-independent continuation and repartition without changing restored physical state.

Restart itself defines no post-restore numerical solver, so T7 is not applicable. Deterministic continuation equivalence remains verification/qualification evidence, not invented numerical theory.

No filesystem format, cross-version migration, mid-transaction restart, trial-state persistence or scratch persistence is claimed.

## Result

For the nine `RUNTIME_ARCHITECTURE` capabilities, all T0–T7 tiers now have an explicit bounded disposition: either `RESOLVED` under controlled runtime/state semantics or `NOT_APPLICABLE` with rationale. Four capability dispositions are carried from F-DOC03 and five are materialised here from frozen source and already-qualified execution/restart behaviour.

This closes only the runtime-family portion of `GAP-CONTROLLED-THEORY-FORMAL`. It does **not** make any capability `FULLY_TRACED` and does not establish Status A readiness. In particular, complete T11 graphs and T12 validation/applicability remain governed by their existing gap state.

## Hard nonclaims

F-DOC12 does not:

- reopen immutable RB1 science, qualification or release authority;
- alter production source or reference data;
- alter physics, solver, tolerances, mass criteria, temporal acceptance or performance policy;
- infer physical-process theory from runtime implementation or release PASS evidence;
- resolve the physical-science, numerical-method or hybrid authority families;
- select a universal `H_budget`, temporal tolerance or groundwater-head accuracy budget;
- claim `FULLY_TRACED`, Status A readiness, Status A compliance or Status AA compliance;
- claim surface-evaporation throughput/scaling or resolve its call-local allocation performance work.
