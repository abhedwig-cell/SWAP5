# SWAP5 publication and thesis evidence inventory

Status: **living evidence map**

Purpose: connect existing SWAP5 implementation, qualification and governance evidence to the publication portfolio without retrospectively overstating what that evidence proves.

This inventory separates four evidence classes:

1. **FOUNDATIONAL_EXISTING**: pre-existing implementation or qualification evidence that directly establishes a capability or invariant needed by a paper;
2. **RETROSPECTIVE_CANDIDATE**: historical evidence that may become manuscript evidence after explicit re-audit/re-extraction, but was not originally designed as a publication experiment;
3. **SHARED_INFRASTRUCTURE**: reusable code, testbank, datasets, telemetry or runtime surfaces that support multiple papers but own no primary scientific inference;
4. **PROSPECTIVE_REQUIRED**: publication-grade experiment or analysis that does not yet exist and must be designed under the relevant scientific contract.

The chronology rule is strict:

> Existing qualification evidence may support a later publication, but it must never be described as pre-registered publication evidence when it predates the publication hypothesis.

The inventory is therefore not a claim that the papers are already proved. It is a map of what is already available and what still has to be done.

---

## 1. Programme-level baseline

### Status-A scientific baseline

Relevant authorities:

- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`;
- production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`;
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- Status-A release-readiness admission: PR #151.

PR #151 records a frozen denominator including the reference solver, transactional orchestration, restart, serialized MultiSWAP, drainage, surface evaporation, admitted WOFOST81 scope, bounded Snow, Groundwater Coupling v1, permanent testbank and qualification authority. It explicitly leaves Ross/RossFast, broad MODFLOW/backend evolution, parallel real-physics MultiSWAP and speculative optimization outside that denominator.

Classification:

- `FOUNDATIONAL_EXISTING` for the existence of a frozen, qualified scientific baseline;
- `SHARED_INFRASTRUCTURE` for all publication lines;
- not by itself publication evidence for novelty, performance or generality.

### Permanent testbank

Relevant authorities:

- F-TB11, PR #111;
- F-TB11 postimage reconciliation, PR #113.

F-TB11 preserves stable regression/qualification coverage for transaction, mass, restart, MultiSWAP, Full Richards, typed solver seam and ET-related capability. It also demonstrates an important governance rule: superseded historical fixtures remain historical evidence and are not patched merely to force moving-current PASS.

Classification:

- `FOUNDATIONAL_EXISTING` for preservation/qualification capability;
- `SHARED_INFRASTRUCTURE` for `PUB-ME`, `PUB-SQ`, `PUB-GC` and thesis synthesis;
- not sufficient on its own for publication-grade statistical or numerical comparison.

---

# 2. PUB-ME evidence inventory

Research role: **PRESERVE**

Doctoral mapping: `RQ1`

Primary question: how can a mature process-based scientific model be structurally transformed while preserving defined scientific behaviour and qualification evidence?

## ME-E01: explicit candidate versus committed state

Evidence:

- `docs/numerics/transactional-time-stepping.md`;
- admitted transaction/kernel lineage incorporated in Status-A;
- F-TB11 transaction/reject/mass/restart preservation.

What is already established:

- candidate calculation and accepted/committed authority are explicit;
- rejected attempts must not leak into committed state;
- retry begins from accepted authority;
- computation is separated from acceptance/publication;
- restart persists admitted committed continuation, not arbitrary scratch state.

Classification: `FOUNDATIONAL_EXISTING`.

Potential paper use:

- architecture definition;
- formal invariant set;
- one case study showing how this separation enabled safe later transformations.

Still missing:

- a publication-oriented empirical comparison demonstrating what failure modes are prevented by this structure;
- quantified migration/verification effort versus a credible alternative development approach, if such comparison is scientifically defensible.

## ME-E02: mandatory typed soil-water solver seam and HeadCalc isolation

Evidence:

- F-SI35 production admission, PR #107;
- F-CI58P postimage reconciliation, PR #108;
- F-CI93 semantic-successor preservation, PR #157.

