# PUB-ME D6 F-CI98 semantic-successor replay

Status: PREREGISTERED_SUCCESSOR_REPLAY_BEFORE_EXECUTION

Publication owner: PUB-ME

Capability: D6 — rejected-trial external side effect survives

## 1. Why replay is required

PUB-ME D6 was admitted on canonical merge d517088cdc1cd82904b37648d6556dc79d57a641 with classification EARLIER_DETECTION.

Canonical subsequently advanced through F-CI98 / F-GC31 to 7b864853ca22baa73141b2dec9ed2f3915ef520d.

That successor changes source files inside the D6 dependency surface, including:
- src/solver/mod_soil_water_accepted_step_direction_contract.f90
- src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
- src/transaction/mod_accepted_trajectory_directional_publication.f90

Therefore the admitted D6 scientific result may not be reused solely from historical success. A semantic replay is required.

## 2. Immutable D6 authorities

- D1-D6 design head: b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa
- design blob: 61f7133f19cc900971aa454b7bdb16a254468eda
- admitted D6 test blob: 76f3394cdb11367c609d5f6c8028be80b82f45e7
- admitted D6 result blob: 4bd7a3aa752fda37c29517c93d64d91d0da4ef95
- admitted O0/O2 output SHA-256: 9563ed157258f1993a826a9ef498498cafa45254266818d877db73bb28c88643

No D6 fault operator, observer, B1/B2 comparator, classification rule or output marker may change in this replay.

## 3. F-CI98 dependency authority

Current source blobs used by the successor replay:
- transaction reference: d5a71a526efaebd82054580c3186f8e3545db331
- accepted-step direction contract: b5a0276d2f1b2c8ffe581e68dffecdaf55a32768
- accepted-trajectory sensitivity: d267a763ceb697557e762c937a99b7f11cb44684
- accepted-trajectory publication: b1be9af9ece045cac1fd17087e6b08bc615bd733
- accepted-trajectory transaction binding: 3cd25cfecb75f0e6ba7cb537859d6d738097abe8

The three changed directional/publication blobs match the admitted F-CI98 authority.

## 4. Replay decision rule

The D6 result remains current only if all of the following hold on the exact successor postimage:
1. the original D6 test source is byte-identical;
2. no src/** or reference/** file is changed by this replay workunit;
3. the current F-CI98 dependency blobs match the pins above;
4. D6 passes under O0 and O2;
5. O0 and O2 output are identical;
6. the exact output SHA-256 remains the admitted D6 SHA;
7. classification remains exactly EARLIER_DETECTION;
8. clean accepted and rejected controls remain green.

If any criterion fails, the cross-defect PUB-ME synthesis must treat D6 as stale until separately adjudicated.

## 5. Scope

This workunit changes no production/reference source and does not create a new D6 experiment.

It is evidence continuity after a relevant semantic dependency change.
