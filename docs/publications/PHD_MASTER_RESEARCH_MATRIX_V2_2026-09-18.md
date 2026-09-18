# PhD five-paper master research matrix v2

Date: 2026-09-18  
Status: **PROSPECTIVE RESEARCH-DESIGN AUTHORITY FOR NEXT EXPERIMENTS**  
Branch reconciled at design start: `research/phd-five-paper-manifests-20260918@517c4bc76ead8baf5f3aab3ecf84f3f9f5def26e`  
Upstream adversarial review: `docs/publications/NOVELTY_STRESS_TEST_2026-09-18.md`

## 1. Purpose and authority

This matrix converts the five-paper portfolio into falsifiable research designs.

For every paper it binds:

```text
research question
    -> hypothesis
        -> experiment
            -> comparator/control
                -> primary endpoint
                    -> falsification criterion
```

The purpose is to prevent three forms of research drift:

1. changing the research question after seeing the decisive result;
2. substituting an easier comparator when the intended comparator is unfavorable;
3. turning infrastructure or software development into a scientific result without a predeclared inference.

This matrix is prospective. It does **not** rewrite or invalidate an experiment that was already frozen under an earlier manifest. Existing preregistrations and immutable result receipts retain their original authority. Where this v2 matrix narrows a future research question, that narrowing applies to new experiment design and manuscript interpretation.

A hypothesis may be supported, weakened or rejected. None of those outcomes authorizes changing the primary endpoint after result inspection.

## 2. Doctoral research question

### Overarching research question

> **How can changes in the numerical representation, solution and composition of an established process-based hydrological model be made scientifically testable and conditionally admissible rather than assumed equivalent?**

This question treats scientific equivalence as a claim that must be qualified, not as a consequence of successful implementation.

The five lines interrogate five different changes:

| Role | Change under test | Publication |
| --- | --- | --- |
| PRESERVE | change in state/acceptance architecture | PUB-ME |
| REPLACE | change in numerical solver | PUB-SQ |
| COUPLE | change from isolated to composed dynamic models | PUB-GC |
| ACCELERATE | change in interface information used by the coupling solver | PUB-RC |
| SCALE | change in spatial representation of heterogeneous vadose response | PUB-SG |

## 3. Portfolio architecture

```text
                               REPLACE / PUB-SQ
                              /
PRESERVE / PUB-ME -----------+
                              \
                               COUPLE / PUB-GC
                                  |          \
                                  |           SCALE / PUB-SG ?
                                  |
                           ACCELERATE / PUB-RC ?
```

Core programme:

- PUB-ME
- PUB-SQ
- PUB-GC

Conditional studies:

- PUB-RC only if hydrologically meaningful response information adds reproducible net value beyond a strong generic black-box accelerator.
- PUB-SG only if two-way shared-groundwater feedback adds a distinct, mechanistically interpretable transferability result beyond already-known regime-dependent vadose-zone upscaling.

The doctoral programme must remain coherent if either conditional paper fails its standalone-paper criterion.

---

# 4. PUB-ME — PRESERVE

## 4.1 Research question

> **Which scientifically consequential state-contamination faults can escape matched regression and invariant testing during staged model modernization, and to what extent does explicit candidate-to-accepted scientific-state authority prevent or earlier localize them?**

## 4.2 Protected contribution

A causal evaluation of explicit scientific-state authority as a fault-containment mechanism under matched scientific functionality.

PUB-ME does **not** claim novelty for modernization, checkpointing, rollback, state save/restore, transaction terminology, CI, regression testing or fault injection themselves.

## 4.3 Hypothesis matrix