What is already established:

- one mandatory typed production solver seam exists;
- legacy HeadCalc remains behind the typed compatibility boundary;
- standalone and worker routes use the common seam;
- transaction/retry, hard mass, boundaries, diagnostics, sensitivity and worker isolation were replayed as preservation evidence;
- later legitimate composition changes were handled by semantic requalification rather than pretending historical blobs had not changed.

Classification:

- `FOUNDATIONAL_EXISTING` for the seam and preservation mechanism;
- `RETROSPECTIVE_CANDIDATE` for a model-evolution case study.

Potential paper use:

- concrete migration episode from legacy procedural ownership to typed scientific service;
- example of evidence-preserving semantic successor lineage.

Still missing:

- a concise chronological reconstruction of the migration decision and alternatives considered;
- publication figures/tables summarizing the before/after ownership graph and preservation evidence;
- a generalization argument that is bounded beyond SWAP-specific code names.

## ME-E03: preservation authority evolves when implementation legitimately evolves

Evidence:

- F-CI75, PR #143;
- F-CI92, PR #155;
- F-CI93, PR #157;
- F-CI96, PR #168.

What is already established:

- exact historical hashes are retained as historical authority;
- a later scientifically admitted semantic successor can replace a stale moving-current byte lock;
- the remedy is semantic requalification against the changed surface, not silently updating hashes;
- preservation authority can therefore evolve without rewriting history.

Classification: `RETROSPECTIVE_CANDIDATE`.

Potential paper use:

- one of the strongest examples for an evidence-preserving scientific-model evolution workflow;
- supports a distinction between immutable historical evidence and moving-current semantic preservation.

Still missing:

- formal terminology and threat model suitable for a general scientific-software audience;
- a compact set of episodes demonstrating the pattern rather than relying on one repository anecdote.

## ME-E04: Status-A theory/code/evidence mapping

Evidence:

- PR #152, current Status-A documentation reconciliation;
- PR #151, release-readiness baseline;
- F-DOC21/F-DOC24 and related authority matrices.

What is already established:

- current documentation distinguishes frozen scientific authority, current preservation authority and historical target material;
- theory, code, qualification and preservation references are intentionally connected.

Classification:

- `FOUNDATIONAL_EXISTING` as research artefact;
- `RETROSPECTIVE_CANDIDATE` as publication evidence.

Still missing:

- independent evaluation of whether the traceability structure materially improves auditability/reproducibility;
- comparison with established scientific-software provenance practices in the literature.

## PUB-ME prospective experiment requirements

The following remain `PROSPECTIVE_REQUIRED` unless a later audit finds equivalent existing evidence:

1. a bounded set of representative migration episodes reconstructed from immutable repository history;
2. before/after architecture/state-ownership diagrams produced from exact source authorities;
3. an evidence-preservation matrix showing which scientific behaviours remained unchanged across each episode;
4. explicit counterexamples where naive mutation or stale-hash preservation would have produced a false assurance signal;
5. a bounded generalization analysis: which principles plausibly transfer to other time-stepped process models and which are SWAP-specific;
6. literature-grounded evaluation criteria for trustworthy scientific model evolution.

Current maturity assessment: **strong foundational evidence, publication analysis still required**.

---

# 3. PUB-SQ evidence inventory

Research role: **REPLACE**

Doctoral mapping: `RQ2`

Primary question: when may an alternative numerical solver replace the reference Richards solver without confusing computational performance with scientific validity?

## SQ-E01: frozen reference Richards authority

Evidence:

- `docs/numerics/richards-solver.md`;
- F-DOC25, PR #175;
- Status-A production baseline.

What is already established:

- reference residual/Jacobian structure;
- Newton-Raphson update and bounded backtracking;
- tridiagonal solve plus fallback;
- nonlinear convergence criteria;
- distinction between solver convergence and hard mass acceptance;
- separation of solver workspace, candidate physical state and committed state.

Classification: `FOUNDATIONAL_EXISTING`.

Paper role:

- defines the reference method and contract against which substitution is assessed.

