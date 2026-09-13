# F-RG01D — SWAP5 Module Contract Standard & Replaceability Governance

Policy ID: `F-RG01D-MCS`

Policy version: `1.0.0`

Status: `NORMATIVE_PROGRAM_GOVERNANCE_ADDENDUM`

Parent governance authorities:

- F-RG01: `regie/f-rg01-post-rb1-program-rebaseline@09ef05c60c5e45af218980001c8ad8ec30da2e9e`
- F-RG01A: `regie/f-rg01a-parallel-research-isolation-contract-ownership-policy@4553204468695553cf69a48d1c97598c471156d6`
- F-RG01B: `regie/f-rg01b-runtime-resumption-execution-policy@5e2561d9051fba81769565291b1bf3089c7ddcd9`
- F-RG01C: `regie/f-rg01c-fixed-denominator-completion-model@56b86e29e0960e396059caf47c193440d571b709`

Current-canonical snapshot at establishment:

- `integration/f-ci-canonical@c19a04721a05c6a00ba264e7477969807dcb258f`
- tree `5342833575484452b34606f8854ff3f5a542e452`
- current canonical includes the F-CI56 predictor-corrector admission closeout.

Exit target:

`QUALIFIED_MODULE_CONTRACT_STANDARD_AND_REPLACEABILITY_GOVERNANCE_ESTABLISHED`

## 1. Purpose

SWAP5 already has a modular target architecture, explicit component ownership, data-category separation, workstream ownership, semantic-contract governance and transactional execution rules.

This policy adds one missing uniform layer: every material architectural module or component shall be describable by one compact **Module Contract Manifest** that makes its boundary mechanically inspectable.

The manifest answers, in one place:

- what the module is responsible for;
- what it explicitly does not own;
- what it consumes and produces;
- which parameters, persistent state, forcing, numerical configuration, results and scratch it touches;
- which semantic contracts it provides and consumes;
- who owns transaction/commit behaviour;
- what mass, time, restart, diagnostics and fail-closed guarantees apply;
- whether optionality really scales with use;
- which dependencies are forbidden;
- how the module can be replaced without redesigning unrelated physics;
- what repository evidence supports the claims.

This is a governance and architecture-contract standard. It changes no production source and does not itself qualify any physical or numerical implementation.

## 2. What a SWAP5 module is

For this policy, a **module** is an architectural responsibility with a stable semantic boundary, not necessarily a Fortran module, file, class, namespace or workstream.

The target component map remains authoritative for the primary decomposition. The initial module registry therefore follows these responsibilities:

1. Public API
2. Legacy/external adapters
3. Runtime/execution manager
4. Coupler
5. Kernel interval executor
6. Surface/atmospheric boundary physics
7. Crop/ET/root-uptake physics
8. Drainage/irrigation/optional process physics
9. Soil-water solver interface
10. Soil-water solver implementation family
11. Results/diagnostics assembly
12. Optional external deep-vadose transfer component

A later design decision may split or combine these responsibilities. Doing so changes the module registry, not automatically the SWAP5-v1 completion denominator.

## 3. No second source of truth

A Module Contract Manifest is a **contract capsule and authority index**, not a replacement for detailed owning authorities.

The manifest shall reference rather than duplicate where possible:

- detailed solver or process interface contracts;
- state/restart contracts;
- transaction contracts;
- scientific formulation authorities;
- qualification authorities;
- canonical admission authorities;
- performance evidence;
- Status-A/scientific documentation.

If a detailed contract and a manifest disagree, the owning detailed authority controls its own semantics and the manifest is stale and must be repaired.

The manifest may summarize the boundary, but shall not silently redefine it.

## 4. Mandatory manifest fields

Every conforming module manifest shall identify at minimum the following.

### 4.1 Identity and authority

- stable `module_id`;
- human-readable name;
- manifest schema and manifest version;
- module-contract version;
- maturity/status classification;
- owning workstream or governance owner;
- exact definition authority;
- exact implementation authority when implementation is claimed;
- exact qualification authority when qualification is claimed;
- canonical admission authority when canonical status is claimed.

No `latest`, floating branch or chat-only authority is sufficient for a frozen manifest.

### 4.2 Responsibility boundary

The manifest shall state:

- `owns`: behaviour for which this module is authoritative;
- `must_not_own`: responsibilities that explicitly belong elsewhere;
- `non_goals`: nearby behaviour intentionally outside the module contract.

This section is required because modularity is not merely decomposition; it is also refusal of inappropriate ownership.

### 4.3 Explicit data categories

The six SWAP5 data categories shall be addressed individually:

