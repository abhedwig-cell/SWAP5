# PPA-WU05-MIGMAC11 pond-derived macropore donor

Date: 2026-10-07. Status: CLOSED.

## Source contract

Pinned B1.11 authority is
`reference/swap-4.3.1/b1_11_frost_source/SWAP/boundtop.f90`.

The admitted ordering is source-faithful:

1. direct rain, irrigation and melt are area-partitioned only when a direct macropore atmospheric source is actually active;
2. runon remains in the shared surface balance and is not booked as a separate direct macropore source;
3. the residual-synchronous candidate macropore surface area remains available independently of that direct-source option;
4. the no-macropore candidate ponding `h0max` is evaluated first;
5. above `PndmxMp`, B1.11 derives the lateral macropore receipt from `KsMpSs`, `p1`, `p2Mp`, `dt` and the active direct-macro contribution;
6. the pond-derived amount is debited from the same surface donor;
7. A9 capacity rejection is returned to that same surface donor.

`KsMpSs` remains a dedicated macropore-surface parameter. It is not substituted by covering-layer conductivity.

## SWAP5 composition

MIGMAC11 keeps candidate geometry and atmospheric source ownership separate. The dynamic-top provider receives a candidate area for pond-donor evaluation, while `matrix_source_area_partition` is enabled only from actual configured direct macropore top forcing.

The pond receipt is handed to the inner macropore provider on the same Richards residual. Pure surface-to-macropore receipts are valid without simultaneous matrix exchange. The macropore runtime records pond-specific requested, accepted and returned amounts separately from external direct top input, so only external accepted water enters the external mass ledger. Capacity-rejected top water is restored to candidate ponding.

## Qualification

Focused qualification first passed on workstream head
`37e36cfb64df55232037231fbf7ce40365279eee`, run `37603291412`.

Current canonical `integration/f-ci-canonical@19d7ce86f71c7fa5fd3ed2c65a91dc705921f714`
was then merged through PR #1089. The qualified merge postimage is
`609cd5ee8964f0619d94bd396f53ed9fe8d8495e`.

Run `37612249809` passed all workflow stages:

- production runtime compile at O0 and O2;
- active pond receipt above threshold;
- paired runon case, with a larger pond-derived request and no direct runon macropore booking;
- below-threshold/no-pond zero receipt;
- partial A9 capacity acceptance with positive returned surface water;
- expanding and shrinking candidate-area cases;
- exact pond receipt identity `requested = accepted + returned`;
- exact net surface debit identity `requested - returned = accepted`;
- whole-column mass closure within the existing tolerance;
- reject/smaller-retry, rollback/replay and restart equivalence;
- MIGMAC01-09 source/runtime preservation;
- MIGMAC10 bounded Boesten/Rutter/macropore preservation;
- O0/O2 output identity.

Representative persisted values from the postimage qualification include active-pond mass residuals on the order of 1e-16 cm and a partial-return case with a positive accepted share and positive return, while remaining within the hard mass tolerance.

## Closure

MIGMAC11 is closed for the bounded B1.11 surface/macropore donor chain above. This closure does not broaden unrelated macropore, surface-water or source options. A future canonical change that intersects the recorded dependency surface requires targeted preservation or requalification; otherwise this capability remains closed.
