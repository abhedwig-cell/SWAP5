# F-DOC15 — RB1 and current-canonical Status-A readiness final gap assessment

## Executive verdict

**Verdict: NOT READY.**

This is not a finding that SWAP5 “fails Status A”. It means that, at the live-rechecked authorities below, a formally defensible Status-A assessment cannot yet be completed.

The reason is narrower than “not enough documentation”. SWAP5 already has strong release provenance, version control, software/runtime architecture, transaction and coupling contracts, and substantial verification evidence. The remaining blockers are concentrated in four places:

1. the controlled `WR-QA-2024` criterion authority has not yet been obtained and reconciled;
2. the admitted scientific chain does not yet close cleanly from physical world/purpose through system boundary, conceptual model, assumptions and the full formal physical model;
3. model-wide parameter/variable/I/O provenance and assessment-facing technical/user records are incomplete;
4. sensitivity, uncertainty, external validation, monitored use and fitness-for-purpose evidence are not yet established as a complete canonical evidence set.

Therefore F-DOC15 may establish a final bounded readiness-gap and closure-plan authority, but it **never self-certifies Status A**.

## Assessment objects and authority discipline

### Official requirement basis

F-DOC01 remains the requirement authority at `999d4fa3da6fa08c5d57e23b9949f3920de37fbe`.

It pins:

- project control target: `WR-QA-2024`, “Revised checklist Status A/AA, 2024”;
- controlled full text: `NOT_OBTAINED`;
- inspectable baseline: `WR-QA-PUBLIC-22`;
- denominator: 22 public requirements in seven families.

Consequently every requirement verdict below is an **internal readiness verdict against the pinned public baseline**. A formal compliance claim first requires the controlled 2024 authority and explicit reconciliation. F-DOC15 adds no invented Status-A criterion.

### Qualified documentation authority chain

The live recheck confirms F-DOC01 through F-DOC13 as independent exact-head qualified authorities:

| Authority | Exact qualified head |
|---|---|
| F-DOC01 | `999d4fa3da6fa08c5d57e23b9949f3920de37fbe` |
| F-DOC02 | `18942fee83eb385fccc1663230772ae03dcc9ae6` |
| F-DOC03 | `0c25d97bd180378a916fbb14a1e45768af9ec63a` |
| F-DOC04 | `a703747ce1991c5601b76a84f04969b602298268` |
| F-DOC05 | `919f228d8aedc1029b5080bb019fbe61d2e1d7c6` |
| F-DOC06 | `c20c0fd4c53ef65f3c8d375362908a25f0855a4b` |
| F-DOC07 | `492b984bca282d6ec11dcaa727227b34c0ff3a84` |
| F-DOC08 | `8e5863510004ec11ab377b5bc9d3bd5df6d69777` |
| F-DOC09 | `2a4a8738496329001a3c3af9b5e50a9f31d0c44f` |
| F-DOC10 | `ef34a9f5a01d78ff9c2628315b484c5a8ff4f717` |
| F-DOC11 | `df438f8d0eaa4117e3e6df13a7061985fe233a16` |
| F-DOC12 | `e34caabe225986db3c60551f4168869f3e4cc2a2` |
| F-DOC13 | `1c63aeede05180d3628873083d9351da6e67175f` |

F-DOC14 is not an independent authority. Its branch points to the F-DOC13 head and no independent `F-DOC14_STATUS.json` exists.

Two later documentation branches are useful closure inputs but are not silently promoted here:

- F-DOC16 `b0bdf08b5c38771a4ee22c93ed0949f408ceeb2b`: exact-head qualification was observed green, but it is branch-only and not reconciled/admitted into the current authority chain. Its physical-system/1D-column conceptual foundation is therefore **qualified closure input, not current canonical authority**.
- F-DOC18 `448265df8b5a4be8941b688bde378a490751c5f1`: candidate T0-T7 physical-science coverage exists, but no exact-head qualification run was present at live recheck. It is **candidate-only and unqualified**.

### A. Immutable RB1

RB1 remains immutable:

- scientific source: `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`;
- qualification authority: `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`;
- final release authority: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`;
- release artifact: `release/f-rb02/F-RB02_CLOSEOUT.json`.

Post-RB1 documentation or qualification may explain later knowledge, but it is never represented as evidence that belonged to RB1 at release time.

### B. Current post-RB1 canonical snapshot

F-DOC15 freezes its current-canonical comparison at:

- branch: `integration/f-ci-canonical`;
- head: `eba90d79010b095b6556e93bd8b77a8c28d25560`;
- tree: `ed3187c068697f17886cc85ddb9291dfbbd161d4`;
- commit: `F-CI50P R1: finalize post-reconciliation closeout`.

This snapshot includes the post-RB1 F-CI49 transaction-composition admission and the F-CI50/F-CI50P typed groundwater-coupling contract/policy admission and preservation reconciliation. It does **not** imply that production predictor-corrector execution, a MODFLOW adapter or all groundwater-coupling application accuracy is admitted.

If formal assessment later targets a newer canonical SHA, only affected deltas need reconciliation. F-DOC15 does not require the moving branch to stop permanently.

## Requirement-by-requirement readiness matrix

Status semantics:

- `CLOSED`: the current evidence is sufficient for this public-baseline requirement at the assessed object.
- `PARTIAL`: substantial canonical evidence exists, but an assessment-facing closure is incomplete.
- `STATUS-A GAP`: a material claim/evidence object required by the public baseline is not yet canonically closed.
- `OUT OF SCOPE FOR STATUS-A` and `NOT APPLICABLE` are used only when supported by the criterion. None is assigned here before `WR-QA-2024` reconciliation.

| Req | Family | Current authority/evidence | RB1 | Current | Remaining gap and minimum closure |
|---|---|---|---|---|---|
| 1.1 | ST.1 | F-DOC01; architecture overview; F-DOC11; F-DOC16 branch-only | STATUS-A GAP | STATUS-A GAP | Admit a canonical physical-world, purpose, application-envelope and system-boundary foundation. |
| 1.2 | ST.1 | F-DOC03-13; F-DOC11 gap decomposition; F-DOC13 narrow numerical authority; F-DOC18 candidate | STATUS-A GAP | STATUS-A GAP | Close conceptual assumptions plus controlled formal physical chain. Do not infer theory from code. |
| 2.1 | ST.2 | F-DOC traceability; current F-CI admissions | PARTIAL | PARTIAL | Reconcile the assessment-facing as-built technical view to the exact assessed SHA. |
| 2.2 | ST.2 | CI/toolchain evidence; repository build/developer material | PARTIAL | PARTIAL | Pin executable environment, build/install/settings/platform limits for the assessed object. |
| 2.3 | ST.2 | qualification/testbank/release evidence | PARTIAL | PARTIAL | Provide an assessment-facing test/evidence index that states claims, oracles/tolerances and untested scope. |
| 3.1 | ST.3 | F-DOC01 reference architecture; typed contracts | STATUS-A GAP | STATUS-A GAP | Complete canonical parameter/variable registry with meaning, units, provenance, applicability and authoritative defaults/ranges where real. |
| 3.2 | ST.3 | F-DOC01 calibration schema | STATUS-A GAP | STATUS-A GAP | Populate calibration procedure/effects or controlled N/A rationale by relevant class. |
| 3.3 | ST.3 | typed API/runtime contracts; kernel/I-O separation | PARTIAL | PARTIAL | Complete user/kernel I/O semantics and adapter mapping without making `.swp` a kernel contract. |
| 3.4 | ST.3 | F-DOC01 provenance schema | STATUS-A GAP | STATUS-A GAP | Populate relevant raw-data/preparation/provenance records. |
| 4.1 | ST.4 | F-DOC01 sensitivity architecture | STATUS-A GAP | STATUS-A GAP | Produce interpreted application/model sensitivity evidence. Interface derivatives alone are not this requirement. |
| 4.2 | ST.4 | F-DOC01 uncertainty architecture | STATUS-A GAP | STATUS-A GAP | Produce the uncertainty assessment required by the reconciled criterion. |
| 4.3 | ST.4 | strong verification and preservation evidence | STATUS-A GAP | STATUS-A GAP | Establish canonical independent external validation with explicit unvalidated scope. |
| 4.4 | ST.4 | no closing canonical use-monitoring object identified | STATUS-A GAP | STATUS-A GAP | Supply monitored-use/application evidence in the form accepted after criterion reconciliation. |
| 4.5 | ST.4 | F-DOC01 fitness framework and release nonclaims | STATUS-A GAP | STATUS-A GAP | Populate application-class fitness records using validation, uncertainty/sensitivity and independent acceptance criteria. |
| 5.1 | DO.5 | bounded workunits, gap registers, qualification/admission governance | CLOSED | CLOSED | No Status-A closure action identified. |
| 5.2 | DO.5 | Git, exact-SHA authorities, immutable RB1 and admission/preservation chain | CLOSED | CLOSED | No Status-A closure action identified. |
| 6.1 | DO.6 | no qualified required-format metadata object identified | STATUS-A GAP | STATUS-A GAP | Populate metadata in the format required by reconciled `WR-QA-2024`. |
| 6.2 | DO.6 | governance/ownership fragments | PARTIAL | PARTIAL | Consolidate responsible roles, continuity/succession and maintenance/resource responsibilities as required. |
| 6.3 | DO.6 | architecture/coupling/dependency evidence | PARTIAL | PARTIAL | Consolidate complete assessed dependency and external communication register. |
| 6.4 | DO.6 | licensing/governance fragments | PARTIAL | PARTIAL | Consolidate external-use conditions, support route and support ownership. |
| 7.1 | IU.7 | F-DOC01 interpretation architecture plus nonclaims | STATUS-A GAP | STATUS-A GAP | Populate applicability, assumptions, validation/uncertainty coverage and interpretation limits from closed authorities. |
| 7.2 | IU.7 | developer/build/reference material | PARTIAL | PARTIAL | Assemble assessed install/operation/I/O/support guidance by linking canonical technical/reference material. |

The two `CLOSED` rows are not percentages and do not imply overall readiness.

## ST.1 layer-by-layer theory-to-evidence traceability

| Layer | Central question | Current canonical authority | Implementation authority | Qualification/evidence | Status | Gap/closure |
|---|---|---|---|---|---|---|
| Physical world / purpose | Which real system and use is represented? | F-DOC01 framing; target architecture; F-DOC16 branch-only candidate authority | N/A as primary authority | release nonclaims and application constraints are partial evidence | STATUS-A GAP | Admit the physical-world/purpose/application-envelope foundation. |
| System boundary | What is inside SWAP, forcing/interface, or outside? | architecture overview/component map; F-DOC12 runtime architecture; F-DOC16 branch-only | kernel/runtime/coupler interfaces | runtime/coupling tests | PARTIAL | Make one admitted conceptual authority normative for atmosphere, soil, vegetation, surface, drainage, irrigation, groundwater, deep-vadose and runtime/coupler boundaries. |
| Conceptual model | Which reservoirs/states/fluxes/processes interact? | scattered process docs; F-DOC16 branch-only | process/physics/state APIs | process and integration tests exist unevenly | STATUS-A GAP | Admit one connecting conceptual model above detailed process theory. |
| Assumptions | Which idealisations and validity limits apply? | scattered theory/process documentation; F-DOC11 gap decomposition | implementation encodes choices but is not theory authority | some tests bound behaviours, not application validity | STATUS-A GAP | Canonically state 1D column meaning, representativity, continuum/constitutive assumptions, lateral abstractions, boundary interpretation and applicability where supported. |
| Formal physical model | Which conservation laws/equations/relations/IC/BC/interface conditions? | F-DOC11 says controlled T0-T7 gaps remain; F-DOC13 closes only TIME-REFERENCE numerics; F-DOC18 candidate-only | physical-process and soil-water implementations | constitutive/solver/conservation tests | STATUS-A GAP | Review, qualify and admit the formal physical chain; escalate true theory-code mismatch rather than documenting it away. |
| Numerical model | How is the formal model discretised and solved? | F-DOC13 plus solver/runtime numerical authorities | soil-water solver, transaction/runtime and policy interfaces | solver verification, restart, conservation, retry/rollback qualification | PARTIAL | Consolidate full-model spatial/time/nonlinear/Jacobian/tolerance/fallback reference. Keep solver policy separate from physics. |
| Software implementation | Where are parameters/state/forcing/numerics/results and capabilities realised? | architecture docs plus current F-CI authorities | current canonical source at `eba90d...` | exact-SHA CI/admission evidence | PARTIAL | Update stale as-built umbrella documentation and link current post-RB1 admissions. |
| Qualification | Why believe implementation follows its claims? | qualification/testbank authorities | test harnesses and runtime diagnostics | strong verification/conservation/regression/release evidence; external validation/fitness incomplete | PARTIAL | Preserve verification claims, add external validation, sensitivity/uncertainty and application fitness evidence. |

### Interpretation of the current manual/documentation

The current documentation does begin too far downstream for ST.1. Detailed processes, equations and implementation-near material are often useful, but a reader is asked to enter the model after several modelling decisions have already been made.

This is **not** a reason to rewrite all good process documentation. The preferable closure is a thin, normative layer above it:

`physical world/purpose → system boundary → conceptual reservoirs/states/fluxes → assumptions → links to detailed formal process theory`.

The audit distinguishes five situations:

1. **missing content**: admitted high-level conceptual foundation, some assumptions/applicability, model-wide references and ST.4 evidence;
2. **existing but scattered**: system boundaries, runtime composition, process meaning, numerical and qualification material;
3. **existing but not current canonical authority**: especially qualified branch-only F-DOC16 and candidate-only F-DOC18;
4. **good content positioned too low or with the wrong ownership**: target architecture/process documents that should be linked, not made duplicate science authorities;
5. **actual inconsistency**: `docs/architecture/implementation-status.md` is an older as-built snapshot and is stale relative to later F-CI49/F-CI50/F-CI50P admissions. This is a technical documentation inconsistency. No physical theory-code mismatch is declared without evidence.

## Representative end-to-end capability audit

The question here is whether an independent expert can follow:
`conceptual meaning → formal equations/contracts → implementation → qualification`.

| Capability | Conceptual/formal authority | Implementation/contract | Qualification/evidence | Status | Break |
|---|---|---|---|---|---|
| Soil-water transport | substantial legacy/process theory and F-DOC traceability, but admitted upper conceptual/formal chain incomplete | RB1/current soil-water implementation | strong constitutive/solver/conservation qualification | PARTIAL | upper ST.1 authority chain |
| Infiltration / surface storage / runoff | F-DOC03 gives bounded traceability; system-level conceptual bridge incomplete | surface/process implementation | verified RB1 pathway and conservation evidence | PARTIAL | conceptual assumptions/application envelope |
| Soil evaporation | F-DOC06 explicitly leaves physical T0-T7 authority incomplete | evaporation process implementation | implementation/test trace exists | STATUS-A GAP | admitted physical-science chain |
| Transpiration / root uptake | F-DOC06 explicitly leaves physical T0-T7 authority incomplete | root-uptake/ET implementation | implementation/test trace exists | STATUS-A GAP | admitted physical-science chain |
| Drainage | process implementation and documentation exist, but no complete admitted end-to-end science authority was identified | current drainage capability | test evidence exists in qualification corpus | PARTIAL | full conceptual/formal-to-evidence chain |
| Crop / WOFOST | current crop source/capability exists | current canonical crop implementation | no complete Status-A end-to-end crop science/validation chain established by this audit | STATUS-A GAP | theory/application qualification chain |
| Bottom boundary | boundary concepts plus current typed groundwater interface improve the contract | boundary/groundwater interfaces | contract and solver qualification | PARTIAL | physical applicability and application validation |
| Groundwater coupling contract | architecture invariant plus F-CI50/F-CI50P typed interface/policy authority | current runtime groundwater contract/policy | exact-SHA admission/preservation qualification | CLOSED for software interface contract; PARTIAL for application science | production execution/validation is not implied by the closed contract |
| Transaction / retry / rollback | F-DOC12/runtime architecture | F-CI49 admitted solver-service transaction composition | restart/transaction/rollback qualification | CLOSED for runtime contract | no physical validation claim is attached |
| Optional snow process | no admitted end-to-end conceptual/formal authority identified | `src/process/mod_snow_process.f90` exists in current canonical | no end-to-end Status-A science/qualification authority established in this audit | STATUS-A GAP | conceptual/formal and application qualification chain |

A green implementation test proves only its tested contract. It does not automatically validate the physical process against external reality.

## Canonical-authority architecture

To prevent theory, code and evidence from becoming parallel uncontrolled narratives, ownership should be explicit:

| Layer | Canonical owner |
|---|---|
| Normative physical purpose, system boundary, conceptual model and core assumptions | one admitted model-foundation authority |
| Detailed process/theory equations | process-specific scientific theory documents, normative only in their stated scope |
| Numerical methods/solver policies | numerical/solver documentation, explicitly separated from physical options |
| Software architecture/current as-built state | architecture and exact-SHA F-CI admission authorities |
| Parameters/variables/I/O | generated or controlled reference documentation tied to stable IDs/schemas |
| Qualification | immutable testbank/F-CI/scientific qualification evidence, never used as substitute theory |
| Historical/release | immutable release authorities such as RB1, never rewritten by later evidence |

Where two documents currently state the same normative fact, one should own it and the other should link to it.

## Architecture-invariant audit

The current target architecture is substantively aligned with the project invariants on one kernel, kernel/I-O separation, explicit data categories, compact persistent state, worker-local scratch, transactional steps, generic time, coupling as a core runtime concern, hard mass conservation, the groundwater head/flux contract, MultiSWAP, non-1:1 MODFLOW composition, deep-vadose outside SWAP, alternative soil-water solvers, physics versus numerical policy, reference mode, diagnostics and runtime/coupler composition.

Two cautions matter for Status A:

1. target architecture is not automatically proof of current implementation;
2. historical legacy descriptions are not automatically current normative claims.

No Status-A gap is created merely because a legacy manual discusses days, midnight boundaries, `.swp`, one-to-one MODFLOW concepts, HeadCalc internals or per-column scratch. It becomes a gap only if such a statement remains a current canonical claim or conflicts with the assessed implementation. The stale current implementation-status page is such a documentation issue and should be patched. Historical material may remain historical.

## Final gap register

Only the following ten closure objects remain. They intentionally combine related public requirements rather than spawning one workunit per row.

| Gap | Class | Requirements | Why still open | Minimum closure | Code change? |
|---|---|---|---|---|---|
| G1 | GOVERNANCE | all | controlled `WR-QA-2024` absent | obtain, pin and reconcile controlled criterion authority | no |
| G2 | CONCEPTUALISATION | 1.1, 1.2, 7.1 | admitted world/purpose/system/concept/assumption bridge missing | reconcile/admit valid F-DOC16 foundation content as single conceptual owner | no |
| G3 | FORMAL_MODEL / THEORY | 1.2, 7.1 | F-DOC11 T0-T7 gaps remain; F-DOC18 unqualified candidate | scientific review, discrepancy disposition, exact-head qualification and admission | only if real theory-code discrepancy is confirmed |
| G4 | IMPLEMENTATION_DOCUMENTATION | 2.1-2.3, 7.2 | umbrella as-built docs lag F-CI49/50/50P | small current-SHA technical/environment/test-index patch | no |
| G5 | PARAMETER/VARIABLE REFERENCE | 3.1, 3.3, 7.2 | model-wide canonical reference incomplete | controlled/generated parameter-variable-I/O reference | no |
| G6 | PARAMETER/VARIABLE REFERENCE | 3.2, 3.4 | provenance/calibration policy exists but records incomplete | populate application-relevant provenance and calibration/N-A records | no |
| G7 | FITNESS-FOR-PURPOSE | 4.1, 4.2, 4.5 | sensitivity/uncertainty framework has no closing evidence | perform scoped sensitivity and uncertainty qualification | no production-code change expected |
| G8 | VALIDATION | 4.3, 4.5 | verification is strong, external validation not canonically closed | qualify suitable existing validation or perform bounded independent validation | no production-code change expected |
| G9 | FITNESS-FOR-PURPOSE | 4.4, 4.5, 7.1 | monitored use and application fitness not connected | populate accepted use/fitness records after G7/G8 | no |
| G10 | METADATA / GOVERNANCE | 6.1-6.4, 7.1-7.2 | metadata, management, dependencies, external use/support and user guidance fragmented/incomplete | small records/patches assembled from closed authorities | no |

No general `VERIFICATION` or `RELEASE/REPRODUCIBILITY` gap is created. Those areas are comparatively strong. Qualification gaps are capability/application-specific and are represented above.

### Documentation gap versus model gap

F-DOC15 applies the required distinction:

- category 1, documentation absent but implementation/evidence coherent: G4 and parts of G5/G10;
- category 2, documentation stale: current `implementation-status.md`;
- category 3, implementation differs from intended theory: **not declared** without evidence; if found during G3 it must go to scientific/implementation authority;
- category 4, intended theory ambiguous: possible in unresolved T0-T7 items and must be scientifically decided, not copy-edited;
- category 5, qualification insufficient to choose an interpretation: applies where tests cannot establish which scientific interpretation is intended.

## Minimal closure plan

The smallest defensible sequence is:

1. **G1 first:** obtain and reconcile the controlled 2024 criterion authority. This fixes the official denominator and prevents doing work against guessed wording.
2. In parallel, **G2, G4, G7 and G8** can proceed. G2 should reconcile the already qualified F-DOC16 input, G4 is a small technical documentation patch, while G7/G8 are genuine scientific evidence work.
3. **G3** follows the conceptual owner because formal theory should hang from an explicit system/conceptual model. Review F-DOC18 rather than assuming it is valid because it exists.
4. **G5 and G6** establish stable assessment-facing reference/provenance records, using existing schemas and application classes where possible.
5. **G9** integrates validation, sensitivity/uncertainty and actual use into explicit fitness-for-purpose records.
6. **G10** closes metadata/management/dependency/external-use and user guidance by linking the now-canonical authorities rather than duplicating them.
7. Only then run the formal WUR assessment against one exact immutable RB1 object or one explicitly named current-canonical candidate SHA.

No automatic F-DOC16, F-DOC17, etc. sequence follows from this plan. Existing branches should be reconciled where they already contain valid closure material. A new independent workunit is justified primarily where new scientific evidence such as G7 or G8 genuinely has its own scope, owner and acceptance criteria.

## Deferred post-Status-A improvements

The following are useful but should not block Status A unless the controlled criterion later says otherwise:

- exhaustive line-by-line theory-to-code traceability beyond representative scientific meaning;
- broad redesign of all manuals where a thin canonical bridge and links are sufficient;
- Status-AA-specific evidence;
- extra performance documentation or optimization unrelated to a Status-A requirement;
- groundwater-coupling functionality beyond the actually claimed/admitted application scope, including full production predictor-corrector or MODFLOW execution;
- additional testbank depth after the required claim/evidence coverage already closes.

## Final answer to the governing question

At the assessed authorities, an independent expert can reconstruct a large part of **how SWAP5 is implemented, versioned, transacted, coupled and verified**. The expert cannot yet reconstruct from one admitted canonical chain, without relying on branch-only material or source-code inference, the complete route from **which reality SWAP models**, through **system boundary, conceptualisation, assumptions and formal physical model**, to **application-bounded validation and fitness evidence**.

That is why ST.1 is not yet convincingly closed and why the overall verdict remains **NOT READY**. The remaining work is finite and identifiable. It is not a mandate for open-ended documentation growth.
