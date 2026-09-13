# F-RG01A Parallel Research Isolation & Contract Ownership Policy

Policy ID: `F-RG01A-PRICO`

Policy version: `1.0.0`

Status: `NORMATIVE_PROGRAM_GOVERNANCE_ADDENDUM`

Parent program authority: `regie/f-rg01-post-rb1-program-rebaseline@09ef05c60c5e45af218980001c8ad8ec30da2e9e`

Parent F-RG01 tree: `92faf36b3aa746f0b6dca0681c8fc046a8d815f9`

Current-canonical snapshot at establishment: `integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`

Current-canonical snapshot purpose: program-state reference only. This policy does not alter production canonical.

RossFast research snapshot at establishment: `work/f-ross01-fast-mfp-feasibility@3a78d4f8199ebc15908e6e8108a2e4adb8cb5b15`

Exit target: `QUALIFIED_PARALLEL_RESEARCH_ISOLATION_AND_CONTRACT_OWNERSHIP_POLICY_ESTABLISHED`

## 1. Authority and scope

This document is a normative governance addendum to F-RG01. It does not rewrite the historical F-RG01 rebaseline and does not change the SWAP Core Architecture Invariants. It operationalizes how F-RG01 dependency, ownership and safe-parallel guidance must be applied from this policy version onward.

Where the static F-RG01 safe-parallel matrix conflicts with a live semantic-contract ownership assessment under this policy, this policy controls the parallelism classification. Historical F-RG01 classifications remain valid evidence of the state at the time they were made.

This policy applies to all future SWAP5 production, qualification, research, performance, testbank, documentation and coupling workunits when they are considered for parallel execution.

This is a governance-only authority. It:

- does not modify production source;
- does not reopen RB1;
- does not reopen any completed scientific qualification;
- does not admit RossFast or any other research capability to production;
- does not modify the frozen SWAP5-v1 completion denominator merely because optional research exists.

## 2. Why this policy exists

Parallel work cannot be judged safely from branch names, workunit IDs, directory names or changed-file sets alone. Separate branches can still depend on, redefine or co-own the same moving kernel, solver, process or runtime semantics.

The primary unit for deciding whether work may proceed in parallel is therefore the semantic contract.

A semantic contract is any behaviorally meaningful agreement consumed or provided across a component boundary. Examples include:

- a soil-water solver input/output contract;
- transaction, checkpoint, trial, rollback and commit semantics;
- state-layout and restart semantics;
- crop-to-ET data semantics;
- groundwater exchange sign, conservation and residual conventions;
- process-provider interfaces;
- numerical-policy contracts;
- runtime template or batching contracts;
- testbank qualification assumptions;
- controlled conceptual terminology that constrains implementation meaning.

A workunit is an owner when it is authorized to change the meaning of such a contract. A workunit is a consumer when it relies on the contract but is not authorized to redefine it.

A frozen contract is an explicitly versioned and pinned semantic authority whose meaning is fixed for the workunit using it. A moving contract is one whose semantics remain under active ownership or can change within the active workstream.

## 3. Normative principles

### 3.1 Research isolation

Experimental capabilities may develop as an independent research line against an explicitly pinned and frozen interface authority.

A `RESEARCH_ISOLATED` workunit:

- may remain behind current production canonical;
- does not have to rebase whenever canonical moves;
- may use a stable contract version for long-running experiments;
- remains valid research when production advances, provided its pinned assumptions remain explicit and reproducible.

Continuous synchronization with current canonical is not a research-validity requirement.

### 3.2 Contract ownership determines parallelism

Two workunits are truly safe to execute in parallel only when they do not simultaneously own or incompatibly modify the same moving semantic contract.

Different branches, workunit names or production files are not sufficient evidence of independence.

If two workunits both own the same moving semantic contract, the default classification is `SERIAL_REQUIRED` unless ownership is first divided by an explicit and frozen handoff boundary.

### 3.3 Frozen contracts by default

Isolated research should preferentially consume versioned and frozen input, output and interface contracts.

A production-canonical interface change does not automatically invalidate or force a rebase of an isolated research line. Compatibility with newer production authority is evaluated explicitly at a later compatibility gate.

### 3.4 Explicit maturity states

Experimental capabilities use at least the following ordered maturity states:

`RESEARCH_ISOLATED`

-> `CONTRACT_COMPATIBLE`

