# F-SI31 — SoilWaterSolverResearchContract v1

Status: normative research-interface contract

Contract ID: `SoilWaterSolverResearchContract`

Contract version: `1.0.0` (`v1` major line)

Workunit: `F-SI31 — SWAP5 Research Soil-Water Solver Compatibility Contract Freeze`

Base production authority at workunit start: `integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`, tree `8d48f92612eb4a72469b99877ec5805ff2cd113a`.

Research governance authority: `regie/f-rg01a-parallel-research-isolation-contract-ownership-policy`, policy definition `33a94697e031d3003bf0812bff73bf8d30ef9d80`, closed by `4553204468695553cf69a48d1c97598c471156d6`.

## 1. Purpose and non-goals

This contract freezes one thin compatibility seam between SWAP5 production processes/runtime and independently evolving research soil-water solvers.

The intended composition is:

`SWAP5 production processes/runtime -> SoilWaterSolverResearchContract v1 -> research adapter -> research solver`

This contract does not define new soil-water physics, change RossFast algorithms, replace production Full Richards, transfer runtime ownership to a solver, or admit any research solver to production. Full Richards remains the production/reference authority.

The contract is a semantic research contract. It is not a copy of the current Fortran `soil_water_solver_contract_t` ABI. Current production structures are mapped into this contract by an adapter. In particular, v1 defines time as `[t0,t1]` rather than freezing the current `step_duration` implementation detail.

## 2. Versioning and no-canonical-chasing rule

`1.0.0` is frozen. Its semantics shall not be redefined in place.

Version policy:

- MAJOR changes are breaking semantic or ownership changes.
- MINOR changes are backward-compatible additions that remain optional for existing v1 consumers.
- PATCH changes are clarification or errata only and may not change required behaviour.

A solver compliant with v1 is not required to change merely because `integration/f-ci-canonical` advances. Compatibility with a later production interface, or production admission of a research solver, is a separate qualified workunit. A research solver shall pin this frozen contract or an explicitly qualified compatible successor instead of chasing current canonical.

## 3. Normative ownership model

The runtime owns transaction state and acceptance. A solver owns only computation of a candidate from an immutable trial base and worker-local scratch.

For every trial:

1. The committed hydraulic state supplied to the solver is read-only.
2. The solver creates or fills a distinct candidate/trial state.
3. The solver never commits that candidate to runtime state.
4. Runtime may accept and commit the candidate, reject it, or retry from the same committed base.
5. Rollback is candidate discard or replacement. It never requires inverse mutation of committed state.
6. Scratch, Newton vectors, Jacobians, factorizations, constitutive intermediates and warm-start caches are worker-local or job-local and are not persistent column state.
7. Immutable parameter data may be shared by stable ID/reference across columns and trials.
8. Hidden mutable global state is outside this contract and is non-compliant.

## 4. Problem input

A v1 trial request consists of five explicitly separated data categories. An implementation may encode them differently, but it shall preserve their ownership and semantics.

| Category | Minimum semantic content | Ownership |
| --- | --- | --- |
| Physical parameters | vertical grid/geometry; immutable hydraulic parameter identity/data; constitutive/provider identity; active physical options relevant to the soil-water solve | immutable, shareable |
| Committed state | pressure head, water content, surface/ponding state where active, groundwater-level state where part of the hydraulic continuation state | runtime-owned, read-only to trial |
| Forcing/process requests | interval `[t0,t1]`; top-boundary request or resolved provider result; bottom-boundary request; sink/source and root-sink requests/results; trial/retry context | runtime/process-owned input |
| Numerical configuration | tolerances, work limits, nonlinear/linear numerical policy, numerical mode selections, deterministic/replay policy | runtime-owned policy input |
| Scratch | Newton vectors, Jacobians/factorizations, temporary constitutive values, local warm starts | worker/job-owned; not part of request state or persistence |

`t1` shall be strictly later than `t0`. Day, month, year and midnight are not contract units. An adapter to a duration-based production solver may map `step_duration = t1 - t0` without changing the research contract.

Physical options and numerical policy shall remain distinct. A numerical policy may not silently change requested physics.

## 5. Solver result

