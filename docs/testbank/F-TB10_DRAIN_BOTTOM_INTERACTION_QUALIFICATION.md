# F-TB10: drainage x changing bottom-boundary qualification

F-TB10 is the first execution workunit derived from the integrated interaction catalog established by F-TB09. It qualifies only `SWAP5-TB09-DRAIN-BOTTOM-003-v1` and does so without modifying production physics or the F-TB09 catalog.

## Scientific question

Can the current-canonical serialized Full Richards runtime conserve water while the already admitted restricted DIVDRA process remains active across a change in the lower hydraulic boundary and a simultaneous change in the explicit hydraulic view used to distribute drainage?

The question is intentionally narrower than groundwater coupling. No MODFLOW model or direct coupling interface participates in this test.

## Admitted composition reused

The case reuses the F-CI36 restricted DIVDRA runtime callsite. That owner scope is single-level, positive drainage with an explicit process hydraulic view and an externally supplied scalar transfer. F-TB10 does not alter or re-derive the drainage exchange law.

The soil-water solve remains the current-canonical reference Full Richards path. The lower boundary uses `SWBOTB=5`, which prescribes lower-boundary head and makes the corresponding `qbot` a solver output.

## Why `SWBOTB=5`

An initial fixture considered `SWBOTB=7`, inherited from the existing independent DIVDRA verifier. Source inspection showed that mode 7 is free drainage. Changing `bottom_head` or `bottom_flux` under that mode would therefore not prove interaction with a changing hydraulic boundary.

F-TB10 instead uses the prescribed-head mode 5. The final case changes the prescribed bottom head from -123 cm to -120 cm between two committed generic intervals. The qualification requires the signed bottom flux reconstructed from the authoritative mass ledger to change as a consequence.

## Scenario

The first interval uses an explicit drainage-view groundwater level of -0.35 m and the second -1.55 m. A positive single-level DIVDRA scalar transfer of 0.0002 cm/day remains active in both intervals. This deliberately crosses a drainage spatial-distribution water-table node while the lower Richards boundary is perturbed.

Root uptake, surface storage and runoff, snow, soil temperature, macropores and frost are disabled so the accounting seam is bounded and interpretable.

## Oracle and water balance

The primary oracle is F-TB09 O6 property/invariant `TB09-DRAIN-BOTTOM-SIGNED-LEDGER`. Each interval must produce a complete authoritative mass ledger with no missing contributions and residual magnitude no larger than `1e-12`.

For this restricted fixture the signed bottom flux can be reconstructed from the ledger as

`qbot = (total_in - total_out) / DeltaT + qtop + Q_divdra`

because root uptake, irrigation/source terms, surface storage and runoff are inactive. This reconstruction is used only as a diagnostic decomposition of the already authoritative mass ledger. It does not replace that ledger or create a second accounting authority.

The combined window must also satisfy

`S(t1) - S(t0) = sum(total_in_i) - sum(total_out_i)`

within the same arithmetic hard gate. The tolerance is not a water-loss budget.

## Preservation evidence

The dedicated runner replays the exact independent F-VQ51 restricted-DIVDRA verifier against the unchanged current production composition. F-TB10 additionally compiles and executes its own interaction case at `-O0` and `-O2` and requires exact textual output identity.

## Explicit nonclaims

F-TB10 does not qualify direct SWAP-MODFLOW coupling, the `H_SWAP = H_MF` interface condition, drainage exchange-law science outside the F-CI36 scope, fully implicit or trial-state drainage response, negative or multilevel drainage, surface-water-controlled drainage, parallel active-DIVDRA throughput, or every possible bottom-boundary mode.

The other F-TB09 catalog cases remain `CATALOGED_NOT_PHYSICS_QUALIFIED` unless and until their own owner workunits establish execution evidence.

## Closeout

The scientific decision is `QUALIFIED_TB09_003_RESTRICTED_DRAIN_BOTTOM_INTERACTION` only if the dedicated exact-head CI workflow passes on the live F-TB10 branch head. No production source or reference change is part of that decision.
