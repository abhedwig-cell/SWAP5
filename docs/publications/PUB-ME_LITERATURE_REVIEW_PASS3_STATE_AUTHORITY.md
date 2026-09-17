# PUB-ME literature review pass 3: state-transition authority

Status: **targeted adversarial review, remaining novelty boundary**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Review date: 2026-09-18

## 1. Why this pass was needed

Pass 2 proposed comparing explicit state authority with output-regression-centered modernization. A further literature check showed that this comparator is still too weak if the experiment is framed merely as `richer scientific tests find faults that regression tests miss`.

Scientific-software literature already contains:

- mutation sensitivity analysis;
- metamorphic testing;
- regression-versus-metamorphic comparisons;
- causal testing;
- off-nominal/fault-injection validation.

SWMM has specifically been used as a scientific-software case for regression, mutation and metamorphic testing.

Therefore PUB-ME must not claim novelty for demonstrating that ordinary regression tests can miss bugs.

## 2. Narrow search target

This pass searched specifically for prior work on faults where a **rejected, retried or otherwise non-authoritative trial affects accepted scientific history**.

Concepts searched included combinations of:

- rejected timestep / rejected step;
- state contamination / side effects;
- accepted versus candidate state;
- rollback / restart;
- event handling on rejected steps;
- state-transition mutation;
- scientific simulation / PDE / ODE / hydrology;
- retry and committed history.

The search intentionally crossed numerical analysis, solver infrastructure and simulation software.

## 3. Findings

### 3.1 Rollback after rejected numerical steps is established practice

Adaptive integration and simulation frameworks already implement the conceptual rule that a rejected trial must not advance the accepted numerical solution. Existing numerical and co-simulation literature and infrastructure save/restore state, reject timesteps and retry from the previous accepted state.

Consequence:

- `a rejected timestep must roll back` is not a novelty claim;
- `accepted state versus rejected trial` is not novel terminology or numerical practice;
- checkpoint/restore and retry are not PUB-ME contributions by themselves.

### 3.2 Rejected-step side effects are a real software-failure mode

A concrete non-scholarly software example was found in the Diffrax ODE solver issue tracker: a terminating event was reported as firing even when the integration step had been rejected. The issue was acknowledged by maintainers as undesirable.

This is not peer-reviewed evidence and is not used to establish novelty. It is useful only as a plausibility example showing that side effects can escape the accepted/rejected-step boundary in real numerical software.

Consequence:

- the defect family targeted by PUB-ME is not artificial;
- the manuscript should nevertheless use preregistered SWAP experiments rather than relying on anecdotal external bugs.

### 3.3 No close peer-reviewed modernization study was identified in this targeted pass

This pass did **not** identify a peer-reviewed study that uses state-transition authority defects as the central empirical discriminator in the architectural modernization of a mature process-based environmental model.

In particular, no close study was found that simultaneously tests whether:

- a rejected candidate can mutate the accepted physical state;
- a retry can double-count accepted scientific flux/accounting;
- restart can capture speculative rather than accepted state;
- a candidate from a stale/wrong accepted origin can be committed;
- numerical warm-start or solver workspace can cross into authoritative physical state;
- side effects generated during rejected work can become externally published model history;

and then uses those results to qualify staged modernization against a legacy scientific denominator.

This is a **bounded search result**, not a priority proof. Further database/citation-chasing work may still identify a close equivalent.

## 4. Revised novelty boundary

After three review passes, the remaining candidate contribution is no longer:

- transactional simulation;
- rollback/retry;
- behavior-preserving refactoring;
- continuous verification;
- adversarial testing;
- mutation testing;
- evidence/change-impact analysis.

The most defensible remaining question is whether **making scientific state-transition authority explicit during model modernization has measurable protection value against a specific class of semantic contamination faults** that are poorly represented by normal successful-run output comparisons and generic software dependency analysis.

The evidence layer remains secondary but potentially useful if it can show that these state-authority semantics alter which prior scientific qualification remains valid after a change.

## 5. Recommended core research question after pass 3

> **During staged modernization of a mature time-stepped process model, does explicit authority over accepted scientific state reduce the risk of rejected or retried computation contaminating model history, accounting or restart state, beyond protection provided by conventional scientific regression and invariant testing?**

A secondary question can then ask:

> **Can those state-authority semantics be used to make requalification decisions more selective without losing scientifically relevant fault coverage?**

This ordering is important. The paper should first establish a scientific-state problem, then test whether the evidence/admission method adds value. It should not lead with governance or evidence graphs.

## 6. Comparator must be strengthened

The baseline comparator should no longer be called only `output-regression-centered modernization`.

