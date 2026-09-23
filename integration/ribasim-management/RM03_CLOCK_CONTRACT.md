# RM03 management clock and scheduling contract

The coupler owns the scheduling relation between SWAP, MODFLOW and Ribasim. It may not rely on a model call accidentally crossing a management boundary.

## Authoritative rule

Let `t` be the current accepted coupled time and `t_alloc_next` the next Ribasim allocation boundary relevant to the connected UserDemand. The next physical advance target is no later than:

`min(t_requested, t_alloc_next, next_SWAp_application_event, next_other_required_transaction_boundary)`.

If `t_alloc_next` lies strictly inside an otherwise valid model advance, the coupler splits the advance before calling the models. The allocation solve/application is executed as an explicit transaction stage at `t_alloc_next`.

This rule is required by RIBASIM-DUMMY-20H10. In the tested fixed-dt RibaMod route an allocation boundary crossed inside one BMI `update_until` can be skipped because allocation execution is keyed to qualifying BMI call-start times.

## Boundary order

At an allocation boundary:

1. all states accepted strictly before the boundary are the committed origin;
2. SWAP derives the management demand from that accepted origin and accepted process/crop memory;
3. current forecast inputs that are defined as boundary-visible are materialized with explicit sign and provenance;
4. Ribasim performs the management solve;
5. the allocation result is frozen for physical realization over its intended management window;
6. coupled physical advance begins;
7. physical transfer receipts remain provisional until outer acceptance;
8. accepted physical changes become memory for the next boundary.

A physical exchange that occurs after the allocation solve does not retroactively alter that solve unless a future explicitly qualified iteration contract says otherwise.

## Aligned first fixture

The first real qualification uses an allocation boundary equal to the coupler boundary. No hidden subcycling is needed to discover the management instant.

## Noncommensurate qualification

Exactly one controlled noncommensurate case is required. It must contain at least one allocation boundary that would be crossed by a naive larger BMI `update_until`. The correct scheduler must split at that boundary and produce the same accepted management trajectory as an explicitly boundary-aligned reference execution.

The purpose is to prove absence of H10 aliasing, not to characterize all clock lattices.

## Restart

Restart metadata must preserve enough scheduling state to identify the next management boundary unambiguously. A restart at an accepted boundary may not repeat the previous allocation solve or skip the next one.

## Nonclaims

No universal timestep recommendation, Ribasim saveat prescription, or generic sub-hour management cadence is established here.