| ID | Hypothesis | Decisive experiment | Comparator/control | Primary endpoint | Falsification / narrowing criterion |
| --- | --- | --- | --- | --- | --- |
| ME-H1 | A strong conventional regression/invariant architecture without enforced candidate-to-accepted authority still permits a non-empty class of prospectively defined boundary-crossing faults to alter accepted scientific history. | `PUB-ME-E2` paired B0/B1 adversarial campaign after no-fault equivalence is established | B0 no explicit candidate/accepted authority, with same equations, forcing, compiler route, oracles and external acceptance criteria as B1 | accepted-state contamination in B0, binary per valid injected run | No valid prospectively frozen fault family contaminates accepted B0 history; then the claimed problem class is not demonstrated |
| ME-H2 | Explicit candidate-to-accepted authority prevents accepted-state contamination for fault families whose causal path crosses the protected authority boundary. | Same `PUB-ME-E2` held-out campaign | B1 versus matched B0 for identical fault instance | accepted-state contamination in B1 | Any valid B1 contamination along a path claimed to be structurally contained falsifies the strong prevention claim; at least two mechanistically distinct families must show B0 contamination with B1 prevention for the broad H2 claim |
| ME-H3 | For valid faults not structurally prevented, explicit authority moves the first observable failure closer to the mutation source or reduces detection latency in accepted scientific time. | `PUB-ME-E2` plus selected `E3/E4` cases where prevention is not the expected mechanism | first detection in matched B0 versus B1 | first_detection_boundary and detection_latency_in_accepted_steps | No reproducible earlier localization or latency reduction across predeclared applicable families; then retain prevention-only claim or reject H3 |
| ME-H0 | In the absence of injected faults, B0 and B1 remain scientifically preservation-equivalent under the frozen oracles. | `PUB-ME-E1` and no-fault controls in E2 | B0 versus B1, no fault | frozen preservation metrics and accepted trajectories | Any material no-fault scientific difference invalidates the causal interpretation of E2 until repaired and re-frozen |

## 4.4 Minimum manuscript evidence

A standalone causal paper requires all of:

- ME-H0 passes;
- at least two mechanistically distinct prospectively frozen boundary-crossing fault families;
- non-empty B0 accepted-state contamination;
- zero B1 contamination for every fault path claimed to be structurally contained;
- provenance showing the fault definitions were fixed before the confirmatory outcomes.

Detection latency is secondary. It cannot rescue a failed prevention claim.

## 4.5 Kill or redirect

Redirect to a scientific-software/model-development case study if:

- B0/B1 cannot be made scientifically equivalent without faults;
- no meaningful boundary-crossing fault survives the conventional test architecture;
- B1 contaminates accepted state on an allegedly contained path;
- the result reduces to ordinary extra testing rather than an authority mechanism.

---

# 5. PUB-SQ — REPLACE

## 5.1 Research question

> **Under a prospectively frozen, candidate-independent scientific error contract, over what joint state, forcing and material domain can a numerically distinct Richards-equation solver be admitted as scientifically interchangeable within an established process model, and what computational advantage remains at matched scientific error?**

"Scientifically interchangeable" is explicitly conditional on the admitted domain.

## 5.2 Protected contribution

A prospective model-level solver-admission method in which:

1. the common Reference domain is established without new candidate outcomes;
2. scientific tolerances are frozen independently of the candidate;
3. candidate holdouts are judged conjunctively;
4. valid failures narrow the domain rather than being averaged away;
5. outside-domain behavior fails closed;
6. performance is compared only at matched accepted error.

The paper does not own the Ross algorithm, a generic Ross-versus-Newton benchmark or a dual-solver API.

## 5.3 Existing evidence boundary

Current evidence before this v2 matrix:

- P2E11/P2E11R: the original material-axis extension including Se=0.98 did not possess a complete common Reference state domain.
- P2E13: a Reference-only common 36-material tested domain was constructed, with complete Se levels 0.65 through 0.96 on the frozen grid and future anchors 0.65, 0.85 and 0.96 selected prospectively.
- P2E14: 36-material Reference-only thresholds were frozen at those three anchors before new RossFast extension execution.
- P2E15: all 180 previously unobserved material-axis candidate cases were paired-valid and admissible under the frozen thresholds.