A successful v1 invocation returns a `candidate_ready`, `retry_advised`, or `failed` solver disposition. `candidate_ready` is deliberately not called `accepted`: acceptance is a runtime transaction decision.

A result shall provide, when applicable to the declared capabilities:

- candidate hydraulic state;
- solver disposition and retry/failure classification;
- actual top flux and candidate bottom flux/exchange with declared sign convention;
- process-facing hydraulic view;
- storage change over `[t0,t1]`;
- mass-balance terms and unrounded mass residual;
- solver diagnostics envelope;
- optional sensitivity envelope.

Mass terms shall be sufficient for the runtime to verify conservation for the declared physics. A research or fallback status is never permission to relax mass conservation.

## 6. Boundary contract and capability matrix

Boundary support is capability-declared. Unsupported or restricted modes fail closed before any committed-state mutation.

| Research capability ID | Contract meaning | Current Full Richards mapping | RossFast evidence at freeze |
| --- | --- | --- | --- |
| `top.prescribed_flux` | prescribed/requested top flux through the production top-boundary provider seam | supported by the F-SI28 frozen top provider/request path | not independently qualified |
| `top.dynamic_provider` | dynamic top regime/provider evaluation without exposing solver internals | supported by the F-SI30 opt-in dynamic-top sibling | unsupported/unqualified |
| `bottom.prescribed_head` | prescribed bottom pressure/head, with resulting candidate bottom flux reported | reference binding bottom mode `5` | unsupported/unqualified |
| `bottom.prescribed_flux` | prescribed `qbot`, positive upward in current SWAP mapping | reference binding bottom mode `2`; optional F-SI28 sensitivity path when eligible | restricted research evidence from F-ROSS01 J1D/J1E only |
| `bottom.legacy_mode_7` | current reference legacy bottom mode `7` | supported by current reference/serialized path | unsupported/unqualified |
| `bottom.legacy_mode_minus2` | current reference legacy bottom mode `-2` | supported by current reference/serialized path | unsupported/unqualified |
| `bottom_exchange.candidate_flux` | solver reports trial bottom exchange; it becomes accepted exchange only after runtime commit | supported | supported conceptually in J1E transaction choreography, not production-qualified |

The current serialized reference runtime directly admits bottom modes `7`, `-2` and `5`. The reference Full Richards solver binding also supports prescribed-qbot mode `2`; that distinction shall not be collapsed into a claim that every runtime path admits qbot directly.

A research solver is not required to implement every boundary capability. It must declare support exactly and fail closed for unsupported requests.

## 7. Process hydraulic view

Production processes shall consume hydraulic information through a process-facing view, never through HeadCalc or other solver-internal arrays.

The minimum common hydraulic view is:

- pressure head;
- water content;
- ponding depth where active;
- groundwater level where represented by the hydraulic state.

Additional derived quantities, such as hydraulic conductivity, capacity, root-zone hydraulic information or other process-required sensitivities, may be exposed through declared provider/view capabilities. They shall not expose Newton vectors, tridiagonal work arrays, Jacobian storage, factorization layout, HeadCalc intermediates or other solver implementation details.

## 8. Transaction contract

The v1 transaction sequence is:

`checkpoint/committed base -> trial -> candidate -> runtime accept or reject -> commit or rollback -> optional retry`

Rules:

- the checkpoint/committed base is not mutated by a trial;
- retries start physically from the correct committed state, although worker-local numerical warm-start data may be reused when declared safe;
- a rejected trial leaves committed state bitwise/logically unchanged according to the runtime state contract;
- solver success does not itself imply runtime acceptance;
- commit ownership remains outside the research solver;
- deterministic replay from the same committed state, immutable parameters, forcing/process requests, numerical configuration and declared deterministic execution mode shall reproduce the same contract-visible result. If a solver cannot guarantee a stronger bitwise mode, it must declare its supported replay/quality level rather than silently weaken the rule.

## 9. Sensitivity seam

Sensitivity support is optional for research compliance and capability-declared.

The primary named interface quantity is:

`dh_bottom_dq_bottom = ∂h_b / ∂q_b`

A sensitivity result shall identify availability, value, scope, method and quality/validity. Unsupported is a valid research capability declaration.