1. immutable/shared parameters;
2. committed dynamic state;
3. forcing/process requests;
4. numerical configuration/policy;
5. results/diagnostics;
6. worker/job scratch.

For each category the module shall state whether it owns, references, reads, proposes, writes or does not use the category.

Persistent physical state and temporary numerical scratch shall never be collapsed into one field.

### 4.4 Provided and consumed semantic contracts

Every cross-component dependency shall be classified as either:

- `provided_contract` — semantics owned/provided by this module;
- `consumed_contract` — semantics used but not owned by this module.

Each referenced contract shall identify where possible:

- contract ID;
- version or exact authority;
- semantic role;
- stability: `FROZEN`, `MOVING` or `EXTERNAL_PINNED`;
- whether an adapter is permitted/required;
- fail-closed behaviour if the contract cannot be satisfied.

This list is the machine-readable bridge to F-RG01A contract-ownership parallelism governance.

### 4.5 Transaction semantics

Every production-relevant module shall state its transaction role explicitly, even if the answer is `NONE`.

The manifest shall cover:

- whether committed state may be mutated directly;
- whether the module computes a trial/candidate;
- who decides acceptance;
- who commits;
- what rollback means;
- whether retries start from the correct committed state;
- whether warm-start information exists and whether it is physical state or scratch.

A process module that does not own commit may not gain commit authority merely because it is convenient for an implementation.

### 4.6 Conservation obligations

The manifest shall state all conservation obligations it participates in.

For water this includes, where applicable:

- flux sign convention;
- storage contribution;
- action/reaction requirement across an interface;
- accepted-only versus trial flux publication;
- mass residual ownership;
- whether conservation is checked locally, globally or both.

`mass_conservation = optional` is not a valid SWAP5 production declaration.

If another conserved quantity later becomes production-required, its obligation shall be added explicitly rather than inferred.

### 4.7 Generic time semantics

The manifest shall declare:

- interval semantics, normally `[t0,t1]`;
- any process-specific event/calendar dependency;
- whether a calendar boundary is physically required or merely an adapter concern;
- whether the module assumes a fixed day, midnight, month or year.

A hidden fixed-day assumption is non-compliant unless explicitly justified by the owning physical process contract.

### 4.8 Restart and persistence

The manifest shall identify exactly what must persist to resume physical evolution.

It shall also identify what must **not** be persisted as per-column physical state, including where applicable:

- Newton vectors;
- Jacobians/factorizations;
- rejected candidate state;
- temporary constitutive values;
- disposable warm-start caches.

A module that claims restart compatibility shall cite restart evidence.

### 4.9 Optionality and scaling

For optional functionality the manifest shall state:

- activation condition;
- persistent-state cost when inactive;
- parameter-reference cost when inactive;
- compute-path cost when inactive;
- scratch allocation behaviour;
- whether heterogeneous active/inactive columns can be separated into templates/batches.

Inactive optional physics shall not silently impose full persistent or solver cost on every column.

### 4.10 Diagnostics

The manifest shall state which diagnostics it guarantees to expose, including applicable:

- execution route;
- retry/failure reason;
- solver effort;
- fallback/relaxed mode;
- water-balance contribution;
- coupling residuals;
- capability restrictions.

Diagnostics are contract-visible behaviour, not optional debug output, when required by runtime qualification.

### 4.11 Failure and fail-closed semantics

Unsupported physics, boundary modes, incompatible contract versions, invalid state or unavailable required providers shall fail closed before inappropriate committed-state mutation.

The manifest shall identify:

- preflight checks;
- failure classes;
- recoverable versus fatal failure boundaries;
- whether rejected work can leave external side effects.

### 4.12 Replaceability boundary

Every major module shall define what it means to replace that module without redesigning unrelated SWAP5 components.

The manifest shall identify:

- the replacement unit;
- the stable externally visible semantics that a replacement must satisfy;
- forbidden implementation dependencies;
- adapter policy;
- qualification obligations for a replacement;
- which consumers should remain unchanged.

Replaceability is semantic, not syntactic. Two implementations with the same routine signature are not interchangeable if state, conservation, time or failure semantics differ.

### 4.13 Invariant mapping

Every module contract shall list the SWAP Core Architecture Invariants that constrain it, with at least:

- invariant number;
- expected effect (`COMPLIANT`, `STRENGTHENS`, `NOT_APPLICABLE_WITH_RATIONALE`);
- evidence or authority reference.

A material contract change shall re-evaluate the affected invariants.

### 4.14 Evidence and open gaps

Claims shall be linked to exact repository evidence.

The manifest distinguishes at minimum:

- `implemented`;
- `owner_tested`;
- `owner_qualified`;
- `independently_qualified`;
- `canonical_admitted`;
- `preserved_regression_protected`.

Open limitations remain explicit. Absence of evidence is not converted into positive status by architecture intent alone.

## 5. Versioning

Module contract manifests use semantic versioning for contract meaning.

- MAJOR: breaking semantic/ownership/state/conservation/transaction change.
- MINOR: backward-compatible addition or newly optional capability.
- PATCH: clarification, metadata/evidence repair or non-semantic correction.

A frozen module-contract version shall never be redefined in place.

An implementation commit may change without a contract-version change only when contract-visible semantics are unchanged and the qualification/admission evidence is updated as required.

## 6. Adoption states

Uniform module-contract adoption is tracked separately from production capability maturity.

Allowed adoption states are:

- `UNMAPPED`: target component exists but no module-contract mapping has been performed;
- `BOUNDARY_MAPPED`: responsibility/data/contract boundary has been mapped from existing authorities;
- `MANIFEST_ESTABLISHED`: a schema-conforming manifest exists;
- `QUALIFIED_MANIFEST`: the manifest has been checked against owning technical authorities and implementation evidence;
- `CANONICAL_MANIFEST`: current canonical explicitly carries or references the qualified manifest for the admitted module state.

These adoption states do **not** imply physical maturity. A module may be production-mature while its uniform manifest adoption still needs retrospective consolidation.

Conversely a complete manifest is not implementation evidence.

## 7. Prospective requirement and legacy/current-module migration

From F-RG01D onward:

1. A new architectural module shall establish a module manifest before production admission.
2. A workunit that materially changes a module's shared semantic contract, state ownership, transaction role, mass obligation, time semantics, restart semantics or replaceability boundary shall update or supersede the affected manifest.
3. Research-isolated work may use a research-scoped manifest with unsupported production capabilities declared explicitly.
4. An `INTEGRATION_CANDIDATE` shall have a complete production-facing manifest before canonical admission.
5. Existing already-admitted modules are not retroactively invalidated solely because the uniform F-RG01D manifest did not exist when they were admitted.
6. Existing modules shall be migrated to the uniform manifest at their next material contract change or through a dedicated bounded consolidation workunit.

This avoids invalidating already-qualified work while preventing further architectural drift.

## 8. Admission and qualification use

A Module Contract Manifest is a required review input, not automatically an independent qualification authority.

Owner qualification should verify at least:

- implementation matches the manifest's owned responsibility;
- forbidden ownership/dependencies are absent in the qualified scope;
- data ownership matches the manifest;
- provided/consumed contract pins are correct;
- transaction and persistence claims are accurate;
- invariant mapping has no adverse delta.

Independent qualification may rely on the manifest to define the claim boundary but shall independently verify the claims relevant to its workunit.

Canonical admission shall not promote a manifest beyond the exact candidate actually admitted.

## 9. Relation to F-RG01A parallelism

F-RG01A declares semantic-contract ownership, not branches/files, as the unit that determines safe parallelism.

F-RG01D makes that assessment easier and less subjective by requiring each module to enumerate:

- provided contracts;
- consumed contracts;
- frozen/moving status;
- owning authority;
- adapter boundary.

The F-RG01A gate remains normative:

- `SAFE_PARALLEL` when no shared moving contract is jointly owned;
- `PARALLEL_AFTER_PINNING` when shared semantics must first be frozen;
- `SERIAL_REQUIRED` when workunits co-own or redefine the same moving semantic contract.

A module manifest cannot label work `SAFE_PARALLEL` contrary to F-RG01A ownership evidence.

## 10. Relation to F-RG01B recovery

F-RG01B requires recoverable workunit checkpoints.

When a material module-contract change spans multiple execution chunks, a recovery checkpoint shall record at minimum:

- module ID;
- old contract version/authority;
- proposed new contract version;
- changed provided/consumed contracts;
- implementation status;
- test/qualification status;
- next safe action.

A runtime interruption shall not force reconstruction of an already-persisted module boundary.

## 11. Relation to F-RG01C completion model

F-RG01D does not alter `SWAP5_V1_COMPLETION_MODEL_V1` weights or denominator.

Module manifests are an evidence/architecture discipline, not a newly weighted physics capability.

No percentage credit is earned merely by creating manifests.

No already-earned production credit is removed solely because a historical module predates this standard.

If future governance decides that complete canonical manifest coverage must become an independently weighted release capability or new hard completion gate, that requires an explicit completion-model version decision under F-RG01C rules. It shall not be introduced implicitly through this policy.

## 12. F-SI31 as an exemplar, not a replacement