This supports material-axis transfer **within the frozen common fixed-request domain**. It does not establish a universal solver domain, equal-error speed advantage, transaction-level equivalence or groundwater-coupled equivalence.

## 5.4 Hypothesis matrix

| ID | Hypothesis | Decisive experiment | Comparator/control | Primary endpoint | Falsification / narrowing criterion |
| --- | --- | --- | --- | --- | --- |
| SQ-H1 | Solver interchangeability is bounded and can be expressed as a reproducible admissibility domain over scientific state, forcing and material axes rather than as global equivalence. | `PUB-SQ-E2` prospectively frozen inside/boundary/outside matrix | RossFast against REF-HIGH under one immutable candidate-independent admission contract | conjunctive case admissibility and resulting domain classification | Failures/successes show no reproducible relation to predeclared domain variables, or the boundary can only be recovered by post-hoc threshold changes |
| SQ-H2 | Candidate-independent Reference-derived criteria transfer to untouched candidate cases inside the declared domain. | P2E15 is current material-axis primary evidence; future E2 extends to boundary/state/forcing structure | frozen P2E14 thresholds, no RossFast-dependent widening | holdout admissibility | A valid untouched inside-domain case violates the frozen contract; the domain must narrow and broad transfer claim weakens |
| SQ-H3 | On a non-empty subset of the common admissible domain, RossFast has lower total computational cost than Reference at matched scientific error. | `PUB-SQ-E3` equal-error cost study after E2 | RossFast versus Reference configurations in the same frozen accepted-error band | total computational cost at matched error, with work counters primary and stable timing secondary | No reproducible cost advantage after matching error, or advantage only occurs outside admitted domain; then no performance claim |
| SQ-H4 | Outside the admitted domain, the selected RossFast route fails closed without silent Reference substitution or accepted-state contamination. | E2 outside-domain/failure cases plus transaction-level fail-closed qualification where needed | requested RossFast route versus declared route/status authority | correct rejection/out-of-domain status and zero unauthorized accepted mutation | Any silent fallback, false acceptance or accepted-state contamination falsifies the fail-closed claim |

## 5.5 Immediate next experiment

The next primary PUB-SQ design is **inside / boundary / outside admissibility**, not performance.

Rules:

- P2E14 scientific thresholds remain immutable;
- the matrix must contain cases deliberately selected inside, near and outside the current declared domain;
- no failed boundary case may be replaced after inspection;
- Se=0.98 and WETTING retain their current exclusions unless independently re-qualified under a new pre-result design;
- equal-error cost work starts only after the boundary experiment is interpretable.

## 5.6 Kill or redirect

The general admission-framework claim weakens materially if:

- confirmatory thresholds need candidate-dependent widening;
- the observed boundary has no reproducible structure;
- REF-HIGH cannot establish a stable scientific reference for much of the intended domain;
- H3 fails and the remaining result is only a routine SWAP-specific solver benchmark.

---

# 6. PUB-GC — COUPLE

## 6.1 Research question

> **Which finite-window exchange and acceptance semantics are necessary for conservative, convergent and time-partition-consistent composition of independently time-integrating vadose-zone and groundwater models?**

This formulation deliberately asks which semantic choices matter, not merely whether one proposed implementation works.

## 6.2 Protected contribution

The candidate strict contract consists of:

- one accepted origin per coupling window;
- independent subsystem candidate integration;
- whole-window interface exchange;
- one authoritative action/reaction exchange ledger;
- no accepted scientific mutation from rejected subsystem or coupled candidates;
- atomic commit only after coupled acceptance.

None of these terms is assumed novel in isolation. PUB-GC owns only the demonstrated hydrological/numerical consequence of the contract and its constituent choices relative to fair alternatives.

## 6.3 Hypothesis matrix