The contract does not require a finite-difference production path. Current Full Richards authority may use the qualified same-factorization/backsolve path. A solver-local or terminal constitutive tangent shall not be labelled as the authoritative whole-window `∂h_b/∂q_b` unless a dedicated mapping proves that equivalence.

## 10. Diagnostics envelope

Every solver invocation shall expose enough diagnostics to distinguish successful, restricted, retried and failed routes. The minimum envelope contains:

- convergence/disposition status;
- nonlinear iterations or an equivalent declared work-unit metric;
- retry cause or failure classification;
- fallback/restricted-capability indicator;
- unrounded mass residual;
- temporal/solver quality indicator where applicable;
- execution route/solver identity sufficient for runtime diagnostics.

Additional counters such as Jacobian evaluations, linear solves, backtracking steps and sensitivity backsolves are recommended when meaningful.

## 11. Capability declaration and fail-closed rule

Every v1 research solver publishes a machine-readable capability declaration conforming to `F-SI31_SOIL_WATER_SOLVER_RESEARCH_CAPABILITY_SCHEMA_V1.json` or an explicitly qualified compatible schema.

The declaration covers at minimum:

- top and bottom boundary modes;
- physics assumptions and excluded physics;
- vertical-grid/geometry restrictions;
- constitutive-model support;
- sink/source and root-sink support;
- sensitivity support and exact scope;
- transaction support;
- restart support;
- temporal limitations and replay guarantees;
- process-hydraulic-view support.

An unsupported, undeclared, or out-of-range capability request fails closed before committed-state mutation. There is no implicit downgrade to a different physical problem.

## 12. Restart semantics

Restart is capability-declared and separate from trial scratch.

For a restart-compatible solver path, persistence consists only of committed physical continuation state plus stable identities/references needed to recover immutable parameter/provider data. Solver scratch, Jacobians, factorization state, rejected candidates and local warm-start caches are not required restart state and shall not become mandatory per-column persistent storage.

A research solver that has not qualified restart support declares it unsupported. That does not invalidate research-contract compliance, but it prevents claims of production restart compatibility.

## 13. Full Richards mapping

Current Full Richards maps to v1 without changing production physics or solver semantics:

- current `soil_water_parameter_set_t` maps to immutable grid/parameter input;
- current `base_state` maps to the read-only committed trial base;
- current `step_duration` is an adapter representation of `t1 - t0`, not the frozen time contract;
- current top providers map to `top.prescribed_flux` and, when selected, `top.dynamic_provider`;
- current bottom modes `5` and `2` map to prescribed head and prescribed flux respectively; reference legacy modes `7` and `-2` remain separately named capabilities;
- current candidate state and top/bottom flux outputs map to the v1 candidate result;
- `process_hydraulic_view_t` maps to the minimum process-facing hydraulic view;
- HeadCalc/Newton/factorization arrays remain worker-internal scratch;
- the qualified prescribed-qbot sensitivity path maps to optional `dh_bottom_dq_bottom` only when its production eligibility conditions hold;
- runtime/transaction layers remain responsible for candidate validation, acceptance, commit, rollback and accepted-only publication.

This mapping demonstrates representability. It does not make this research contract a replacement production ABI.

## 14. RossFast mapping at freeze

The existing F-ROSS01 research branch maps only a restricted subset of v1:

- candidate/trial ownership is compatible: J1E computes on a cloned candidate and does not self-commit;
- rollback/retry choreography is representable: the rejected candidate is discarded and retry starts from committed state;
- prescribed-qbot sign and local node-balance mapping are evidenced in J1D for the tested research setup and six tested materials;
- terminal candidate `q_bottom` is recomputed after stage updates and can populate `bottom_exchange.candidate_flux`;
- the existing local RossFast `dh_compute_cm/dqbot` is a local/terminal constitutive tangent only and does not satisfy the authoritative whole-window `dh_bottom_dq_bottom` capability;
- RossFast remains research evidence only. The mapping neither changes its algorithm nor establishes production equivalence.