## SQ-E02: RossFast bounded model binding

Evidence:

- F-ROSS02, PR #128.

What is already established:

- a deliberately narrow RossFast D3R model envelope;
- fixed material set, grid, head envelope, forcing and duration restrictions;
- candidate hydraulics and numerical certificate do not own commit/mass/publication;
- malformed/out-of-envelope candidates fail closed;
- O0/O2 identity on the qualified binding route.

Classification: `FOUNDATIONAL_EXISTING` for admissibility mechanics.

Publication limitation:

- not a comparative solver study;
- the original workunit explicitly did not establish production execution or general Full-Richards equivalence.

## SQ-E03: concrete RossFast kernel and immutable table provider

Evidence:

- F-ROSS03, PR #129;
- F-ROSS04, PR #130;
- F-ROSS05, PR #133;
- F-ROSS06, PR #140.

What is already established:

- concrete Fortran D3R kernel against exact research oracles;
- six immutable production-owned mobility tables;
- real transactional execution through the qualified restricted composition;
- exact material/duration oracle comparisons at O0/O2;
- fail-closed rejection of unsupported tables, durations and configuration;
- no hidden publication of incomplete/rejected work.

Classification:

- `FOUNDATIONAL_EXISTING`;
- selected numerical outputs may be `RETROSPECTIVE_CANDIDATE` after audit.

Publication limitation:

- these gates were designed for qualification, not balanced scientific comparison against the reference solver over a broad problem space.

## SQ-E04: production solver selection

Evidence:

- F-ROSS12 adapter qualification, PR #164;
- F-ROSS12 production admission, PR #165;
- F-CI96 postimage preservation, PR #168;
- final F-ROSS12 closeout, PR #174.

What is already established:

- explicit registered `ROSSFAST_D3R` selection behind the existing `soil_water_solver_t` seam;
- Reference remains default/reference path;
- no automatic fallback from RossFast to Reference;
- preflight fails closed before transactional mutation;
- real RossFast execution, mass closure, certificate propagation and no HeadCalc fallback were qualified;
- production solver ABI and transaction ABI remained unchanged.

Classification:

- `FOUNDATIONAL_EXISTING` for safe solver substitution;
- `RETROSPECTIVE_CANDIDATE` for publication case study.

## PUB-SQ prospective experiment requirements

`PROSPECTIVE_REQUIRED`:

1. a balanced Reference-versus-RossFast experimental design over a declared physical/numerical parameter space;
2. equal-accuracy or error-versus-cost comparison rather than default-tolerance wall-time comparison only;
3. long trajectory comparison, not just isolated step/kernel agreement;
4. cumulative mass and hydrologic-output divergence analysis;
5. explicit mapping of successful, marginal and inadmissible regimes;
6. failure-mode comparison near dry/wet transitions, difficult hydraulic contrasts and timestep limits;
7. work counters: nonlinear iterations, internal substeps, retries, rejected trials, CPU time and wall time;
8. sensitivity of conclusions to compiler optimization and platform where materially relevant;
9. a predefined rule for when RossFast is scientifically admissible, computationally useful, both, or neither.

The intended publication product is an **admissibility map**, not a winner/loser benchmark.

Current maturity assessment: **implementation and qualification are advanced; publication-grade comparative evidence is still missing**.

---

# 4. PUB-GC evidence inventory

Research role: **COUPLE**

Doctoral mapping: `RQ3`

Primary question: how can independently time-integrating vadose-zone and groundwater models be coupled conservatively and reproducibly over finite coupling windows?

## GC-E01: Groundwater Coupling v1 scientific semantics

Evidence:

- `docs/science/groundwater-coupling.md`;
- F-DOC24, PR #173;
- Status-A groundwater capability chain.

What is already established:

- explicit pressure-head to hydraulic-head datum conversion;
- explicit flux unit/sign conversion;
- whole-window integrated lower-boundary exchange;
- restricted predictor/corrector sequence from the same accepted origin;
- predictor candidate discard before corrector evaluation;
- governed head-residual acceptance;
- dedicated interface mass ledger;
- accepted-state publication after preflight;
- explicit nonclaim of broad/unrestricted MODFLOW coupling.

