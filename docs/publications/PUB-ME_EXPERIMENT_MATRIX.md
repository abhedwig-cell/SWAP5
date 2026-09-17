# PUB-ME publication experiment matrix

Status: **prospective experiment design**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Primary purpose: turn the SWAP4.3.1 -> SWAP5 modernization history into an empirical study of **evidence-preserving scientific model evolution**, rather than a retrospective software narrative.

This matrix is subordinate to `PUB-ME_SCIENTIFIC_CONTRACT.md` and uses `EXPERIMENT_MANIFEST.md`.

## 1. Experimental principle

The paper must test a method, not merely describe an architecture.

The core empirical unit is a **migration slice**:

```text
legacy ownership / behaviour
        |
        v
bounded architectural change
        |
        v
new ownership / behaviour
        |
        v
preservation, invalidation or intentional semantic change
```

Each selected slice must have an explicit scientific risk and independent evidence that determines whether the slice preserved the intended model semantics.

## 2. Migration-slice selection rule

Avoid selecting only visually clean or fully successful cases.

Before manuscript extraction, freeze a small stratified set including at least:

1. one state-ownership migration;
2. one time/transaction migration;
3. one solver/service-boundary migration;
4. one restart/persistence migration;
5. one later semantic-successor event where old evidence became stale and required requalification.

Candidate historical episodes include, subject to exact authority audit:

- state versus workspace separation;
- candidate versus committed state;
- transactional interval orchestration;
- mandatory typed soil-water solver seam / HeadCalc isolation;
- restart of accepted continuation state;
- F-CI75/F-CI93 style semantic-successor preservation after legitimate composition changes.

The final selection must be frozen before detailed manuscript extraction to reduce success-case cherry-picking.

## 3. Benchmark matrix

Use a fixed set of scientifically meaningful SWAP cases spanning at least:

- dry profile / infiltration;
- wetter profile / drainage;
- shallow-groundwater or capillary-sensitive case where inside the selected historical scope;
- atmospheric forcing transition;
- restart/split-run case;
- at least one case that exercises retry/rejection semantics.

The benchmark matrix should preferentially use preserved testbank/reference cases with known provenance. New synthetic cases may be added only when a migration risk is not exercised by the existing bank.

## 4. Core experiment families

### ME-E0 — Reference lineage reconstruction

Hypothesis support: H1, H3.

Purpose: define exactly what "preservation" means at each selected historical stage.

For each selected migration slice record:

- source commit/tree;
- target commit/tree;
- reference authority used at that time;
- corrected-reference authority if applicable;
- intended semantic delta: `NONE`, `BOUNDED`, or `SCIENTIFIC_CHANGE`;
- exact benchmark/test evidence used for admission;
- evidence later invalidated, superseded or retained.

Primary output:

- `PUB-ME-T01`: reference/evidence lineage table.

This is a prerequisite, not a novelty result by itself.

### ME-E1 — Behaviour preservation across representative migration slices

Hypothesis: H1.

Purpose: test whether major ownership restructuring preserved the declared scientific behaviour.

Design:

For each frozen migration slice, rerun or re-extract the common benchmark matrix on the exact pre/post authorities where executable reconstruction is possible.

Primary metrics:

- endpoint and trajectory state differences;
- integrated water-balance term differences;
- mass residual;
- accepted/rejected timestep sequence where relevant;
- restart continuation result;
- deterministic identity or tolerance-qualified difference.

Classification:

- historical reruns are `RETROSPECTIVE_REEXTRACTION`;
- any newly constructed controlled replay designed under this matrix is `PROSPECTIVE_PRIMARY`.

Candidate figure:

- `PUB-ME-F01`: preservation error by migration slice and benchmark regime.

Important analysis rule:

Do not collapse all slices into one pass/fail statistic. The paper should show which semantics were required to remain exact, which were tolerance-qualified, and which changed intentionally.

### ME-E2 — Candidate-state contamination adversarial experiment

Hypothesis: H2.

Purpose: show empirically why candidate/committed-state separation matters.

Construct a controlled diagnostic harness around an admitted transaction-capable route.

Compare:

1. normal transaction semantics;
2. a diagnostic fault-injection variant that intentionally leaks one selected candidate mutation into the next retry/accepted state.

The fault-injection route must never become production code or authority.

Stress cases:

- nonlinear solver failure followed by retry;
- rejected timestep after partial candidate state update;
- failed publication/preflight where applicable.

Primary metrics:

- accepted-state digest before retry;
- accepted endpoint after retry;
- mass/storage divergence;
- restart/replay divergence;
- downstream trajectory divergence.

Candidate figure:

- `PUB-ME-F02`: clean rollback versus injected candidate-state leakage.

This experiment is important because it turns an architectural invariant into an observable scientific consequence.

### ME-E3 — Restart sufficiency experiment

Hypothesis: H2.

Purpose: test whether admitted committed continuation state is sufficient for reproducible continuation without serializing arbitrary scratch/candidate state.

Design:

For selected benchmark cases:

- continuous run from `t0` to `t2`;
- split run `t0 -> t1`, persist admitted restart state, resume `t1 -> t2`;
- compare accepted trajectory and accounting after `t1`.

Include at least one case with retries before the restart point and one without.

Primary metrics:

- state identity/difference at `t2`;
- cumulative mass terms;
- accepted timestep history after restart;
- lineage/provenance reconstruction.

Candidate artifact:

- `PUB-ME-T02`: restart continuation preservation.

### ME-E4 — Evidence invalidation and semantic-successor experiment

Hypothesis: H3.

Purpose: demonstrate that evidence preservation is dependency-aware rather than hash-preservation theater.

Use at least two historical longitudinal cases:

#### Case A: unrelated change