`F-SI31 — SoilWaterSolverResearchContract v1` demonstrates the desired contract quality for a solver boundary:

- explicit parameter/state/forcing/numerics/scratch separation;
- read-only committed trial base;
- candidate versus acceptance distinction;
- boundary capability declarations;
- process hydraulic view;
- transaction/restart semantics;
- diagnostics;
- optional sensitivities;
- fail-closed unsupported capabilities;
- invariant audit;
- semantic versioning.

F-RG01D does not copy F-SI31 semantics into unrelated modules and does not promote its research contract to a production ABI.

Instead, the F-SI31 structure validates that the uniform module-manifest fields are practical and aligned with existing SWAP5 architecture.

## 13. Research and optional modules

Research or optional components follow the same ownership discipline but may truthfully declare unsupported production properties.

Examples:

- RossFast remains `OPTIONAL_STRETCH_CAPABILITY / RESEARCH_ISOLATED` and may eventually carry a research-scoped solver-module manifest against its pinned F-SI31 contract.
- Deep-vadose remains an optional external component outside the SWAP kernel.
- Energy-balance research remains outside the frozen SWAP5-v1 denominator unless separate governance changes that scope.

A research manifest creates no production authority.

## 14. Architecture invariant coverage

F-RG01D directly strengthens or operationalizes at least:

- invariant 1 — one kernel, by preventing use-case-specific hidden component ownership;
- invariant 2 — I/O stays outside the kernel;
- invariant 3 — explicit data separation;
- invariant 4 — compact persistent state;
- invariant 5 — worker scratch ownership;
- invariant 6 — storage-layout freedom behind logical contracts;
- invariant 7 — transaction boundaries;
- invariant 9 — generic time;
- invariant 11 — coupling contract visibility;
- invariant 13 — mass conservation obligations;
- invariant 16 — MultiSWAP-scalable component contracts;
- invariant 20 — replaceable soil-water solvers;
- invariant 21 — reuse physics without reusing legacy module boundaries;
- invariant 22 — no HeadCalc-internal coupling;
- invariant 23 — physics versus solver policy;
- invariant 26 — diagnostic obligations;
- invariant 27 — optional functionality scales with use;
- invariant 28 — runtime/coupler owns system composition;
- invariant 29 — no silent dependencies;
- invariant 30 — explicit review of module-contract changes.

No invariant is weakened by this policy.

## 15. Initial registry interpretation

The accompanying registry is deliberately conservative.

It does not claim that existing modules lack architecture. It records whether their already-existing authorities have been consolidated into the new uniform manifest shape.

At establishment:

- all primary target components are at least `BOUNDARY_MAPPED` through the target component ownership map and architecture invariants;
- the soil-water solver interface has the strongest existing contract exemplar through F-SI31, but that artifact is research-scoped and therefore does not by itself constitute a canonical production Module Contract Manifest;
- runtime, transaction, coupling, WOFOST, ET, drainage and other lines possess numerous specific authorities, but these remain distributed rather than yet consolidated into one schema-conforming per-module capsule;
- no production capability is downgraded by this registry observation.

## 16. Required review questions for future workunits

Every material architecture/module workunit shall answer:

1. Which `module_id` owns the behaviour being changed?
2. Does the module already have a manifest? If so, what exact version/authority?
3. Is this change contract-visible or implementation-private?
4. Which provided contracts change?
5. Which consumed contracts change?
6. Does state ownership change?
7. Does transaction/commit/rollback behaviour change?
8. Does mass accounting or a sign convention change?
9. Does restart/persistence change?
10. Does time/event behaviour change?
11. Does optional functionality impose new inactive cost?
12. Do consumers remain unchanged, proving replaceability?
13. Which F-RG01A parallelism classification follows from the changed contracts?
14. Which invariants and qualification gates must be rerun?

If a workunit cannot answer these questions, its modular boundary is not yet sufficiently explicit for production admission.

## 17. Governance preservation

This workunit:

- changes no production source;
- changes no current canonical branch;
- does not reopen RB1;
- does not reopen completed scientific qualification;
- does not change physics;
- does not alter solver policy;
- does not change F-RG01C completion weights;
- does not admit RossFast or any research solver;
- does not require rewriting already-qualified historical work solely for documentation conformity.

## 18. Decision

The SWAP5 Module Contract Standard v1 is established when the F-RG01D status record closes with:

`QUALIFIED_MODULE_CONTRACT_STANDARD_AND_REPLACEABILITY_GOVERNANCE_ESTABLISHED`

From that point, module-level architectural development shall use the standard prospectively, and already-admitted modules shall be consolidated at bounded future integration points rather than through a disruptive repository-wide rewrite.