Classification: `FOUNDATIONAL_EXISTING`.

## GC-E02: generic external-groundwater gateway

Evidence:

- F-GC26, PR #124 and its later admission lineage.

What is already established in the qualified gateway design:

- external native head to common hydraulic head translation;
- external flux to public outward-positive flux translation;
- checkpoint/trial/commit/discard/prepare/abort delegation;
- stale/partial/failure handling;
- multiple cell gateways sharing an external backend;
- quiescence/rebind protection.

Classification:

- `FOUNDATIONAL_EXISTING` for the external coupling seam;
- `SHARED_INFRASTRUCTURE` for future MODFLOW experiments.

Publication limitation:

- gateway conformance is not a MODFLOW scientific backend and does not establish a numerical-coupling result.

## GC-E03: bounded N:1 MultiSWAP groundwater aggregation

Evidence:

- F-GC25, PR #122;
- inherited F-GC20 tile aggregation and F-GC22 accuracy binding.

What is already established:

- multiple SWAP tiles can be composed into one groundwater-cell transaction;
- predictor and corrector tile exchanges are area-aggregated deterministically;
- one groundwater predictor/corrector trial is driven by the aggregated transfer;
- per-tile ledger weighting and exact mass conservation are qualified in the bounded composition;
- caller-order independence and failure isolation were tested;
- no wall-clock speedup or hydrologic heterogeneity importance was claimed.

Classification:

- `FOUNDATIONAL_EXISTING` for `PUB-GC` mapping/conservation;
- `SHARED_INFRASTRUCTURE` for `PUB-SG`;
- not itself `PUB-SG` scientific evidence.

## GC-E04: Status-A coupled acceptance and preservation

Evidence:

- Status-A PR #151;
- Groundwater Coupling v1 included in the frozen release-readiness denominator;
- F-DOC24 current technical reference.

Classification: `FOUNDATIONAL_EXISTING`.

## GC-E05: prospective held-out same-origin replay experiment

Evidence:

- primary scientific manifest `PUB-GC-E1-PRIMARY-0001`, frozen at commit `c3114e455029ee5dee0d92dbc4814c3fc0923ef6`;
- independently qualified generic primary engine, receipt `PUB-GC-E1-PRIMARY-ENGINE-QUAL-0001`;
- primary execution authority `a2fab00d6076933972cee924d7d392ec6bc5024c`;
- one-shot held-out execution: GitHub Actions run `35287247968`, job `105422209812`;
- primary result receipt: `docs/publications/results/PUB-GC-E1-PRIMARY-0001.yaml`.

What is prospectively established:

- exact same-origin A/B/C window responses were independent of candidate order under the frozen controlled real-SWAP case;
- the accepted SWAP origin remained unchanged and every candidate was discarded rather than published;
- the deliberately history-contaminated diagnostic produced different repeated-A responses after B versus after C;
- the preregistered exchange discriminant was `3.07959298679549853e-3 cm`, above the frozen `1e-9 cm` numerical floor;
- the preregistered endpoint-pressure-head discriminant was `1.31893680771767663 cm`, above the frozen `1e-8 cm` numerical floor;
- analytic GW-A telemetry translated the repeated-A exchange difference into a groundwater-head difference of `1.53979649339774927e-4 m`;
- all 16 candidate rows had zero reported mass residual and zero transaction retries in this controlled execution.

Classification: `PROSPECTIVE_PRIMARY`.

Admitted interpretation:

- supports H1 at the **operator-definition level** for this held-out controlled case: a subsystem candidate response is reproducible when evaluated from a common accepted origin, whereas deliberate candidate-history contamination makes that response order dependent.

Publication limitations:

- the history-contaminated route is explicitly non-production-valid;
- E1 does not establish practical hydrologic materiality;
- E1 does not establish MODFLOW 6 transferability;
- E1 does not establish coupling-window convergence or whole-window-versus-terminal-flux superiority;
- generality beyond the held-out case remains to be tested.