| ID | Hypothesis | Decisive experiment | Comparator/control | Primary endpoint | Falsification / narrowing criterion |
| --- | --- | --- | --- | --- | --- |
| GC-H1 | Same-origin evaluation plus one authoritative exchange ledger preserves action/reaction exchange and accepted-state atomicity across a coupling window independently of admissible subsystem-internal substep partitions. | existing E0/E1 evidence plus explicit internal-partition perturbation where not yet covered | repeated same interface candidate from identical accepted origin under different valid internal partitions; diagnostic contaminated-origin run is secondary only | committed exchange closure; zero rejected-state publication; repeatability from accepted origin | accepted exchange or state depends materially on admissible internal partition beyond subsystem tolerance, or rejected candidates publish authoritative transfer |
| GC-H2 | Whole-window exchange produces lower transient interface error or lower time-partition sensitivity than terminal instantaneous exchange in predeclared regimes where within-window flux varies materially. | `PUB-GC-E2` | whole-window exchange versus terminal-flux comparator under identical subsystem physics and acceptance criteria | coupled error relative to GC-REF, reported separately for head, cumulative exchange and selected vadose state | No prospectively frozen mechanism case shows a material distinction, or any apparent gain disappears at matched coupling error |
| GC-H3 | Refining coupling-window duration and outer acceptance tolerance drives the accepted coupled solution toward a stable strict numerical reference. | `PUB-GC-E3` window/tolerance refinement ladder | candidate methods against GC-REF; same subsystem numerical authority | component-wise error versus GC-REF and convergence trend | no stable refinement trend; reference itself unstable; or outer convergence is dominated by unresolved subsystem temporal error |
| GC-H4 | The validity domain of strict same-origin finite-window coupling differs measurably from loose/sequential or established-style relaxed feedback in strong-feedback regimes. | `PUB-GC-E4` robustness domain | loose sequential, fair relaxed head/flux feedback, restricted same-origin predictor/corrector, converged same-origin method where qualified | joint pass/fail on hard invariants plus normalized component-wise coupled error | fair comparators are indistinguishable across all predefined practical regimes, or differences exist only for intentionally contaminated controls |
| GC-H5 | The semantic/numerical consequence established on the transparent GW-A system transfers without method-specific retuning to a minimal auditable MODFLOW 6 backend. | `PUB-GC-E5` | predeclared easy and strong-feedback GW-B MODFLOW 6 holdouts, frozen before method outcomes | same GC error/invariant endpoints as GW-A plus MODFLOW solver diagnostics | effect disappears under MODFLOW 6, requires comparator-specific retuning, or the admitted backend cannot reproduce the declared interface semantics |

## 6.4 Supporting but not primary GC evidence

- bounded N:1 conservation;
- coupling API wiring;
- transaction checkpoint/replay implementation;
- diagnostic history-contaminated negative controls;
- realistic case demonstration.

These may support the method but do not by themselves establish GC novelty.

## 6.5 Required comparator discipline

At least one serious prior-practice comparator must survive into the final design. A deliberately weak sequential implementation is insufficient.

Where scientifically implementable, the comparison set should include:

- loose/sequential exchange;
- established-style relaxed head/flux feedback;
- terminal exchange;
- restricted same-origin predictor/corrector;
- converged same-origin whole-window iteration.

Every comparator must use the same subsystem physics and the same accepted-error and conservation gates.

## 6.6 Kill or redirect

The broad methods paper should narrow if:

- strict semantics give no distinguishable accuracy, conservation, partition-sensitivity or robustness result against fair comparators;
- the result exists only against an intentionally contaminated diagnostic control;
- the effect fails transfer to minimal MODFLOW 6;
- apparent advantages disappear under matched error.

A SWAP5-MODFLOW6 integration paper may still be valid even if the broader method claim fails.

---

# 7. PUB-RC — ACCELERATE

## 7.1 Research question

