# PUB-ME D6 execution checkpoint

Status: **RECONCILED__READY_FOR_D6_DESIGN**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Checkpoint date: 2026-09-18

## 1. Live authority

Canonical branch:

`integration/f-ci-canonical`

Canonical head at reconciliation:

`d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0`

Canonical merge message identifies admitted D5:

`admit(PUB-ME D5): workspace-authority earlier detection`

D6 work branch:

`work/pub-me-d6-rejected-side-effect`

Branch start:

`d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0`

## 2. Reconciled publication state

Canonical contains persisted execution/result records for:

- D1 rejected-candidate state contamination;
- D2 retry/double-accounting;
- D3 wrong-origin candidate acceptance;
- D4 speculative restart;
- D5 numerical-workspace authority.

Observed canonical publication files include:

- `PUB-ME_D1_RESULT.json`;
- `PUB-ME_D2_RESULT.json`;
- `PUB-ME_D3_RESULT.md`;
- `PUB-ME_D4_RESULT.md`;
- `PUB-ME_D5_RESULT.md`;
- corresponding execution checkpoints.

D6 result/evidence is not yet present in canonical.

## 3. Current capability

Capability:

`PUB-ME-D6 — rejected-trial external side effect survives`

Preregistered defect semantics:

A side effect produced during non-authoritative/rejected candidate execution becomes externally visible or persistent as if it belonged to accepted scientific history.

Examples permitted by the preregistration include:

- external publication/observer output;
- diagnostic/event publication;
- exchange/accounting publication when not already owned by D2;
- any externally visible state whose authority should be accepted-only.

## 4. Scientific comparison

Primary comparator remains the preregistered:

`B1 strong conventional scientific-software qualification`

versus:

`B2 = B1 + explicit transition-authority oracles`

D6 must not be designed so that B1 is artificially weak.

Required interpretation categories remain:

- `NO_INCREMENTAL_VALUE`;
- `EARLIER_DETECTION`;
- `UNIQUE_DETECTION`;
- `STRUCTURAL_PREVENTION`.

## 5. Current verdict

`READY_FOR_BOUNDED_D6_RECONCILE_AND_DESIGN`

No D6 experiment has been run in this branch at this checkpoint.

No production/reference source has been changed.

No fault-injection implementation has been added.

## 6. Next permitted action

1. Read the exact canonical D1-D5 result summaries only as needed to preserve comparator consistency.
2. Identify one real accepted-only external publication/observer seam already present in canonical.
3. Design a qualification-only D6 mutant and matched clean control that exercise that seam after real candidate work.
4. Persist the D6 design/checkpoint **before execution**.
5. Only then implement/run one bounded D6 experiment.

## 7. Exclusions

Do not:

- alter production physics;
- change transaction semantics to force a positive result;
- weaken B1;
- reuse D2 double-accounting as D6 under a different name;
- count compile failure as defect detection;
- merge any fault-injection mutant into production;
- broaden into evidence-selection RQ1b before D6 is classified;
- repeat D1-D5 experiments unless exact comparator evidence is missing.

## 8. Timeout recovery rule

On interruption, resume from this branch/head and recheck only:

- current canonical head;
- D6 branch head;
- relevant delta since this checkpoint;
- the selected external-publication seam.

Do not reconstruct the broader PUB-ME literature or D1-D5 history.
