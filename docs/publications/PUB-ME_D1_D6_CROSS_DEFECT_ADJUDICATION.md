# PUB-ME D1-D6 cross-defect adjudication

Status: **PROVISIONAL_GO__REPLICATION_AND_NOVELTY_REVIEW_REQUIRED**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Adjudication date: 2026-09-18

## 1. Authority

Preregistered design:

- branch/head: `work/pub-me-literature-pass2@b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`

Current result authority inspected for this adjudication:

- `integration/f-ci-canonical@7b864853ca22baa73141b2dec9ed2f3915ef520d`

Canonical result records inspected:

- `PUB-ME_D1_RESULT.json`
- `PUB-ME_D2_RESULT.json`
- `PUB-ME_D3_RESULT.md`
- `PUB-ME_D4_RESULT.md`
- `PUB-ME_D5_RESULT.md`
- `PUB-ME_D6_RESULT.md`

This adjudication does not modify or reinterpret the frozen D1-D6 classifications.

## 2. First-pass result matrix

| Defect | Scientific authority boundary | Result class | B1 first detection/prevention | B2 first detection/prevention | Scientific/history consequence if allowed |
| --- | --- | --- | --- | --- | --- |
| D1 | committed physical storage versus candidate mutation | STRUCTURAL_PREVENTION | no executable public write-through mutant | public interface prevents mutable alias; snapshots are clones | direct public-interface contamination is unrepresentable |
| D2 | rejected-trial exchange versus accepted accounting | EARLIER_DETECTION | post-accept accepted-total regression | nonzero accepted ledger detected at retry entry | double-counted accepted side ledger while accepted endpoint and canonical accounting remain unchanged; net mass closure can remain green |
| D3 | candidate provenance versus accepted lineage/revision/time | STRUCTURAL_PREVENTION | invalid commit never becomes a normal accepted comparison | commit seam rejects wrong lineage, stale revision and wrong time origin before state mutation | wrong-origin accepted history is structurally prevented |
| D4 | speculative state versus persisted/restarted accepted state | EARLIER_DETECTION | restart round-trip detects mismatch after faulty artifact restore | accepted-state/payload authority mismatch detected before persistence publication | resumed history advances from a state that was never accepted; local mass checks can remain green |
| D5 | solver workspace versus physical retry origin | EARLIER_DETECTION | post-retry endpoint/storage comparison | wrong physical origin detected before retry solve | retry converges from solver scratch promoted to physics and produces a different accepted state/storage |
| D6 | rejected local result versus externally accepted publication | EARLIER_DETECTION | external accepted-output regression after observer emission | transaction authority rejects publication before emission | externally visible accepted history contains rejected-work output while physical state remains unchanged |

No D1-D6 family produced `UNIQUE_DETECTION`.

That absence is scientifically important and must remain visible in the manuscript.

## 3. Conservative independence analysis

The six experiments are not six statistically independent observations. They share one overarching concept: authority over transitions from non-authoritative computation to accepted scientific history.

For manuscript interpretation, use a conservative mechanism grouping.

### M1 — authoritative state / commit integrity

Defects:

- D1: direct alias/write-through into committed physical storage;
- D3: wrong lineage/revision/time candidate offered to commit.

Common theme:

- authoritative accepted state may change only through the admitted commit contract.

Distinct submechanisms:

- D1 is ownership/alias isolation;
- D3 is causal/provenance authorization.

For conservative publication counting, do **not** count D1 and D3 as two fully independent mechanisms.

### M2 — accepted accounting authority

Defect:

- D2.

Distinctive property:

- accepted accounting can be contaminated even while the final accepted physical endpoint and canonical accepted accounting remain unchanged and net mass closure remains green.

This is materially distinct from M1 because the contaminated scientific history is an accepted side ledger rather than committed physical state.

### M3 — persistence/restart authority

Defect:

- D4.

Distinctive property:

- a candidate-derived state can become durable scientific history through persistence even when the in-memory accepted carrier was not mutated.

This is materially distinct from M1/M2 because the authority transfer occurs through a persistence artifact and affects later continuation.

### M4 — numerical-workspace versus physical-state authority

Defect:

- D5.

Distinctive property:

- numerically meaningful solver scratch can be physically well-formed yet still have no authority to become the start state of a retry.

This is materially distinct from simple aliasing or provenance mismatch because the wrong state may be numerically plausible and the subsequent solve may converge normally.

### M5 — external publication authority

Defect:

- D6.

Distinctive property:

- rejected work can contaminate externally visible accepted history without changing physical state, restart state or mass ledgers.

This is materially distinct from M1-M4 because the irreversible consequence is observer/publication state.

## 4. Preregistered threshold adjudication

The preregistered strong-support threshold requires:

> at least two materially different defect families with reproducible EARLIER_DETECTION, UNIQUE_DETECTION or STRUCTURAL_PREVENTION, a demonstrated scientific/history consequence, no matched-control false positive, and the full B1 comparator.