-> `INTEGRATION_CANDIDATE`

-> `PRODUCTION_ADMITTED`

The meanings are:

- `RESEARCH_ISOLATED`: research is reproducible against a pinned frozen contract but has no production authority.
- `CONTRACT_COMPATIBLE`: compatibility with a named production contract/current-canonical authority has been explicitly qualified, without yet becoming an admission candidate.
- `INTEGRATION_CANDIDATE`: an immutable candidate has been frozen for production integration and qualification against a named current production authority.
- `PRODUCTION_ADMITTED`: the exact qualified candidate has passed the applicable admission route and is represented in current canonical.

These states may not be skipped implicitly. Evidence from one state cannot silently be treated as authority for a later state.

### 3.5 Periodic compatibility qualification

Compatibility with current canonical is qualified at explicit maturity or integration points, not continuously enforced during research.

A research line may intentionally lag production canonical. When compatibility is needed, the qualification must name:

- the frozen research candidate;
- the production/current-canonical authority;
- the semantic contract version or boundary;
- any adapter used;
- the compatibility evidence and limitations.

### 3.6 Adapter-first evolution

When production interfaces change, first determine whether the change can be absorbed by a thin adapter, seam or versioned compatibility layer before modifying the experimental implementation itself.

The goal is to preserve research isolation and keep production evolution from becoming an accidental requirement to continuously rewrite experiments.

An adapter may not hide a real semantic mismatch. Conservation, transactionality, state meaning and other physical or numerical guarantees must remain explicit.

### 3.7 No production authority from research

A `RESEARCH_ISOLATED` branch:

- does not modify current canonical;
- is not a production authority;
- does not implicitly replace a production capability;
- cannot become the reference implementation merely because it is newer or faster;
- cannot block a production release unless that research capability was explicitly included in the frozen release scope before the release gate.

### 3.8 Separate production admission

When research is mature enough for production consideration:

1. freeze an immutable research candidate;
2. stop treating the evolving research branch as the future production authority;
3. start a separate compatibility/integration workunit against the then-current production authority;
4. qualify the exact integration candidate;
5. use the normal production-admission route.

A continuously evolving research branch must not simply grow into production authority.

### 3.9 Optional research cannot block SWAP5-v1

Capabilities outside the frozen SWAP5-v1 production scope have zero weight in the SWAP5-v1 completion criterion.

Their incompleteness, canonical drift or failed experiments cannot reduce the fixed SWAP5-v1 completion score and cannot block SWAP5-v1 release readiness.

An optional capability only acquires v1-critical weight if program governance explicitly changes the frozen v1 scope through a separate authority.

### 3.10 Interference is an architecture signal

If an allegedly isolated solver, process implementation or experimental component repeatedly has to be modified because kernel, runtime or process code changes elsewhere, do not first solve the problem by adding more cross-branch synchronization.

Treat repeated interference as evidence that a common semantic contract may be insufficiently explicit, insufficiently versioned or insufficiently decoupled.

Before expanding synchronization, inspect whether the architecture needs:

- a cleaner interface boundary;
- a frozen contract;
- a provider/view abstraction;
- a transaction seam;
- a compatibility adapter;
- separation of physical semantics from solver/runtime policy.

## 4. Mandatory parallel-workstream gate

Before two or more workunits are declared safe to execute in parallel, each workunit must answer:

1. Which semantic contracts does this workunit consume?
2. Which semantic contracts does this workunit own, modify or redefine?
3. For every relevant contract, is the authority `FROZEN` or `MOVING`?
4. Which other active workunit, if any, owns or modifies the same contract?
5. Based on that ownership, is the relationship `SAFE_PARALLEL`, `PARALLEL_AFTER_PINNING` or `SERIAL_REQUIRED`?

The classifications mean:

- `SAFE_PARALLEL`: no shared moving semantic contract is owned by both workunits, and any shared dependencies are already frozen or read-only.
- `PARALLEL_AFTER_PINNING`: work may proceed in parallel only after the shared dependency or handoff contract is explicitly frozen and each workunit's ownership boundary is stated.
- `SERIAL_REQUIRED`: the workunits currently own, redefine or incompatibly depend on the same moving semantic contract, or one workunit requires the accepted semantic output of the other before its own contract can be finalized.

