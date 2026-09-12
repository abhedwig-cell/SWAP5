# F-TB10 runlog

## Purpose

F-TB10 executes the bounded interaction catalogued as `SWAP5-TB09-DRAIN-BOTTOM-003-v1` without changing production source. The workunit is restricted to the already admitted serialized positive single-level DIVDRA runtime combined with a current-canonical Full Richards column and a changing lower hydraulic boundary.

## Frozen authorities

- current-canonical composition base: `eba90d79010b095b6556e93bd8b77a8c28d25560`
- F-TB09 catalog authority: `fe3545c4537b11cefd0186aa401048d4f4b10eb9`
- restricted DIVDRA canonical owner authority: F-CI36 as present on the frozen base
- independent restricted DIVDRA verifier: F-VQ51 `716d0952c2a9580b213cd22d8c3c1dc824f53dff`

## Pre-implementation runtime audit

The first candidate fixture inherited `bottom_mode=7` from the F-VQ51 drainage verifier. Live source inspection then showed that `SWBOTB=7` is the free-drainage route. Consequently, changing `bottom_flux` or `bottom_head` under that mode would not constitute a qualified changing-boundary interaction.

That fixture was rejected before qualification materialization. The final F-TB10 fixture instead uses `SWBOTB=5`, the current-canonical prescribed-head route for which the reference Richards binding explicitly materializes the resulting `qbot` as an output after a successful solve.

This correction is scientifically material: F-TB10 must demonstrate an active hydraulic lower-boundary perturbation, not merely changed input metadata.

## Final bounded scenario

Two consecutive generic intervals are executed through `fmr_run_serialized_physical_multiswap_with_divdra`.

Interval 1:

- prescribed bottom head: -123 cm
- explicit drainage hydraulic-view groundwater level: -0.35 m
- positive single-level DIVDRA scalar transfer: 0.0002 cm/day

Interval 2:

- prescribed bottom head: -120 cm
- explicit drainage hydraulic-view groundwater level: -1.55 m
- the same positive single-level DIVDRA scalar transfer

Root uptake, surface storage/runoff, snow, soil temperature, macropores and frost are inactive.

## Required qualification observations

The dedicated runner must demonstrate:

1. active drainage publication in both intervals;
2. change of the prescribed bottom head;
3. change of the derived signed bottom flux after that perturbation;
4. change of the drainage water-table node under the explicit hydraulic-view change;
5. complete mass ledgers with no missing contribution mask in both intervals;
6. hard mass closure at `1e-12` or better in each interval;
7. hard mass closure at `1e-12` or better across the combined full window;
8. committed storage continuity at the interval boundary;
9. exact O0/O2 output identity;
10. successful replay of the exact F-VQ51 restricted-DIVDRA verifier against the same unchanged production composition.

## Scope controls

No `src/**` or `reference/**` change is permitted. F-TB09 remains closed and unchanged. RB1 is not reopened. This workunit is not direct groundwater-coupling evidence and does not qualify drainage exchange-law science, fully implicit drainage response, negative or multilevel drainage, surface-water-controlled drainage, or parallel active-DIVDRA throughput.

## Closeout rule

The workunit reaches `QUALIFIED_TB09_003_RESTRICTED_DRAIN_BOTTOM_INTERACTION` only when the dedicated GitHub Actions run is green on the exact live branch head, with live branch-ref checks both before and after execution. Until then the qualification status remains conditional.
