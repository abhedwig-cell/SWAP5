# PUB-ME G1 D2 reverse-flow replication result

Status: **QUALIFIED_REPLICATION_PENDING_POSTIMAGE_ADMISSION**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Workunit: `PUB-ME-G1-D2-REPLICATION`

## Design authority

- original D1-D6 preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- original D2 classification: `EARLIER_DETECTION`
- cross-defect synthesis: `work/pub-me-d1-d6-synthesis@28844e19a3ac1c2c9fa83ede2c3062a9bc3ecbe8`
- G1 checkpoint: `docs/publications/PUB-ME_G1_D2_REPLICATION_CHECKPOINT.md`
- G1 preregistration: `docs/publications/PUB-ME_G1_D2_REPLICATION_PREREGISTRATION.md`
- current execution base after F-CI98 reconciliation: `integration/f-ci-canonical@7b864853ca22baa73141b2dec9ed2f3915ef520d`

The reversed-flow fixture, temporal budget, historical oracles, D2 fault operator and B1/B2 definitions were frozen before execution.

## Replication regime

Original D2 prescribed throughflow:

`q = +1.0e-6 cm/day`

G1 replication:

`q = -1.0e-6 cm/day`

This reverses physical throughflow direction while retaining:

- identical magnitude;
- same hydrostatic initial state;
- same grid and constitutive parameters;
- same prescribed-qbot mode;
- same top explicit-flux mode;
- same Reference Richards route;
- same long/short durations;
- same temporal budget;
- same hard mass criterion.

## Pre-existing F-SI38 prediction

Historical evidence generated before G1:

- run `34815146569`
- job `103884165405`

Frozen negative-q rows:

- long `dt=0.01 day`: `Binf=3.70914011132183706e-6 cm`
- short `dt=0.0001 day`: `Binf=1.23637633357863245e-7 cm`

Frozen decision budget:

`1.0e-6 cm`

Therefore the preregistered expected sequence was:

- long trial rejected;
- short re-execution accepted.

## F-CI98 reconciliation

Canonical advanced before G1 execution and changed direct build dependencies, including the serialized Reference backend and accepted-step directional surfaces.

G1 was not executed on the stale branch.

The frozen replication design was carried unchanged onto:

`7b864853ca22baa73141b2dec9ed2f3915ef520d`

F-CI98 adds restricted active-drainage/groundwater tangent behavior but does not change Groundwater Coupling v1 transaction/commit semantics. The G1 physical fixture has no drainage/root/macropore optional physics.

The D2 qualification build continues to replace the non-requested real accepted-step directional service with the pre-existing fail-closed D2 test stub.

## Qualified primary replication

Executable head before this result record:

`8b1ce5a0a93888f163527fc822bbe87d8db048e8`

Evidence:

- PR: `#219`
- workflow: `PUB-ME G1 D2 reverse-flow replication`
- run: `35290239264`
- job: `105431291680`
- conclusion: **SUCCESS**
- O0: PASS
- O2: PASS
- O0/O2 semantic identity: PASS
- output SHA-256: `ad1a484e446e5bf90f9c66e2ba8c062e4bafa3eedb10a3444bbc4248ca610aa2`

Documentation on the executable head:

- run `35290239237`
- conclusion: **SUCCESS**

Full canonical qualification was still running when this result record was frozen.

## Observed clean physical sequence

Observed temporal certificate:

- rejected long trial: `3.70914011132183706e-6 cm`
- accepted short trial: `1.23637633357863245e-7 cm`

These reproduce the pre-existing negative-q F-SI38 values exactly at the printed precision.

Markers:

- `PUB_ME_G1_D2_REJECTED_BINF_CM=3.70914011132183706E-006`
- `PUB_ME_G1_D2_ACCEPTED_BINF_CM=1.23637633357863245E-007`

The executable therefore reproduced the preregistered reject→accept sequence without changing duration, budget or flux after observation.

## Replicated D2 accounting fault

The qualification-only rejected-throughflow contribution was prospectively defined for reversed flow as:

- accepted-ledger inflow increment = `abs(q)*0.01 = 1.0e-8 cm`
- accepted-ledger outflow increment = `abs(q)*0.01 = 1.0e-8 cm`

Observed at retry entry:

`1.00000000000000002e-8 cm`

The valid accepted short transfer was:

- canonical accepted total in = `1.00000000000000004e-10 cm`
- canonical accepted total out = `1.00000000000000004e-10 cm`

The faulty final ledger inflow became:

`1.00999999999999995e-8 cm`

The inherited D2 assertions also require:

- clean and mutant exactly one accepted commit;
- clean and mutant committed time identical;
- canonical accepted accounting identical clean versus mutant;
- accepted physical endpoint bit-identical clean versus mutant;
- clean external ledger equals canonical accepted totals;
- faulty net mass closure may remain green because equal erroneous inflow/outflow are added.

## B2 result

B2 detects the rejected contribution at retry/re-execution entry, before the accepted short physical re-execution.

Marker:

`PUB_ME_G1_D2_B2_RETRY_ENTRY_AUTHORITY=DETECTED`

## Strong B1 result

Strong B1 detects the final accepted-ledger mismatch only after the valid accepted retry.

Marker:

`PUB_ME_G1_D2_B1_FINAL_ACCEPTED_TOTAL_REGRESSION=DETECTED`

B1 therefore still detects the defect; this is not unique detection.

## Primary replication classification

**`REPLICATED_EARLIER_DETECTION`**

Marker:

`PUB_ME_G1_D2_CLASSIFICATION=REPLICATED_EARLIER_DETECTION`

The original D2 timing distinction therefore reproduces when the prescribed throughflow direction is reversed.

## Scientific interpretation

Supported:

- D2's authority-timing result is not limited to the original positive throughflow direction;
- under both equal-magnitude throughflow directions, a rejected physical transfer can contaminate an external accepted ledger while the eventual accepted physical endpoint and canonical accepted transaction accounting remain unchanged;
- B2 localizes the contamination at retry entry, while strong B1 detects the final accepted-total mismatch after acceptance;
- equal rejected inflow/outflow can remain invisible to net mass closure.

Not supported:

- material/soil generality;
- arbitrary flux-magnitude generality;
- arbitrary initial-state generality;
- existing production defect prevalence;
- unique detection;
- a population-level performance estimate for B2.

This is one directional physical-regime replication, not a broad hydrologic sensitivity study.

## G1 gap decision

**G1 = CLOSED_FOR_DIRECTIONAL_REPLICATION**

The explicit D2 physical-regime replication obligation from the cross-defect synthesis is satisfied at the preregistered forcing-direction level.

The final manuscript must describe the bound honestly: the replication changes flow direction, not material or initial hydraulic state.

## Next permitted action

1. replay the dedicated G1 gate, Documentation and full canonical qualification on the result-bearing postimage;
2. reconcile live canonical delta;
3. if green and dependency-stable, admit/close G1;
4. update the PUB-ME go/no-go document from G1-open to G1-closed;
5. continue G2 preservation-denominator extraction;
6. do not broaden G1 into a multi-material campaign unless G2/literature review demonstrates that such expansion is necessary.
