# TRACE prospective research protocol v0.2

Date: 2026-09-19
Model in this repository: SWAP/SWAP5
Repository observation baseline: `integration/f-ci-canonical@aa3147f7177993a4464b4aa1a256b0ad2ffcf116`

## Aim

Prospectively determine which scientifically consequential discrepancies emerge when theory, scientific documentation, mature implementation and executable evidence are reconciled, how conflicts are resolved, and which discrepancies existing regression-preservation evidence would or would not have detected.

Modernization is the observational setting, not the scientific novelty claim.

## Research questions

RQ1. What classes of scientifically consequential discrepancy emerge during prospective reconciliation of theory, documentation, implementation and executable evidence, and how are they resolved?

RQ2. Which prospectively identified consequential discrepancies are detected by pre-existing regression-preservation evidence, and which require independent scientific or executable evidence?

Secondary RQ. When accepted historical behaviour conflicts with theory, documentation or independent executable evidence, what authority determines the final disposition?

## Hypotheses

H1. Consequential inconsistencies will include cases that cannot be reduced to ordinary implementation defects because multiple individually plausible representations or evidence sources conflict.

H2. Pre-existing regression-preservation evidence will miss at least some consequential discrepancies when historical accepted behaviour forms part of the inconsistency.

H3. Some cases will require a disposition other than simply correcting code, including documentation correction, oracle correction, preserved/versioned legacy behaviour, narrowed application envelope, recalibration or unresolved authority.

Negative results are retained and must not be reframed post hoc.

## Prospective eligibility

A candidate is confirmatory prospective evidence only if, before creation of its TRACE candidate record:

1. the substantive scientific inconsistency was not already known to the investigator;
2. its scientific disposition was not already known;
3. it was encountered after protocol freeze;
4. a reconstructable pre-resolution state exists.

Previously discussed, identified or substantially understood cases are historical/pilot evidence regardless of repair date.

## Unit of analysis

The primary unit is a discrepancy episode: an underlying case in which at least two independently inspectable scientific representations or evidence sources cannot, within a stated application envelope, simultaneously be interpreted as scientifically equivalent or operationally consistent, or executable evidence contradicts an explicit scientific claim.

One causal issue with several code manifestations is normally one episode.

## Inclusion

A confirmed TRACE case must:

- identify at least two relevant representations/evidence sources;
- contain genuine inconsistency, ambiguity or non-equivalence requiring scientific interpretation;
- potentially affect governing equations, state, source/sink, flux, conservation, boundary/initial condition, parameter meaning, units, signs, activation/timing, scientifically consequential discretization, output interpretation or application envelope;
- retain enough evidence to reconstruct discovery;
- contain scientific content beyond ordinary maintenance.

## Exclusion

Exclude pure formatting, naming, stylistic refactoring, generic build failures, warnings without scientific relevance, duplicated code without inconsistency, missing comments without conflicting scientific content, infrastructure-only defects, unsupported speculation and formulations shown to be relevantly equivalent.

All exclusions remain logged.

## Evidence freeze

Before scientific repair where technically possible, preserve:

- repository/ref/commit;
- relevant source;
- relevant theory/documentation versions;
- configuration/input;
- compiler/runtime where relevant;
- existing tests and baselines;
- reproduction command;
- relevant outputs;
- initial conflict statement;
- discovery date, observer and inspection trigger.

Repository history may substitute only when it exactly reconstructs the pre-resolution state.

## Denominator

Raw case counts are not prevalence estimates.

The denominator is the reconciled scientific element: a bounded constitutive relation, boundary condition, source/sink, transfer law, state, initialization rule, process activation, temporal rule, conservation relation or numerical convention subjected to explicit reconciliation.

Record all inspected elements, including elements producing no discrepancy.

## Preregistered relation classes

- THEORY_DOCUMENTATION
- THEORY_IMPLEMENTATION
- DOCUMENTATION_IMPLEMENTATION
- INTENDED_EQUATION_EXECUTABLE
- REGRESSION_ORACLE_INDEPENDENT_EVIDENCE
- DUPLICATE_IMPLEMENTATION
- HISTORICAL_CONVENTION_CURRENT_INTERPRETATION
- CALIBRATED_LEGACY_INDEPENDENT_EVIDENCE
- MULTIPLE_RELATION_CONFLICT

These are structural relation classes, not a predetermined defect taxonomy.

## Emergent mechanism coding

Mechanisms are open-coded. Units, signs, indexing, hidden state, temporal staging, duplicated-formula drift, obsolete documentation, oracle error, numerical convention and calibration lock-in are sensitising concepts only.

## Scientific consequence dimensions

- INTERPRETATIVE
- QUANTITATIVE
- STRUCTURAL
- CONSERVATION
- NUMERICAL
- APPLICATION_ENVELOPE
- CALIBRATION
- NONE_DEMONSTRATED

Potential consequence and demonstrated consequence are recorded separately.

## Regression counterfactual