> **What is the lowest-order hydrologically meaningful whole-window response information that produces a reproducible net reduction in coupled-solve cost at matched coupled error and robustness beyond strong generic black-box acceleration?**

## 7.2 Protected contribution

PUB-RC is an information-content study, not a claim to have invented quasi-Newton, secant, tangent, Aitken, Broyden or waveform coupling.

Response ladder:

| Level | Information exposed |
| --- | --- |
| R0 | residual/base fixed-point information |
| R1 | residual history plus strong generic black-box acceleration |
| R2 | local whole-window hydrological secant, e.g. ΔQ_window / ΔH |
| R3 | explicit local whole-window tangent, e.g. dQ_window / dH |
| R4 | richer time-dependent/block response, prohibited until R2/R3 show unresolved benefit |

## 7.3 Hypothesis matrix

| ID | Hypothesis | Decisive experiment | Comparator/control | Primary endpoint | Falsification / merge criterion |
| --- | --- | --- | --- | --- | --- |
| RC-H1 | R2 or R3 reduces net total coupled-solve cost relative to strong R1 in prospectively defined strong-feedback regimes at the same accepted coupled error and robustness. | frozen R0/R1/R2/R3 matrix on stable PUB-GC problem | R1 must include Aitken plus at least one serious derivative-free/history-based quasi-Newton baseline | total work at matched coupled error, including subsystem and response evaluations | R1 matches or beats R2/R3 after response-acquisition cost and safeguards are included |
| RC-H2 | Any R2/R3 advantage transfers to an unseen response regime and to a MODFLOW 6 holdout without retuning method-specific controls. | synthetic holdout plus inherited-but-untuned GW-B holdout | fixed controls from design set | same total-cost endpoint plus hard PUB-GC accuracy/conservation gates | advantage confined to tuned GW-A case, vanishes under MODFLOW 6, or requires retuning |
| RC-H3 | There is a lowest sufficient response-information level beyond which extra derivative detail yields no practically relevant net benefit. | compare R2 versus R3; admit R4 only if predeclared unresolved need remains | adjacent ladder levels | marginal work reduction, robustness gain and acquisition cost | no stable saturation/ordering can be identified; then no "lowest-order sufficient information" claim |
| RC-H4 | Response-assisted updates fail safely when derivative information is unavailable, singular, nonsmooth or inconsistent with subsystem admissibility. | safeguard challenge set | response-assisted route versus fallback declared before outcome | zero hard-gate violation; bounded retry/window-reduction behavior | response data override PUB-GC hard scientific gates or create accepted-state inconsistency |

## 7.4 Standalone-paper rule

PUB-RC remains a standalone article only if RC-H1 and RC-H2 survive.

RC-H3 can strengthen the paper but cannot compensate for failure of the incremental-value claim.

If strong generic black-box acceleration is enough, the negative result belongs in PUB-GC or thesis synthesis.

---

# 8. PUB-SG — SCALE

## 8.1 Revised research question

The earlier question "when does an equivalent single column cease to be transferable across hydrological regimes?" is too broad after literature stress testing.

The prospective v2 question is:

> **How does two-way dynamic shared-groundwater feedback alter the cross-regime transferability of a calibrated equivalent full-process vadose-zone column relative to explicit heterogeneous subcolumns, and which hydrological response transitions determine the resulting aggregation-error boundary?**

This revised question governs future PUB-SG experiment design. No prior result may be retroactively relabelled as confirmation of this narrower hypothesis.

## 8.2 Protected contribution

PUB-SG does not claim:

- that heterogeneous vadose zones can require upscaling;
- that equivalent hydraulic properties depend on boundary conditions;
- that nonlinear averaging can fail;
- that multiple SVAT/vadose columns can map to one groundwater cell.

Its candidate contribution is the incremental effect and mechanism of **two-way dynamic shared-groundwater feedback** on transferability of a frozen equivalent full-process column.

## 8.3 Experimental systems