## PUB-GC prospective experiment requirements

The same-origin operator-definition experiment is no longer prospective. The remaining central work is `PROSPECTIVE_REQUIRED`:

1. concrete MODFLOW 6 backend with explicit datum/unit/temporal semantics and qualification;
2. a fair whole-window-versus-terminal-flux comparator under matched non-exchange semantics;
3. one-column MODFLOW 6 benchmark small enough for strict numerical references;
4. loose sequential, restricted pc1 and converged replay-based coupling comparators;
5. coupling-window refinement and residual-tolerance refinement;
6. numerical-reference self-refinement check;
7. head error, cumulative whole-window exchange error, coupled mass residual and retry statistics;
8. at least one relevant strong-feedback regime where coupling choice materially matters;
9. a bounded N:1 conservation demonstration using the same publication telemetry;
10. realistic demonstration case after the controlled experiments are understood.

Current maturity assessment: **method semantics and infrastructure are strong and one prospective held-out primary result now supports the same-origin operator-definition hypothesis; practical materiality, convergence behaviour and concrete MODFLOW evidence remain prospective**.

---

# 5. PUB-RC evidence inventory

Research role: **ACCELERATE**

Doctoral mapping: `RQ4`

Primary question: can subsystem response information accelerate the nonlinear groundwater-vadose coupling without weakening conservation or reproducibility?

## RC-E01: canonically admitted groundwater response-sensitivity contract

Evidence:

- F-GC29 closed checkpoint on `work/f-gc29-groundwater-response-sensitivity-service-extension`;
- production file `src/runtime/mod_groundwater_response_sensitivity_contract.f90`;
- independent qualification F-VQ94;
- canonical admission F-CI83.

What is already established:

- optional additive groundwater response sensitivity;
- tangent is bound atomically to the exact candidate/trial pair and time window;
- public derivative is `dh_groundwater_dq_groundwater_s`;
- exact service, lineage, origin revision and candidate revision provenance;
- unavailable, nonsmooth, provider-error and nonfinite derivative paths fail closed;
- finite difference is qualification-only, not a production response construction;
- response evaluation does not commit or mutate groundwater state.

Classification: `FOUNDATIONAL_EXISTING`.

Important boundary:

- this is a **groundwater-side local tangent**;
- it is not yet the complete coupled interface Jacobian;
- it does not own coupling iteration policy.

## RC-E02: accepted-trajectory directional sensitivity infrastructure

Evidence:

- F-KT21/F-CI75, PR #143;
- accepted-trajectory directional sensitivity with typed solver-seam preservation.

Classification:

- `SHARED_INFRASTRUCTURE` / `RETROSPECTIVE_CANDIDATE` pending exact relevance audit;
- not automatically equivalent to the SWAP whole-window derivative required by `PUB-RC`.

## PUB-RC prospective experiment requirements

`PROSPECTIVE_REQUIRED`:

1. define and qualify the SWAP-side whole-window response with respect to groundwater interface head, schematically `dQ_swap/dh_interface`;
2. establish a scientifically valid construction for that response, including nonsmooth/fail-closed regions;
3. compose SWAP-side and groundwater-side sensitivities into the coupling residual derivative or an equivalent interface update;
4. implement at least one response-assisted method without weakening `PUB-GC` acceptance/conservation semantics;
5. compare against fixed-point coupling, relaxation and at least one strong established acceleration baseline where feasible, such as Aitken or Broyden/interface quasi-Newton;
6. report iterations, SWAP trials, groundwater trials, retries, failure cases and wall/CPU cost;
7. compare at equal coupling accuracy, not just equal iteration tolerance;
8. test robustness when derivatives are unavailable, noisy, nonsmooth or misleading;
9. define a crossover region where response construction cost is or is not repaid by reduced subsystem evaluations.

Falsifying outcome to preserve:

- if ordinary fixed-point/relaxed coupling converges in very few trials for relevant regimes, or tangent construction costs more than it saves, `PUB-RC` may collapse into a negative numerical result or cease to be a standalone paper.