No workunit may receive `SAFE_PARALLEL` solely because it uses a different branch, changes different files or has a different owner label.

Every future workunit prompt that proposes parallel execution must include this gate or an equivalent explicit contract-ownership assessment.

## 5. RossFast-specific ruling

RossFast is formally classified as:

`OPTIONAL_STRETCH_CAPABILITY`

and, while remaining on its research line:

`RESEARCH_ISOLATED`

Full Richards is sufficient as the production/reference soil-water solver for a complete SWAP5-v1.

Therefore RossFast:

- has `0%` weight in SWAP5-v1 completion;
- may continue on `work/f-ross01-fast-mfp-feasibility` or a successor research line against a pinned SoilWaterSolver contract;
- does not need to continuously track current canonical;
- cannot block SWAP5-v1;
- does not gain current transaction, restart or MultiSWAP production requirements merely because production canonical evolves;
- only acquires those production integration requirements after an explicit immutable RossFast `INTEGRATION_CANDIDATE` is designated.

For parallelism:

- RossFast consuming a pinned, frozen SoilWaterSolver contract while production work owns a newer moving implementation is `PARALLEL_AFTER_PINNING` and may then execute independently.
- RossFast and production work both attempting to own or redefine the same moving SoilWaterSolver semantic contract is `SERIAL_REQUIRED`.
- Different files or branches do not weaken that rule.

No RossFast production admission is authorized by this policy.

## 6. Relationship to SWAP Core Architecture Invariants

This policy changes no architecture invariant. It operationalizes them as follows.

| Invariant | Policy consequence |
| --- | --- |
| 1. One kernel | Research variants do not create a second production SWAP kernel. Production admission returns through the common-kernel contract. |
| 2. Kernel independent of I/O | Research isolation must not create file-format or path dependencies inside the kernel to simplify an experiment. Adapters remain outside. |
| 7. Transactional timesteps | An experimental solver may use a frozen transaction contract during research, but production compatibility must preserve checkpoint, trial, retry, commit and rollback semantics. |
| 16. MultiSWAP primary use case | Research need not continuously implement every current runtime optimization, but an integration candidate must qualify the applicable MultiSWAP contract before production admission. |
| 20. Alternative soil-water solvers | This policy provides the governance mechanism for alternative solvers to remain isolated behind a common soil-water interface until explicitly integrated. |
| 22. No HeadCalc-internal coupling | Frozen contracts must be clean interfaces. Research may not gain de facto ownership by reaching into HeadCalc or another solver's internal arrays. |
| 23. Physics and solver policy separated | Research solver policy or performance experiments must not silently redefine physical configuration or process semantics. |
| 25. Reference mode remains available | Full-accuracy reference mode remains production authority even when optional fast/reduced solvers are researched. |
| 30. Explicit architecture checks | Repeated research-production interference triggers an explicit architecture review before more coupling or synchronization is added. |

## 7. Normative update to F-RG01 parallelism guidance

F-RG01 section 7 remains historical evidence, but its pairwise labels are now conditional on this policy's live contract-ownership gate.

The program-wide interpretation is updated as follows:

| Relationship | Normative interpretation from F-RG01A onward |
| --- | --- |
| WOF43A vs PM08D7 | `PARALLEL_AFTER_PINNING` only when shared runtime semantics are frozen. `SERIAL_REQUIRED` if both own the same moving transaction/runtime contract. |
| WOF43A vs groundwater-coupling work | `SAFE_PARALLEL` only when there is no shared moving semantic contract. Otherwise pin the dependency or serialize. |
| WOF43A vs TB09 | Not automatically safe. `PARALLEL_AFTER_PINNING` when TB09 qualifies WOF/crop semantics that are still moving; `SAFE_PARALLEL` only for a disjoint frozen test scope. |
| WOF43A vs DOC16 | `SAFE_PARALLEL` only while DOC16 consumes frozen conceptual/crop semantics. If both redefine crop/ET meaning, pin or serialize. |
| PM08D7 vs groundwater-coupling work | `PARALLEL_AFTER_PINNING` for disjoint contracts; `SERIAL_REQUIRED` where shared runtime transaction semantics converge. |
| PM08D7 vs TB09 | Not automatically safe. Apply the producer/consumer contract gate and pin any moving process/runtime semantics before parallel qualification. |
| PM08D7 vs DOC16 | Safe only where conceptual semantics are frozen and read-only; otherwise `PARALLEL_AFTER_PINNING` or `SERIAL_REQUIRED`. |
| GC18 vs GC19 or their successors | `SERIAL_REQUIRED` while both own moving coupling transaction/interface semantics. `PARALLEL_AFTER_PINNING` only after an explicit frozen handoff. |
| Groundwater coupling vs TB09 | `PARALLEL_AFTER_PINNING` where TB09 consumes coupling/process semantics still moving; `SAFE_PARALLEL` only when the tested contract is frozen and work is disjoint. |
| Groundwater coupling vs DOC16 | `SAFE_PARALLEL` only after relevant coupling terminology and conceptual boundaries are frozen; otherwise `PARALLEL_AFTER_PINNING`. |
| TB09 vs DOC16 | `SAFE_PARALLEL` only if neither workunit modifies the same semantic contract and both consume frozen authorities. |
| RossFast vs production soil-water solver/service work | `PARALLEL_AFTER_PINNING` when RossFast is a consumer of a frozen SoilWaterSolver contract. `SERIAL_REQUIRED` if both attempt to own the moving SoilWaterSolver contract. |
| Any two F-CI admissions | `SERIAL_REQUIRED`. |
| F-CI admission vs its postimage/preservation step | `SERIAL_REQUIRED`. |

The matrix is no longer a substitute for a live ownership assessment. It is a default decision framework.

## 8. Current-workstream implications at establishment

The repository contains multiple historical, owner, remediation and qualification branches for several capabilities. Branch multiplicity is not itself evidence of simultaneous semantic ownership.

At this policy's establishment:

- RossFast is explicitly reclassified from generic optional research to `OPTIONAL_STRETCH_CAPABILITY / RESEARCH_ISOLATED` with zero SWAP5-v1 completion weight.
- Existing WOF43A and PM08D7 source/candidate branches must not be treated as active production owners merely because the branches still exist. Their current production status must be derived from the current-canonical admission chain.
- GC18/GC19-family branches must be interpreted through explicit groundwater transaction/interface contract handoffs. Any two genuinely active workunits that both own the same moving groundwater transaction/interface contract are `SERIAL_REQUIRED`; historical or qualification branches do not create ownership merely by existing.
- TB09 is primarily a qualification consumer. Where it qualifies a semantic contract that is still changing, its relation to that producer is `PARALLEL_AFTER_PINNING`, not automatically `SAFE_PARALLEL`.
- DOC16 is primarily a conceptual/documentation authority. It is `SAFE_PARALLEL` only when the implementation semantics it consumes are frozen; if it and an implementation workunit both redefine the same conceptual contract, the work must be pinned or serialized.

No currently existing branch is authorized by this document to seize ownership from an admitted production authority.

## 9. Future workunit prompt requirement

Every new SWAP5 workunit prompt that starts or explicitly permits parallel work must include, directly or by reference to this policy:

- consumed semantic contracts;
- owned/modified semantic contracts;
- frozen or moving status of each relevant contract;
- other active owners;
- resulting `SAFE_PARALLEL`, `PARALLEL_AFTER_PINNING` or `SERIAL_REQUIRED` decision;
- exact authority used for each frozen dependency.

For research workunits, the prompt must additionally state the current maturity state from section 3.4 and whether the capability belongs to frozen SWAP5-v1 scope.

## 10. Governance preservation

This policy deliberately does not:

- modify `integration/f-ci-canonical`;
- modify any production source;
- reopen RB1;
- invalidate previous scientific or numerical qualifications;
- grant production authority to RossFast;
- change the fixed completion denominator through optional research;
- infer semantic ownership from branch existence alone.

Any future change to this policy requires a new versioned governance authority. Historical versions remain reproducible.

## 11. Exit condition

The policy is established when:

1. this versioned artifact is committed on a governance branch descended from the exact F-RG01 authority;
2. its definition commit and tree are pinned in a closeout/status artifact;
3. the current-canonical snapshot used for the establishment assessment is recorded;
4. the changed paths are governance-only;
5. the RossFast classification is explicit;
6. F-RG01 parallelism guidance is normatively updated through section 7;
7. the exact target is recorded as:

`QUALIFIED_PARALLEL_RESEARCH_ISOLATION_AND_CONTRACT_OWNERSHIP_POLICY_ESTABLISHED`