At this freeze, RossFast shall therefore declare unsupported or restricted, as applicable: dynamic top boundary; general prescribed-head and legacy bottom modes; authoritative whole-window sensitivity; production restart compatibility; complete production process-hydraulic-view obligations; general sink/source and root-sink closure; full Richards nonlinear time stepping; heterogeneous-cell coupling; saturation handling; unrestricted grid/constitutive-model support; crop/no-crop process closure; production MultiSWAP/runtime admission; production/reference equivalence.

## 15. Compatibility checklist

A research solver is v1-compatible only if all applicable answers below are explicit:

1. Does it consume immutable physical parameters separately from state and numerical policy?
2. Is committed state read-only throughout a trial?
3. Does it return a distinct candidate and never self-commit?
4. Can rejection occur without inverse mutation of committed state?
5. Is scratch worker/job-local and excluded from persistent column state?
6. Are `[t0,t1]`, boundary requests and sink/source requests represented without calendar assumptions?
7. Are all supported boundary capabilities declared and all others fail-closed?
8. Are process quantities exposed without solver internals?
9. Are storage change and mass-balance terms sufficient for conservation checking?
10. Are retry/failure routes and solver work diagnosable?
11. Are optional sensitivities named with their exact scope and method?
12. Are restart and deterministic replay capabilities declared honestly?
13. Can the adapter reject unsupported production requests before committed-state mutation?
14. Is the solver prevented from claiming production/reference equivalence solely from v1 compliance?

## 16. Known intentional gaps

v1 deliberately does not standardize a single internal discretization, Richards formulation, nonlinear algorithm, factorization format, scratch layout, GPU/SIMD layout, constitutive implementation, crop implementation, drainage implementation or runtime scheduler.

v1 also does not require every research solver to support all production boundary modes, restart, interface sensitivities or all SWAP process combinations. Those are declared capabilities and future qualification obligations.

The contract freezes semantic ownership and exchange, not a performance ABI. Batching/SoA/pools remain implementation choices as long as contract-visible state and transaction semantics are preserved.

## 17. Invariant audit

| Invariant | Result | F-SI31 assessment |
| --- | --- | --- |
| 1 | PASS | one SWAP kernel remains production authority; research adapters do not create a second production kernel |
| 3 | PASS | parameters, state, forcing/process requests, numerical policy and scratch are explicitly separated |
| 4 | PASS | only committed continuation state persists; immutable parameter data are shareable |
| 5 | PASS | Newton/Jacobian/factorization and other scratch are worker/job-local |
| 7 | PASS | committed base, candidate, accept/reject, commit/rollback and retry ownership are explicit |
| 8 | PASS | replay/retry starts from committed state while declared worker-local warm starts remain possible |
| 9 | PASS | time is `[t0,t1]`; no calendar boundary is fundamental |
| 11 | PASS | candidate exchange, transaction semantics and optional sensitivities are representable for coupling without giving solver runtime ownership |
| 13 | PASS | mass residual is mandatory diagnostic information and mass conservation cannot be traded for fallback/performance |
| 14 | PASS | `dh_bottom_dq_bottom` is a first-class optional capability; finite differences are not mandated |
| 16 | PASS | no one-solver-instance-per-column requirement is introduced; immutable data and worker scratch remain shareable/batchable |
| 20 | PASS | Full Richards and alternative research solvers fit behind one semantic soil-water compatibility seam |
| 21 | PASS | process physics remain production-owned and reusable; research solver only owns the soil-water solve it declares |
| 22 | PASS | process hydraulic view excludes HeadCalc internals |
| 23 | PASS | physical capability requests and numerical policy are distinct and cannot silently substitute for each other |
| 25 | PASS | Full Richards remains the production/reference authority |
| 29 | PASS | no implicit midnight, day, file format or MODFLOW assumption is introduced |
| 30 | PASS | this contract includes an explicit invariant audit and known-gap record |

## 18. Freeze decision

`SoilWaterSolverResearchContract v1.0.0` is frozen as a research compatibility contract when the F-SI31 qualification record closes with decision:

`QUALIFIED_SOIL_WATER_SOLVER_RESEARCH_CONTRACT_V1_FROZEN`

That decision authorizes research isolation and stable contract consumption only. It is not production solver admission, canonical production-interface replacement, RossFast production readiness, or permission to bypass normal owner, independent qualification and canonical-admission gates for future production integration.
