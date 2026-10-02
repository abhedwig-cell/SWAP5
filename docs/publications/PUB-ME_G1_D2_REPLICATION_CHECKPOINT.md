# PUB-ME G1 D2 physical-regime replication checkpoint

Status: **RECONCILED__READY_FOR_PROSPECTIVE_REPLICATION_SELECTION**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Workunit: `PUB-ME-G1-D2-REPLICATION`

Checkpoint date: 2026-09-18

## Authorities

Original canonical selection base:

`integration/f-ci-canonical@d517088cdc1cd82904b37648d6556dc79d57a641`

Reconciled execution base after F-CI98 dependency change:

`integration/f-ci-canonical@7b864853ca22baa73141b2dec9ed2f3915ef520d`

D1-D6 design authority:

- preregistration head `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- design blob `61f7133f19cc900971aa454b7bdb16a254468eda`

Cross-defect synthesis authority:

`work/pub-me-d1-d6-synthesis@28844e19a3ac1c2c9fa83ede2c3062a9bc3ecbe8`

Go/no-go verdict:

`PROVISIONAL_GO_NARROWED`

Mandatory gap:

`G1 — D2 physical-regime replication`

## Purpose

Test whether the D2 `EARLIER_DETECTION` timing distinction remains meaningful in at least one additional prospectively selected physical regime.

This is a replication, not a new defect family.

## Original D2 result that must not be tuned

Original D2:

- defect: rejected trial contaminates external accepted-accounting ledger;
- B2 detects nonzero accepted ledger at retry/re-execution entry;
- strong B1 detects final accepted-total mismatch after acceptance;
- accepted physical endpoint and canonical accepted transaction accounting remain unchanged;
- equal rejected inflow/outflow can leave net mass closure green;
- classification: `EARLIER_DETECTION`.

The original fixture, thresholds and result remain immutable.

## Replication selection rule

Select the second physical regime from **pre-existing Reference evidence generated independently of this replication result**.

The new regime must differ materially from the first D2 physical case in at least one hydrologically meaningful dimension, preferably:

- hydraulic material / constitutive nonlinearity;
- initial hydraulic state;
- forcing magnitude or direction;
- or another already qualified physical setting.

Selection may use existing historical/reference measurement tables only to establish a viable reject-then-accept pair.

Do not inspect a new D2 mutant result before the regime and all B1/B2 criteria are frozen.

## Required clean physical sequence

The selected regime must prospectively provide:

1. one real Reference trial that is rejected under a predeclared temporal criterion;
2. a shorter real re-execution from the unchanged accepted origin that is accepted;
3. nonzero prescribed/integrated transfer suitable for the same D2 accounting operator.

If no pre-existing regime satisfies these constraints without tuning, record `BLOCKED_NO_PREEXISTING_REPLICATION_FIXTURE`.

## Comparator

B1 and B2 are unchanged from D2.

B1:
- accepted endpoint/scientific output checks;
- accepted accounting totals;
- strong end-state/ledger regression.

B2:
- accepted accounting must remain empty/unchanged at retry entry after a rejected trial.

Permitted replication outcomes:

- `REPLICATED_EARLIER_DETECTION`
- `NO_INCREMENTAL_VALUE`
- `BLOCKED_NO_PREEXISTING_REPLICATION_FIXTURE`
- `BLOCKED_CLEAN_SEQUENCE`

Do not introduce a more favorable category after execution.

## Scope guards

No production/reference source changes.

No change to:
- D2 fault operator;
- B1/B2 detection definitions;
- existing transaction acceptance logic;
- scientific tolerances solely to make replication succeed.

## Next permitted action

Read only:
- original D2 checkpoint/result/test;
- pre-existing Reference measurement/evidence surfaces that existed before this G1 branch.

Freeze one replication regime and its exact acceptance/rejection criteria before execution.

## Timeout recovery

Resume from this branch and checkpoint.

Do not reconstruct D1, D3-D6, broad literature or P2 solver-admissibility work unless directly required to identify a pre-existing Reference fixture.


## Implementation checkpoint before execution

Current implementation head:

`a2570c3a61b3cac81a7ea48a168882c8f28a4ad6`

Persisted publication-only artifacts:

- `tests/publication/test_pub_me_g1_d2_reverse_flow_replication.f90`
- `tests/publication/pub_me_g1_d2_fortran_closure.py`
- `tests/publication/run_pub_me_g1_d2_reverse_flow_replication.sh`

Frozen implementation differences from admitted D2:

- q changed from `+1e-6` to preregistered `-1e-6 cm/day`;
- historical Binf values changed only to the pre-existing negative-q F-SI38 rows;
- column id changed to an independent publication fixture id;
- qualification-only rejected transfer uses `abs(q)*dt` so accepted accounting remains positive-magnitude inflow/outflow under reversed physical direction;
- output markers identify G1 replication.

No G1 scientific execution has been observed at this checkpoint.

Next permitted action:

add one dedicated workflow, open draft PR, and run the exact G1 gate before broad interpretation.