A change outside a capability's dependency surface where immutable evidence remained valid.

Show:

- exact dependency comparison;
- rationale for reusing evidence;
- preservation outcome.

#### Case B: legitimate overlapping change

A later admitted change that altered a previously pinned production blob or composition surface.

Candidate historical example: F-KT21/F-CI75 followed by F-CI93 requalification of F-SI35 moving-current semantics.

Show:

- old exact-postimage guard failure;
- classification as evidence invalidation rather than immediate scientific defect;
- targeted semantic replay;
- establishment of successor authority only after replay.

Primary output:

- `PUB-ME-F03`: evidence dependency/semantic-successor timeline.

This experiment is central to the paper's distinction from ordinary regression testing.

### ME-E5 — Bounded migration versus broad-rewrite counterfactual analysis

Hypothesis support: H3.

Status: **methodological analysis, not necessarily executable experiment**.

Purpose: test whether the bounded-capability method actually reduces the scientific requalification surface.

For selected historical stages, calculate from repository dependency/evidence records:

- files/capabilities touched;
- qualified dependency surface;
- number of preserved evidence chains reusable;
- number requiring targeted replay;
- number requiring new scientific qualification.

Compare this with a declared counterfactual in which the same architectural changes were treated as one monolithic rewrite requiring whole-denominator requalification.

Be careful: this is not a measured development-effort comparison unless actual effort data exist. The defensible quantity is **qualification surface**, not claimed person-hours saved.

Candidate figure:

- `PUB-ME-F04`: bounded versus hypothetical whole-denominator requalification surface.

### ME-E6 — Extensibility without claim transfer

Hypothesis: H4.

Purpose: demonstrate that later scientific extensions can use admitted seams without becoming evidence for the modernization paper's own scientific claims.

Use two post-Status-A examples:

- RossFast selection behind the typed soil-water solver seam;
- external groundwater coupling behind admitted exchange/gateway seams.

Measure/document:

- pre-existing interface contract reused;
- denominator/source that remained unchanged;
- qualification required specifically for the extension;
- evidence inherited versus newly created.

Primary output:

- a bounded architecture/evidence diagram, not RossFast performance or groundwater accuracy results.

Candidate artifact:

- `PUB-ME-F05`: extension composition over preserved scientific denominator.

## 5. Prospective primary tranche

Because much of SWAP5 modernization already happened before this publication hypothesis, the paper must include at least one genuinely prospective experiment rather than relying entirely on retrospective interpretation.

Recommended prospective primary tranche:

1. freeze the migration-slice set before detailed extraction;
2. freeze the common benchmark matrix;
3. execute ME-E1 controlled pre/post reruns where historical builds can be reproduced;
4. execute ME-E2 candidate-state fault-injection experiment;
5. execute ME-E3 restart sufficiency experiment;
6. predeclare the two ME-E4 longitudinal cases before writing results.

This provides prospective analysis discipline even though the architectural changes themselves are historical.

## 6. Historical reconstruction rules

Historical evidence may be used only when:

- exact commit/tree is known;
- build/run requirements are reconstructable enough to make the comparison meaningful;
- input/reference identities are known;
- later semantic changes are not silently backported into the historical result.

If an old stage cannot be reproducibly built, classify it as documentary evidence and do not invent a numerical comparison.

## 7. Primary metrics

The paper should use metrics from three categories.

### Scientific preservation

- state trajectory difference;
- water-balance difference;
- restart continuation difference;
- accepted/rejected execution difference.

### Architectural authority

- number/type of distinct state owners;
- mutation boundary before/after;
- candidate/committed separation;
- explicit persistence/publication boundary.

These should be treated descriptively; avoid dubious scalar "architecture quality scores".

### Evidence preservation

- inherited evidence count/surface;
- targeted replay surface;
- invalidated evidence surface;
- newly required qualification surface.

Repository dependency data should be the source, not subjective estimates.

## 8. Predeclared unfavorable outcomes

Possible scientifically meaningful results include:

- some migration slices cannot be shown to preserve behaviour as cleanly as expected;
- bounded admission creates substantial evidence overhead;
- old architecture already prevented some candidate leakage, reducing the contrast;
- restart requires more state than the minimal conceptual model suggested;
- evidence dependency boundaries are difficult to define without SWAP-specific governance;
- the transferable contribution is narrower than originally hypothesized.

These outcomes should narrow the paper rather than be hidden.

## 9. Manuscript artifact plan

Candidate primary artifacts:

- `PUB-ME-T01`: reference and authority lineage;
- `PUB-ME-F01`: preservation across representative migration slices;
- `PUB-ME-F02`: adversarial candidate-state leakage;
- `PUB-ME-T02`: restart/split-run preservation;
- `PUB-ME-F03`: evidence invalidation and semantic-successor timeline;
- `PUB-ME-F04`: qualification-surface analysis;
- `PUB-ME-F05`: later extension over preserved seams.

The final manuscript should select only artifacts required by the central argument.

## 10. Go/no-go after evidence extraction

Continue toward a standalone `PUB-ME` paper only if the evidence supports more than "refactoring plus tests".

At least two of the following should be demonstrated:

- explicit state authority prevents an observable scientific continuation defect under adversarial failure/retry;
- bounded migration preserves scientifically meaningful trajectories across major ownership changes;
- dependency-aware evidence invalidation/reuse materially differs from static regression/hash preservation;
- later numerical/coupling extensions can be admitted through preserved seams without requalifying the full scientific denominator;
- a transferable lifecycle/qualification pattern can be stated without relying on SWAP-specific names.

If these are not supported, `PUB-ME` should be narrowed to a software case study or absorbed into the doctoral synthesis instead of overstating methodological novelty.