Current maturity assessment: **one important groundwater-side building block is already admitted; the actual response-assisted coupled method remains prospective**.

---

# 6. PUB-SG evidence inventory

Research role: **SCALE**

Doctoral mapping: `RQ5`, conditional

Primary question: under what conditions must heterogeneous vadose-zone responses within one groundwater cell be retained explicitly rather than homogenized?

## SG-E01: deterministic N:1 composition exists

Evidence:

- F-GC25, PR #122;
- F-GC20 aggregation lineage.

What is already established:

- multiple SWAP tiles can be mapped to one groundwater-cell transaction;
- area-weighted transfer is deterministic and conservatively accounted;
- transaction/state isolation can be preserved in the bounded composition.

Classification: `SHARED_INFRASTRUCTURE`.

What it does **not** prove:

- that explicit heterogeneity is hydrologically important;
- that the chosen subgrid representation is superior to a calibrated effective column;
- any regional scale or speedup claim.

## PUB-SG prospective experiment requirements

Almost all central evidence is `PROSPECTIVE_REQUIRED`:

1. define physically meaningful heterogeneous column ensembles, initially two-column controlled contrasts;
2. define credible effective/homogenized representations rather than naive arithmetic averages only;
3. compare aggregated dynamic response `sum_i A_i Q_i(h)` with `A_total Q_eff(h)` across groundwater depths and transient forcing;
4. identify mechanism classes such as soil hydraulic contrast, rooting/vegetation contrast, irrigation/drainage contrast and capillary feedback;
5. determine whether errors affect only local interface flux or materially alter groundwater trajectories and other hydrologic outputs;
6. test sensitivity to groundwater-cell size and subgrid fraction distribution;
7. scale only after controlled mechanisms are understood;
8. include computational cost so scientific value can be compared with added complexity;
9. predefine a null-result criterion under which explicit heterogeneity is not worth a standalone publication.

Current maturity assessment: **technical N:1 infrastructure exists; scientific upscaling evidence is essentially not yet generated**.

---

# 7. THESIS-SYNTHESIS evidence inventory

`THESIS-SYNTHESIS` does not own primary paper evidence. It will combine independently owned results after they exist.

## TS1: explicit acceptance as common scientific boundary

Potential supporting evidence already present:

- transactional candidate/commit architecture;
- F-SI35 solver seam and preservation;
- F-ROSS12 solver substitution through the same accepted-state lifecycle;
- Groundwater Coupling v1 accepted-state publication.

Current classification: `RETROSPECTIVE_CANDIDATE`.

What is still required:

- successful publication-level results from at least `PUB-ME`, `PUB-SQ` and `PUB-GC`;
- synthesis must distinguish architectural precondition from empirically demonstrated consequence.

## TS2: interfaces alone are insufficient for scientific modularity

Potential supporting evidence already present:

- typed solver interface plus scientific/mass/transaction qualification;
- external groundwater gateway plus datum/unit/temporal semantics;
- response-sensitivity service with provenance and fail-closed semantics.

Current classification: `RETROSPECTIVE_CANDIDATE`.

Still required:

- cross-paper analysis demonstrating that interface syntax without qualification/ownership would not have been enough to preserve scientific meaning.

## TS3: reproducible subsystem evaluation enables higher-order coupling

Current supporting basis:

- candidate/accepted replay architecture;
- `PUB-GC` scientific contract;
- F-GC29 response-sensitivity building block.

Classification: mostly `PROSPECTIVE_REQUIRED` because the key empirical bridge depends on successful `PUB-GC` and `PUB-RC` results.

## TS4: evidence-preserving evolution can convert a legacy model into a composable scientific component

Current supporting basis:

- Status-A scientific baseline and traceability;
- typed solver seam;
- production solver substitution;
- groundwater gateway/coupling semantics.

Classification: `RETROSPECTIVE_CANDIDATE` for the historical arc, but final thesis claim remains `PROSPECTIVE_REQUIRED` pending all component studies.