A credible comparator should include established scientific-software practice:

1. reference/output regression;
2. conservation and domain invariants where already conventional;
3. restart checks where normally used;
4. conventional unit/integration testing;
5. generic mutation or metamorphic properties where applicable.

The candidate method adds **explicit authority tests at the transition between speculative and accepted scientific state**.

This avoids a straw-man comparison in which PUB-ME wins merely because the baseline is under-tested.

## 7. Preregistered defect families for the central experiment

Each defect should be designed before observing comparative results and should be scientifically plausible.

### D1 — rejected candidate mutates committed physical state

A trial that is later rejected changes one or more persistent physical state variables.

Primary consequence:
- subsequent accepted trajectory begins from the wrong origin.

### D2 — retry double-counts scientific exchange/accounting

Flux or storage accounting from a rejected attempt is retained and counted again after the successful retry.

Primary consequence:
- accepted mass/accounting history is inconsistent even if endpoint state appears plausible.

### D3 — wrong-origin candidate is accepted

A candidate computed from an earlier/stale revision or incompatible interval is committed to the current accepted lineage.

Primary consequence:
- accepted trajectory loses causal/state provenance.

### D4 — restart captures speculative state

A restart/checkpoint artifact is produced from candidate state before final acceptance.

Primary consequence:
- a restarted simulation continues from a history that never became scientifically accepted.

### D5 — numerical workspace becomes physical authority

Warm-start, Newton workspace, cached solver quantities or other disposable numerical state is reused as if it were accepted physical state after rejection/retry.

Primary consequence:
- a numerical optimization changes scientific history.

### D6 — rejected-trial side effect escapes transaction

Diagnostics, events, external publication, exchange ledgers or another externally visible scientific consequence is emitted by a rejected trial and survives rollback.

Primary consequence:
- external model history differs from accepted internal history.

## 8. Detection comparison

For each preregistered defect family report whether it is detected by:

| Detection layer | Purpose |
| --- | --- |
| reference/output regression | established behavior-preservation baseline |
| scientific conservation/invariant tests | established scientific consistency checks |
| restart/split-run regression | established continuity check |
| generic mutation/metamorphic tests | stronger established scientific testing |
| explicit state-authority contract | candidate PUB-ME addition |

Important outcome:

A positive paper result does not require conventional tests to miss every defect. The scientifically useful result is a reproducible mapping of **which failure classes require which authority information**, including overlaps and cases where the new layer adds no value.

## 9. Evidence-impact follow-up

Only after the state-authority experiment is established should PUB-ME test change-aware evidence selection.

For each real or seeded change ask:

- which scientific authority boundary is affected;
- which claims depend on that boundary;
- which evidence must therefore be replayed;
- which evidence remains independent and reusable.

Compare this against:

- full-suite replay;
- code/test dependency selection;
- state-authority/scientific-claim selection.

If the state-authority layer does not change selection in a useful and scientifically correct way, H-ME3 should be dropped rather than protected rhetorically.

## 10. Falsification criteria after pass 3

PUB-ME should cease to be protected as a standalone methods paper if:

1. a close peer-reviewed modernization study is found that already evaluates the same state-contamination problem and solution pattern;
2. the explicit state-authority layer detects no meaningful defect class beyond a strong conventional scientific-test baseline;
3. the selected defect families are only artificial implementation mistakes with no plausible route in legacy time-stepped simulation software;
4. state-authority tests reduce to ordinary assertions that can be expressed without the accepted/candidate distinction;
5. the evidence-impact layer adds no scientifically meaningful discrimination beyond generic change-impact analysis;
6. the final manuscript's strongest results are still only preservation/regression equivalence.

## 11. Current scientific feasibility verdict

**PUB-ME remains viable, but the novelty-bearing core has become narrow and empirical.**

The paper should now be built around one central proposition:

> Deep modernization of a stateful scientific simulator creates a specific risk at the boundary between computed candidate state and accepted scientific history; making that boundary explicit may provide measurable protection that is not captured by model-output equivalence alone.

Everything else, modularity, rollback, verification, provenance, evidence graphs and staged migration, should support or delimit this proposition rather than be presented as independently novel.

## 12. Literature status

This is still a targeted scoping review, not a completed systematic review. The strongest remaining literature gap should next be challenged through formal database searches and backward/forward citation chasing around:

- adaptive solver side-effect semantics;
- event handling during rejected integration steps;
- state-machine or temporal-property testing in scientific simulation;
- transactional correctness of simulation state publication;
- restart/checkpoint consistency under rejected/retried timesteps;
- semantic mutation operators for numerical state-transition software.