### Explicit truth system

```text
N heterogeneous full dynamic vadose columns
        |
        | weighted whole-window exchange
        v
one shared dynamic groundwater cell
        |
        +---- head feedback to every column
```

Each subcolumn retains its own accepted state.

### Reduced system

One equivalent full SWAP column calibrated only in regime R_A. Parameters and objective weights are frozen before holdout regimes.

### Critical feedback control

The same heterogeneous columns must also be evaluated under a prescribed groundwater-head trajectory or another defensible one-way groundwater boundary that removes the shared dynamic feedback loop while preserving the relevant boundary history as far as scientifically possible.

This control is required to distinguish a new groundwater-feedback effect from already-known boundary-condition dependence.

## 8.4 Hypothesis matrix

| ID | Hypothesis | Decisive experiment | Comparator/control | Primary endpoint | Falsification / merge criterion |
| --- | --- | --- | --- | --- | --- |
| SG-H1 | Two-way dynamic shared-groundwater feedback changes the cross-regime transferability error of a frozen equivalent column beyond the error observed under an otherwise comparable prescribed-head/one-way boundary treatment. | paired dynamic-feedback versus prescribed-head holdout matrix after one calibration regime | explicit N:1 truth and frozen equivalent column under both feedback treatments | component-wise cross-regime transferability error and incremental feedback effect ΔE_feedback above numerical floor | dynamic and prescribed-head errors are indistinguishable within predeclared numerical/materiality bounds across the intended regimes |
| SG-H2 | The incremental feedback effect is concentrated around identifiable hydrological response transitions, such as drainage ↔ capillary rise, groundwater entry into root influence, or lower-boundary response switching. | mechanism-stage contrasts followed by frozen transition holdouts | cases spanning the same static heterogeneity but different dynamic response regimes | error change conditioned on response transition; exchange/head/storage/ET components reported separately | no response-transition mechanism explains the incremental effect better than generic static contrast or case identity |
| SG-H3 | A non-empty weak-feedback/low-contrast domain exists in which the equivalent column remains transferable across holdout regimes and explicit subgrid representation provides little scientific gain. | low-contrast/deep-groundwater/weak-feedback holdouts | frozen equivalent versus explicit N:1 | all primary component errors below predeclared materiality thresholds | equivalent column fails broadly even in the predeclared weak-feedback controls; then the proposed regime boundary is misplaced and must be reformulated before manuscript claim |
| SG-H4 | Static parameter variance alone is an inferior predictor of transferability failure to response-based measures that include groundwater-feedback strength and regime transition. | post-primary explanatory analysis using predictors declared before fitting the final model | static heterogeneity descriptors versus hydrologically interpretable response/feedback descriptors | out-of-sample explanatory/predictive performance on frozen holdouts | response-based descriptors do not improve interpretable prediction beyond static descriptors; then retain only direct experimental result, not predictive regime-map claim |

## 8.5 Error decomposition requirement

Before a spatial aggregation effect is called scientific, the design must bound and separate:

- solver error;
- coupling error;
- common numerical-reference uncertainty;
- equivalent-model calibration error;
- spatial aggregation/transfer error;
- incremental two-way feedback effect.

The PUB-GC configuration used for SG must place coupling error below the aggregation-effect scale.

## 8.6 Standalone-paper rule

PUB-SG remains standalone only if SG-H1 survives and at least SG-H2 or SG-H3 yields a mechanistically interpretable boundary.

If all transferability loss is already explained by prescribed-boundary behavior known from prior upscaling literature, the result should merge into thesis synthesis or a broader coupled-model paper rather than be forced into a separate article.

---

# 9. Cross-paper claim firewall v2

