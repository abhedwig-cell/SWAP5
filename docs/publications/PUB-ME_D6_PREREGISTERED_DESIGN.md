# PUB-ME D6 preregistered design

Status: **PREREGISTERED_BEFORE_D6_EXECUTION**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Design branch: `work/pub-me-d6-rejected-side-effect`

Design base: `integration/f-ci-canonical@d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0`

## 1. Defect family

D6 — **rejected/non-authoritative trial external side effect survives**

The experiment tests whether a process result computed while a candidate is still non-authoritative can escape to an externally visible observer/event sink before the candidate becomes accepted scientific history.

This experiment does not test novelty of rollback, events, observers or commit receipts.

## 2. Selected canonical seam

Primary production seam:

`src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90`

Supporting candidate-bound materializer:

`src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90`

Why this seam was selected:

- candidate-bound surface evaporation can be materialized while the candidate and its origin are present;
- the candidate-bound carrier is opaque but publicly inspectable;
- the production accepted-publication seam deliberately keeps its prepared precommit carrier private;
- the same candidate is then committed;
- public surface-attribution publication is finalized only after a ready accepted commit receipt;
- rejected/non-authoritative candidate work therefore has no production path to public accepted attribution.

The D6 experiment attacks the timing boundary outside that protected production seam with a qualification-only external observer.

## 3. Candidate sequence

Use two candidates from the same authoritative origin.

### Candidate A

1. materialize candidate A from accepted origin `S_n`;
2. materialize a valid candidate-bound surface-evaporation result for A while A is still admissible;
3. do not yet commit A.

### Candidate B

4. materialize candidate B from the same accepted origin;
5. commit B successfully, advancing the authoritative committed revision;
6. candidate A is now stale/non-authoritative.

### Final A commit attempt

7. attempt to commit candidate A;
8. require rejection as stale/non-authoritative;
9. authoritative physical state remains candidate B's accepted endpoint.

This reuses an admitted origin-authority rejection mechanism but D6's measured fault is the external side effect, not wrong-origin acceptance.

## 4. Clean control

In the clean route:

- candidate A may produce a candidate-bound surface result;
- no external accepted-publication observer is called for A before acceptance;
- candidate B commits;
- A is rejected as stale;
- the external accepted-event sink contains no event attributable to A;
- if B has an accepted surface publication, exactly that accepted event may be published.

Clean control must demonstrate no stale A event and no observer carry-over.

## 5. Qualification-only mutant

The D6 mutant inserts one test-only external observer call immediately after candidate A's candidate-bound surface result becomes ready and **before any accepted commit receipt exists**.

The observer records at least:

- candidate lineage;
- origin revision;
- origin interval;
- surface route;
- bare-soil evaporation rate;
- ponded-water evaporation rate;
- event sequence number.

The mutant then follows the same sequence in section 3, making A stale and rejecting A's commit.

No production module is modified.

No production callback/observer API is added.

The observer exists only in the publication qualification harness.

## 6. B1 comparator

B1 remains the strong conventional scientific-software baseline.

For D6 it includes, where applicable:

- committed-state and accepted-endpoint regression;
- commit/rejection status checks;
- conservation/accounting invariants;
- accepted public surface-publication output checks;
- end-of-run external event-stream regression: rejected/non-authoritative candidate A must not appear in the accepted external publication stream.

B1 is allowed to detect the injected event after the bounded execution by observing an unexpected event count, provenance, route or value.

D6 must not suppress this check to manufacture a B2 advantage.

## 7. B2 transition-authority oracle

B2 adds an accepted-only side-effect authority rule:

> An external event labelled as accepted scientific publication may be emitted only when the exact candidate has a valid accepted commit receipt for the same lineage, origin revision and interval.

Before the qualification-only observer write for candidate A, no such receipt exists.

Expected B2 result:

`DETECTED_BEFORE_EXTERNAL_SIDE_EFFECT`

The experiment may then deliberately bypass the B2 guard in the mutant harness to measure the downstream B1 consequence. This bypass is qualification-only and must not alter production code.

## 8. Primary classification rules

### STRUCTURAL_PREVENTION

Use only if the selected public production interfaces make the D6 side effect unconstructable even in the qualification harness without private/internal bypass.

### UNIQUE_DETECTION

Use only if B2 detects the authority violation and the frozen strong B1 comparator does not detect the persisted external event.

### EARLIER_DETECTION

Use when B2 detects before observer mutation/publication and B1 detects the contaminated event stream only after the bounded execution.

### NO_INCREMENTAL_VALUE

Use when B1 detects the same fault at the same meaningful boundary or the B2 oracle adds no observable protection.

No other positive label is permitted.

## 9. Scientific consequence to measure

The intended bounded consequence is:

- accepted physical endpoint can remain identical to the clean control;
- accepted canonical mass/accounting can remain identical;
- accepted public surface-publication object can remain valid for the actually accepted candidate;
- nevertheless the external event stream contains an event from candidate A, which never became accepted scientific history.

This makes D6 distinct from:

- D2 accepted accounting contamination;
- D4 speculative restart;
- D5 solver-workspace physical-state contamination.

## 10. Primary outputs

Record for clean and mutant:

- final committed revision/time/state digest;
- commit statuses for B and A;
- accepted public surface-publication readiness/provenance;
- external observer event count;
- each event's lineage/revision/interval;
- event route and evaporation rates;
- whether any event belongs to rejected/stale A;
- B1 first detection point;
- B2 first detection point;
- O0/O2 semantic identity.

## 11. Stop / block conditions

Stop without changing the design if:

- a valid candidate-bound surface result cannot be materialized prospectively before candidate acceptance;
- candidate A cannot be made non-authoritative using only public admitted transaction interfaces;
- the clean accepted-publication fixture is not stable under O0/O2;
- a D6 event cannot be distinguished from D2 accounting semantics;
- implementation would require modifying production or reference code.

A blocked result remains publication evidence.

## 12. Interpretation boundary

A positive D6 result will not establish:

- an existing SWAP5 production defect;
- novelty of accepted-only callbacks/publication;
- novelty of rollback or commit receipts;
- that B1 scientific testing is weak;
- hydrologic generality;
- publication readiness by itself.

It will establish only the incremental timing/authority result for this preregistered external side-effect channel.

## 13. Next permitted action

Implement one qualification-only D6 harness and dedicated runner/workflow on this branch, using the exact canonical production/reference sources unchanged.

Persist the first executable checkpoint before waiting on broad CI.