---

# 8. Evidence gaps ranked by urgency

## Immediate, because future runs can lose publication telemetry

1. **Coupling telemetry schema** for `PUB-GC` / `PUB-RC`: window, accepted origin, head residual, integrated exchange, mass residual, trial counts, retries and timing.
2. **Solver-comparison telemetry schema** for `PUB-SQ`: accepted timestep, solver work, retries, mass, state/output error and timing.
3. **Publication metadata on new workunits**: owner paper, hypothesis, primary claim, reusable infrastructure, exclusions.

## Near-term scientific gaps

1. `PUB-GC`: concrete MODFLOW 6 backend and convergence experiment ladder.
2. `PUB-SQ`: publication-grade Reference/RossFast admissibility experiment design.
3. `PUB-ME`: bounded historical migration episodes reconstructed as research cases rather than repository narrative.
4. `PUB-RC`: SWAP-side whole-window sensitivity and interface algorithm.
5. `PUB-SG`: no urgency until `PUB-GC` mapping is sufficiently mature; avoid generating regional data before the null/alternative design is fixed.

## Literature gaps

Each paper still needs a systematic or at least reproducible targeted literature map before priority/novelty language is admitted. The current scientific contracts contain provisional boundaries only.

---

# 9. Prospective evidence record template

For future publication-relevant experiments, use a record equivalent to:

```yaml
publication_evidence:
  evidence_id: <stable id>
  created_at: <date/time>
  publication_owner: PUB-ME | PUB-SQ | PUB-GC | PUB-RC | PUB-SG | SHARED-INFRASTRUCTURE
  doctoral_question: RQ1 | RQ2 | RQ3 | RQ4 | RQ5 | null
  thesis_synthesis_relevance:
    - TS1 | TS2 | TS3 | TS4
  hypothesis_id: <pre-existing hypothesis id or null>
  chronology:
    hypothesis_precedes_run: true | false
    design_precedes_run: true | false
  exact_authority:
    canonical_commit: <sha>
    production_commit: <sha>
    configuration_digest: <digest>
    input_digest: <digest>
  experiment:
    case_id: <id>
    comparator: <id or null>
    controls: <description>
    outputs:
      - <metric>
  result:
    verdict: SUPPORTS | WEAKENS | REFUTES | NULL | INFRASTRUCTURE_ONLY
    artifact_refs:
      - <workflow/run/file/result ref>
  publication_use:
    primary_claim: <one sentence or null>
    candidate_figure_table:
      - <id or null>
    reusable_by:
      - PUB-...
    excluded_primary_claims:
      - PUB-...
```

The `hypothesis_precedes_run` field is especially important for the possible PhD trajectory. It prevents later retrospective analyses from being presented as if they had been prospectively specified.

---

# 10. Current programme assessment

| Line | Existing implementation/qualification foundation | Publication-grade core evidence | Main gap |
| --- | --- | --- | --- |
| `PUB-ME` | strong | partial / retrospective | convert migration history into bounded empirical research cases and literature-grounded evaluation |
| `PUB-SQ` | strong | partial / qualification-oriented | balanced Reference/RossFast admissibility and equal-error/cost experiment programme |
| `PUB-GC` | strong method/infrastructure foundation | one prospective held-out primary result plus supporting conservation evidence | concrete MODFLOW 6 coupling, whole-window comparator and controlled convergence/reference experiments |
| `PUB-RC` | partial but important groundwater tangent exists | minimal | SWAP-side response, full interface method and comparator experiments |
| `PUB-SG` | N:1 infrastructure exists | essentially absent | controlled heterogeneity-versus-effective-representation science |
| `THESIS-SYNTHESIS` | strong historical narrative potential | premature | depends on publication-level results and must remain synthesis rather than duplicate ownership |

The programme is therefore not starting from zero. A substantial part of the **research infrastructure and capability qualification** already exists. The main future work is to turn selected parts of that infrastructure into prospectively designed, publication-grade scientific experiments without rewriting the chronology of how SWAP5 was actually developed.