| Scientific inference | Sole primary owner | Other papers may use |
| --- | --- | --- |
| causal fault containment by candidate-to-accepted authority | PUB-ME | implementation infrastructure and accepted-state semantics |
| solver admission domain and equal-error solver cost | PUB-SQ | qualified solver route and numerical uncertainty floor |
| base vadose-groundwater coupling correctness, conservation, convergence and semantic validity domain | PUB-GC | stable coupling problem and reference |
| incremental benefit/cost of response information | PUB-RC | PUB-GC reference and cases |
| transferability consequence of spatial representation under dynamic shared groundwater | PUB-SG | PUB-GC N:1 conservation and strict coupling configuration |

A single primary figure/table/result may have only one owner.

## 9.1 Explicit anti-overlap rules

### ME versus GC

The same-origin/replay mechanism may be shared infrastructure. ME owns the general fault-containment inference. GC owns hydrological coupling consequences.

### SQ versus GC

GC may select a solver already qualified by SQ but may not reuse solver-admission outcomes as a GC contribution.

### GC versus RC

RC must solve exactly the coupling problem established by GC. It cannot claim conservation, same-origin or whole-window semantics as new.

### GC versus SG

GC may prove that N:1 exchange is numerically conservative. SG alone owns whether explicit heterogeneity is hydrologically necessary.

### SQ versus SG

SG must quantify its numerical floor using a qualified solver configuration; it cannot treat solver discrepancy as spatial aggregation.

---

# 10. Programme-level falsification map

The doctoral programme is intentionally robust to negative paper outcomes.

| Outcome | Programme consequence |
| --- | --- |
| ME causal advantage not demonstrated | modernization becomes supporting methodology, not core causal paper |
| SQ material/state domain proves very narrow | still publishable if prospectively characterized and scientifically interpretable; universal-equivalence claim is prohibited |
| SQ equal-error speed advantage absent | remove performance claim; admission-domain result may remain if independently strong |
| GC strict semantics indistinguishable from fair comparators | narrow to integration/model-development paper; do not claim general coupling method |
| RC generic black-box acceleration matches hydrological response methods | merge RC into GC/thesis synthesis |
| SG dynamic feedback adds no incremental transferability effect | merge SG into synthesis or report negative practical result; no standalone novelty claim |

Negative evidence is part of the programme evidence graph and must be retained.

---

# 11. Immediate next permitted work by paper

## PUB-ME

Materialize the research-only matched B0/B1 bypass/injector harness without altering the frozen causal endpoint. Run no confirmatory campaign until no-fault equivalence and injector validity are qualified.

## PUB-SQ

Preregister the inside/boundary/outside admissibility experiment against immutable P2E14 scientific thresholds. Do not move to performance merely because P2E15 was favorable.

## PUB-GC

Prioritize discriminating experiments:

1. E2 whole-window versus terminal exchange on new pre-frozen transient mechanism cases;
2. E3 convergence/refinement against GC-REF;
3. E4 fair comparator robustness domain;
4. E5 transfer to admitted MODFLOW 6.

Do not spend publication effort on additional architecture evidence unless one of these experiments requires it.

## PUB-RC

Do not execute primary R2/R3 experiments yet. First define a genuinely strong R1 baseline and a machine-independent work accounting scheme on the stable GC problem.

## PUB-SG

Before a large heterogeneity ensemble:

1. revise the SG research manifest to the dynamic-feedback question;
2. specify the prescribed-head/one-way control;
3. define the calibration/holdout regime split;
4. define the numerical floor inherited from SQ/GC;
5. run a small mechanism stage capable of falsifying SG-H1 early.

---

# 12. Version-2 freeze rule

Any future change to:

- a research question;
- a primary endpoint;
- a primary comparator;
- a hypothesis falsification criterion;
- a standalone-paper kill rule;

must be recorded as a new version with:

1. reason for change;
2. evidence known at the moment of change;
3. explicit statement whether decisive outcomes had already been inspected;
4. effect on existing preregistrations;
5. new permitted next action.

No change may retroactively convert exploratory evidence into prospectively confirmatory evidence.