### Current evidence

D2, D4, D5 and D6 all provide executable contamination faults with:

- a clean matched control;
- strong B1 detection after the relevant operation or acceptance boundary;
- B2 detection before the contamination becomes accepted/reused/emitted history;
- an explicit scientific/history consequence;
- no reported matched-control false positive.

These four results span at least four different authority sinks under the conservative grouping:

- accounting;
- restart/persistence;
- physical retry origin;
- external publication.

Therefore the **mechanism-level minimum positive-family threshold is provisionally exceeded**.

D1 and D3 provide additional structural-prevention evidence but are not needed to make that threshold.

## 5. What the results do and do not support

### Supported at first pass

The D1-D6 set supports the bounded claim that explicit candidate-to-accepted transition authority can provide incremental protection beyond a strong conventional B1 test baseline through:

- structural prevention of invalid state transitions; and/or
- earlier localization of contamination before it becomes accepted scientific history.

The strongest empirical pattern is **earlier detection/localization**, not unique defect coverage.

### Not supported

The results do not support:

- that conventional scientific regression/invariant testing is inadequate;
- that B2 uniquely detects defects B1 cannot detect;
- a population-level defect-detection rate;
- a universal architecture theorem;
- novelty of rollback, commit, provenance checks, restart testing, mutation testing or observer gating;
- a claim that SWAP5 production contained D1-D6 defects;
- hydrologic-regime generality from the first fixture set.

## 6. Key manuscript consequence

The central paper claim should not be:

> explicit scientific-state authority detects bugs that ordinary testing misses.

The evidence instead supports the narrower formulation:

> explicit transition-authority contracts can move detection/prevention to the point where non-authoritative computation attempts to become accepted scientific history, before downstream regression, restart, accounting or publication checks observe the consequence.

This is a temporal/causal localization claim.

That distinction must remain central to avoid overstating the results.

## 7. Physical-regime replication obligation

The preregistration requires at least two materially different Reference regimes where a defect operator is physically meaningful.

Priority replication is required for the results whose effect magnitude depends on hydrologic/numerical dynamics.

### Mandatory priority

- D2: repeat the rejected-throughflow accounting operator in a materially different Reference regime.
- D5: repeat workspace-to-physical-origin misuse in a materially different Reference regime.

### Strongly desirable

- D4: demonstrate the same accepted-versus-speculative restart authority on a hydrologically richer continuation state if a bounded existing fixture is available.

### Lower value for regime replication

- D1 and D3 are predominantly interface/authority invariants and are not expected to depend strongly on hydrologic regime.
- D6 is primarily an integration/publication-lifecycle defect; hydrologic regime replication adds less information unless the observer payload itself depends materially on regime.

No result-dependent tuning of thresholds or fault operators is permitted during replication.

## 8. Status of the abandoned/parallel D1-B PR

Open draft PR #220 attempts an additional executable D1 lower-layer contamination mutant.

Its current experiment run failed before scientific execution because the qualification test bound `fmr_serialized_reference_backend_t` directly as a `transaction_model_t`, which is not the admitted type hierarchy.

This is an experiment-setup error, not a scientific result.

Because D1-A is already canonical and the D1-D6 primary set now contains multiple executable EARLIER_DETECTION families, repairing PR #220 is **not required for the preregistered go/no-go threshold**.

PR #220 may be retained as optional supplementary D1 evidence, but it must not block cross-defect analysis or physical-regime replication.

## 9. Publication go/no-go

### Provisional verdict

**GO, conditionally.**

Reason:

- the primary prospective D1-D6 study shows nontrivial incremental value beyond B1;
- at least four materially distinct contamination channels currently show B2 earlier detection;
- two additional structural-prevention probes support the authority model;
- no result required weakening B1;
- no family was reclassified as UNIQUE_DETECTION when B1 eventually detected the consequence.

### Conditions before standalone-paper claim is secured

1. close the preregistered physical-regime replication, at minimum for D2 and D5;
2. complete a final adversarial literature search for close prior work specifically on transition-authority/side-effect contamination during scientific-model modernization;
3. keep D1/D3 dependence and D2/D4/D5/D6 common authority mechanism explicit;
4. quantify B2 incremental qualification cost only after replication results are frozen;
5. demonstrate representative whole-model preservation separately; D1-D6 alone is not enough to show that SWAP4.3.1 -> SWAP5 preserved the declared scientific denominator.

## 10. Next permitted research action

Priority order:

1. preregister D2 replication regime;
2. preregister D5 replication regime;
3. run those replications without changing the original first-pass results;
4. re-run novelty adjudication against the final literature pass;
5. only then elevate RQ1b selective requalification/cost as a secondary analysis.

Do not repair or extend D1 merely to increase the number of positive cases.