For each replayable confirmed case:

1. restore the latest relevant pre-resolution state;
2. identify the regression/preservation evidence that existed before discovery;
3. run it unchanged;
4. do not add the newly designed TRACE oracle;
5. classify outcome as:
   - REGRESSION_DETECTED
   - REGRESSION_MISSED
   - REGRESSION_NOT_APPLICABLE
   - COUNTERFACTUAL_NOT_RECONSTRUCTABLE
6. then run the independent evidence exposing the discrepancy.

A passing baseline only counts as a miss if the affected route was meaningfully within that evidence's scope.

## Resolution dispositions

Possible dispositions include:

- IMPLEMENTATION_CORRECTED
- DOCUMENTATION_CORRECTED
- THEORY_CLARIFIED
- REGRESSION_ORACLE_CORRECTED
- LEGACY_BEHAVIOUR_PRESERVED
- BEHAVIOUR_VERSIONED
- RECALIBRATION_REQUIRED
- MODEL_EVOLUTION_REQUIRED
- EQUIVALENCE_DEMONSTRATED
- APPLICATION_ENVELOPE_NARROWED
- UNRESOLVED_INSUFFICIENT_AUTHORITY
- REJECTED_NON_DISCREPANCY

New dispositions require codebook versioning.

## Confounding by modernization

Every inspected element records why it was inspected:

- SCHEDULED_SYSTEMATIC_RECONCILIATION
- SCIENTIFIC_QUALIFICATION
- MIGRATION_IMPLEMENTATION
- TEST_FAILURE
- DOCUMENTATION_WORK
- PERFORMANCE_WORK
- USER_APPLICATION_PROBLEM
- INCIDENTAL_CODE_READING
- HISTORICAL_SOURCE_RECONSTRUCTION
- OTHER

Planned and opportunistic inspection must remain distinguishable.

## Independent coding

Primary coding covers all cases. At least 30% of confirmed cases, spanning both models and multiple mechanisms, must be independently coded before consensus. Preserve pre-consensus coding. Report raw agreement and, where appropriate, Krippendorff's alpha.

## Analysis

Primary analysis is descriptive and mixed-methods. Report inspected elements, candidates, confirmed cases, exclusions, relation classes, emergent mechanisms, consequence classes, dispositions, regression detection outcomes and detection methods.

For sufficiently many paired replayable cases, exact McNemar may compare pre-existing regression with a predeclared independent-evidence procedure. No inferential test will be forced for a small dataset.

## Evidential target

Design target, not a success criterion:

- >=30 confirmed consequential prospective discrepancies overall;
- >=10 from each model;
- >=15 replayable RQ2 cases;
- repeated mechanisms;
- preferably >=3 mechanisms independently observed in both models.

## Duration and stop rule

Prospective observation lasts at least nine months and until a predefined reconciliation-coverage target has been reached in both models. Twelve months is preferred. Taxonomy saturation alone cannot terminate collection.

## Kill criteria

Narrow or abandon the standalone TRACE claim if:

K1. prior literature already combines prospective multi-model discrepancy capture, theory/documentation/code/executable reconciliation, consequence classification, regression comparison and authority disposition;
K2. findings reduce almost entirely to ordinary coding or obvious documentation defects already covered by existing taxonomies;
K3. pre-existing regression detects essentially all replayable consequential cases;
K4. one model yields too few eligible prospective cases for comparative replication;
K5. no defensible inspection denominator can be reconstructed;
K6. too many cases lack reproducible pre-resolution evidence;
K7. independent classification remains poorly reproducible despite codebook refinement;
K8. authority is trivial in nearly all cases, leaving no meaningful reconciliation problem.

## Historical/pilot separation

All cases known before freeze are stored separately and may support tooling, rater training and schema refinement, but are not pooled with prospective confirmatory observations.

## Amendment policy

Every protocol/schema/codebook amendment receives a version, date and reason. Earlier versions remain recoverable. Inclusion rules, RQs and hypotheses may not be silently altered after inspecting outcomes.

## Allowed eventual claim

If supported by data:

"We prospectively studied the emergence and resolution of scientifically consequential inconsistencies across multiple representations of two mature environmental models, preserved pre-resolution evidence, and directly tested whether existing regression-preservation evidence would have exposed each replayable case."

No claim of being the first theory-code reconciliation method, no generic claim that regression testing is unreliable, and no population-prevalence claim for environmental models is permitted.

## v0.2 pilot-calibration amendment

Before any prospective candidate was registered, six known pre-freeze cases (three SWAP and three ANIMO) were used as a historical pilot to stress-test the coding scheme. This pilot showed that `NUMERICAL` consequence must be distinguishable from physical/structural consequence, and that `MODEL_EVOLUTION_REQUIRED` is needed when evidence demonstrates missing scientific state or process representation rather than a local implementation repair. No research question, hypothesis, inclusion rule, prospective boundary, regression-counterfactual definition or kill criterion changed.
