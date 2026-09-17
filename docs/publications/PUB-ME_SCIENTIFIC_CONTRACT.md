# PUB-ME scientific contract

Working title: **Evidence-preserving evolution of a process-based scientific model: from legacy execution to explicit state and transactional semantics**

Status: **initial research-design contract, not yet a manuscript claim**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

## 1. Central research question

> How can a mature process-based scientific model be structurally transformed while preserving defined scientific behaviour, provenance and qualification evidence?

The paper is not about replacing SWAP physics, introducing RossFast, or coupling to MODFLOW. It studies the controlled evolution of an established scientific simulator whose scientific meaning is partly encoded in legacy source structure, state mutation order, numerical routines and file-driven execution.

## 2. Research object

SWAP 4.3.1 and its evolution into SWAP5 form the principal case study.

The research object is broader than source-code modernization. The transformation changes architectural ownership of:

- persistent scientific state;
- candidate versus accepted state;
- numerical workspace;
- forcing;
- time and execution policy;
- solver selection;
- process orchestration;
- retry/rollback/commit;
- restart and external publication.

The scientific equations need not change for this transformation to be scientifically risky. A structural rewrite can alter results through changed state lifetime, mutation order, hidden aliases, retry semantics, numerical precision, initialization or execution ordering even when formulas appear unchanged.

## 3. Protected primary contribution

The candidate primary contribution is an **evidence-preserving modernization method for scientific simulation software** in which architectural migration is decomposed into bounded semantic capabilities and each change is admitted only when its scientific behaviour, ownership contract and preservation evidence are explicit.

The protected contribution is expected to combine:

1. **explicit scientific-state ownership** rather than implicit module/global mutation;
2. **candidate/accepted-state separation** so rejected numerical work cannot silently become model history;
3. **bounded migration slices** with declared claims and nonclaims;
4. **qualification before admission**, including preserved reference behaviour where behaviour is intended to remain unchanged;
5. **provenance-preserving authority** that distinguishes historical reference evidence, corrected reference evidence, current production semantics and later scientific extensions;
6. **prospective preservation** so future changes prove that already admitted scientific contracts remain valid.

The novelty claim must not reduce to ordinary refactoring, unit testing, version control or generic transactional programming.

## 4. Current SWAP5 basis

The current SWAP5 architecture already provides concrete evidence relevant to this paper. The admitted transactional time-stepping reference distinguishes committed state, candidate state and disposable workspace, requires rejected trials not to mutate committed state, and treats retry, rollback, restart and external publication as explicit ownership concerns rather than new physics.

The current reference Richards documentation likewise separates accepted start state, nonlinear candidate state and solver workspace, while preserving the frozen reference algorithm behind a typed solver seam.

These implementation facts are candidate case-study evidence. They are not by themselves sufficient to establish a general modernization method.

## 5. Novelty boundary

The paper must acknowledge at least four adjacent bodies of work.

### Legacy software modernization

Architecture-driven and model-driven modernization literature already studies transforming legacy applications while preserving business functionality and quality attributes. `PUB-ME` must therefore show why **scientific simulation semantics and numerical evidence** impose additional requirements beyond ordinary application modernization.

### Reproducible computational modelling

Reproducibility literature already emphasizes versioned code, explicit parameters, archived artifacts, repeatable workflows and independent reproduction. `PUB-ME` must not claim those practices as new. Its question is narrower: how can scientific meaning remain controlled **during architectural evolution**, when the executable implementation itself is being changed?

### Scientific software engineering

Unit tests, regression tests, CI, modular design and continuous integration are established practice. The candidate contribution is not the existence of these tools but the connection between architectural migration decisions and explicit scientific claims, invariants, admissibility evidence and preserved execution semantics.

### Verification and validation

Verification literature already distinguishes code verification from validation against the physical world. `PUB-ME` should use this distinction carefully. The primary claim concerns preservation and qualification of implemented scientific semantics, not empirical validation of every SWAP process.

## 6. Hypotheses

### H1. Behaviour can be preserved across architectural decomposition

A legacy process-based model can be decomposed into explicit state, solver, forcing and execution ownership without materially changing the defined reference behaviour inside a declared capability envelope.

Evidence required:

- exact or tolerance-qualified reference trajectories before and after representative migration slices;
- mass/accounting preservation where applicable;
- restart/split-run consistency;
- optimization-level or compiler-route checks where numerically relevant;
- explicit declaration of cases where exact preservation is neither possible nor scientifically intended.

### H2. Explicit state authority reduces semantic ambiguity

Separating committed state, candidate state and scratch/workspace makes retry, rollback, restart and solver substitution testable as independent contracts rather than emergent side effects of call order.

Evidence required:

- negative tests showing rejected trials cannot leak into accepted state;
- restart/replay tests showing accepted continuation is sufficient;
- examples of legacy hidden ownership that had to be made explicit;
- at least one case where architectural separation exposes or prevents a plausible defect.

### H3. Bounded admission preserves scientific authority through long-running modernization

A capability-by-capability qualification/admission process can allow continued architectural change without requiring the whole model to be re-derived or re-qualified from first principles after every change.

Evidence required:

- longitudinal provenance across multiple admitted workunits;
- dependency/claim maps showing which evidence remains valid when unrelated code changes;
- examples of stale evidence being correctly invalidated when a dependency changes;
- examples where immutable evidence is legitimately reused.

### H4. The method enables later scientific extension without forcing those extensions into the modernization claim

The evolved architecture can admit later solver substitution and model coupling through bounded seams while preserving the original scientific denominator.

Evidence required:

- existence of a qualified solver seam used by both reference and alternative solver routes;
- existence of a qualified external coupling seam;
- no requirement to reassign `PUB-SQ` or `PUB-GC` scientific conclusions to `PUB-ME`.

This is an enabling-architecture result, not proof that the later solver or coupling methods are themselves valid.

## 7. Minimum evidence set

### E0. Historical and corrected reference chain

Freeze the exact reference artifacts used to define preserved behaviour, including any independently justified corrected-reference patches. Document why each reference is authoritative for a given claim.

Primary result: a reproducible reference lineage, not a new hydrologic result.

### E1. Representative architecture migration slices

Select a small number of migration slices that are scientifically representative, for example:

- state/workspace separation;
- time-step transaction ownership;
- forcing/input separation;
- solver seam introduction;
- restart accepted-state boundary.

For each slice record:

```text
legacy ownership -> migration decision -> new ownership
               -> preservation risk -> qualification evidence
```

The paper should not attempt to narrate every SWAP5 commit.

### E2. Behaviour-preservation matrix

Construct a fixed benchmark matrix spanning materially different hydrologic regimes and boundary conditions inside the declared scope.

For each major architecture stage compare at least:

- key state trajectories;
- integrated water-balance terms;
- accepted/rejected step sequence where relevant;
- restart continuation;
- deterministic output identity or declared tolerances.

### E3. Adversarial transaction tests

Demonstrate fail-closed behaviour under:

- solver failure;
- rejected time step;
- retry;
- failed publication/preflight where applicable;
- stale or invalid restart/candidate identity.

Primary question: can non-authoritative work contaminate scientific history?

### E4. Longitudinal evidence-preservation case study

Choose several later SWAP5 changes and show how the evidence model decides whether old qualification remains valid, must be replayed, or is superseded by a semantic successor.

This experiment is central to making the paper more than a snapshot refactoring case study.

## 8. Generalization beyond SWAP

The paper should extract a minimal pattern applicable to other time-stepped process simulators:

```text
accepted scientific state
        |
        v
bounded candidate execution
        |
        v
scientific / numerical assessment
     /     \
 accept    reject
   |          |
commit      discard / retry
```

Around that lifecycle, the paper should identify what must be made explicit for trustworthy evolution:

- state ownership;
- units and sign conventions;
- temporal semantics;
- solver/process ownership;
- mutation boundaries;
- acceptance criteria;
- persistence boundary;
- provenance and evidence dependencies.

Any generalization must be stated as a proposed transferable pattern supported by one deep case study, not as universal proof across all scientific software.

## 9. Measurements to preserve now

For each publication-relevant modernization slice preserve:

- source and target commit;
- capability identifier;
- intended semantic change: none / bounded / scientific;
- files and state owners affected;
- reference authority used;
- qualification tests and exact run identifiers;
- benchmark outputs before/after;
- mass/restart/trajectory differences;
- compiler/optimization configuration;
- defects or ambiguous ownership discovered;
- evidence invalidated or reused;
- explicit nonclaims.

## 10. Falsification criteria

`PUB-ME` must be narrowed or redirected if:

1. the contribution reduces to standard refactoring plus regression tests;
2. preservation cannot be demonstrated on a scientifically meaningful benchmark matrix;
3. the architecture method is so SWAP-specific that no transferable pattern can be formulated;
4. bounded admission adds governance complexity without demonstrable protection against semantic drift or stale evidence;
5. the strongest results are actually numerical-solver or coupling results owned by `PUB-SQ` or `PUB-GC`;
6. a close scientific-software modernization method is found that already combines the same state-authority, bounded-admission and evidence-preservation pattern.

## 11. Hard publication firewall

Excluded from `PUB-ME` primary claims:

- RossFast speed, robustness and admissibility: `PUB-SQ`;
- groundwater coupling accuracy/convergence: `PUB-GC`;
- response-assisted coupling: `PUB-RC`;
- N:1 hydrologic upscaling: `PUB-SG`.

`PUB-ME` may show that the evolved architecture **enables** these studies, but their scientific results remain external evidence of extensibility rather than results of this paper.

## 12. Candidate manuscript structure

1. Scientific risk in legacy model modernization
2. SWAP case and reference authority
3. Evidence-preserving modernization method
4. State/candidate/workspace and transactional execution model
5. Representative migration slices
6. Behaviour-preservation experiments
7. Longitudinal evidence preservation and semantic successors
8. Discussion: transferability, cost and limitations
9. Conclusions

## 13. Publication-admission gates

- [ ] literature review distinguishes the method from ordinary legacy modernization and generic reproducibility practice;
- [ ] reference lineage is frozen and reproducible;
- [ ] representative migration slices are selected prospectively rather than cherry-picked only for success;
- [ ] preservation matrix spans meaningful hydrologic regimes;
- [ ] at least one adversarial state-contamination case is demonstrated;
- [ ] at least one longitudinal evidence-invalidation/reuse example is demonstrated;
- [ ] transferable method is stated without claiming universality;
- [ ] primary figures/results do not duplicate `PUB-SQ`, `PUB-GC` or `PUB-RC`;
- [ ] negative and failed migration evidence is preserved.

## 14. Initial literature anchors

Starting points for the eventual systematic review include:

- architecture-driven simulation modernization literature, including Durak (2015), *Extending the Knowledge Discovery Metamodel for architecture-driven simulation modernization*, Simulation;
- legacy application modernization methods that preserve functional/quality attributes, while noting their non-scientific domain assumptions;
- reproducible computational modelling guidelines that require explicit model, simulation and provenance information;
- scientific-software case studies using software-engineering methods to improve reproducibility of mathematical models;
- verification/validation literature distinguishing implemented-model verification from empirical validation.

This list is intentionally provisional. No priority claim is authorized until the literature boundary is reviewed systematically.
