# F-TB10: drainage x changing bottom-boundary qualification

F-TB10 is an execution workunit derived from the integrated interaction catalog established by F-TB09. Its target is `SWAP5-TB09-DRAIN-BOTTOM-003-v1`.

F-TB10 does **not** qualify that scientific case. It closes fail-closed as:

`BLOCKED_OWNER_TEMPORAL_ACCEPTANCE_POLICY_REQUIRED`

with decision:

`NOT_QUALIFIED_TB09_003_NONSTATIONARY_TEMPORAL_POLICY_GAP`

No production source, reference corpus or F-TB09 catalog content is changed by this workunit.

## Scientific question

Can the current-canonical serialized Full Richards runtime conserve water while the already admitted restricted DIVDRA process remains active across a change in the lower hydraulic boundary and a simultaneous change in the explicit hydraulic view used to distribute drainage?

The intended experiment is deliberately narrower than groundwater coupling. No MODFLOW model or direct SWAP-MODFLOW interface participates.

## Admitted composition reused

The case reuses the F-CI36 restricted DIVDRA callsite: positive single-level drainage with an explicit process hydraulic view and an externally supplied scalar transfer. F-TB10 does not alter or re-derive the drainage exchange law.

F-CI36 remains a frozen admitted authority on postimage `8fa79a70a9faccaf8b63826df607a685eb75b046`, with F-VQ51 as independent verifier provenance. The current-canonical DIVDRA composition, runtime, process and binding blobs used by F-TB10 match that admitted authority.

The soil-water path is the current-canonical reference Full Richards implementation.

## Fixture corrections before the scientific attempt

Two test-fixture errors were found and removed before interpreting the scientific result.

First, the original fixture inherited `SWBOTB=7`. That is free drainage, so changing a bottom-head input would not prove a changing hydraulic lower boundary. The final fixture uses `SWBOTB=5`, the prescribed-head route for which bottom head is physically active and `qbot` is solver output.

Second, the original fixture preallocated the DIVDRA forcing target. The admitted DIVDRA wrapper intentionally owns that transient materialization and rejects an already bound target. The fixture was corrected so the wrapper materializes and cleans the drainage forcing itself.

A separate provenance mistake was also corrected: the historical F-VQ51 test program is not treated as a moving-current integration test. Its frozen authority is pinned instead.

## Attempted scenario

The planned interaction consists of two generic consecutive intervals.

Interval 1 uses:

- prescribed bottom head -123 cm;
- explicit drainage-view groundwater level -0.35 m;
- positive single-level DIVDRA scalar transfer 0.0002 cm/day.

Interval 2 would use:

- prescribed bottom head -120 cm;
- explicit drainage-view groundwater level -1.55 m;
- the same positive DIVDRA scalar transfer.

Root uptake, surface storage/runoff, snow, soil temperature, macropores and frost are inactive so the interaction and mass ledger remain bounded.

## Physical execution result

GitHub Actions run `34680289804` executed the corrected current-canonical composition on exact head `3a3017de9b71430deb053a141b7d9ce762346ebd`.

Before failure it established the intended production/reference immutability, F-TB09 authority, F-CI36/F-VQ51 provenance, unchanged admitted DIVDRA blobs, active `SWBOTB=5` route and successful entry into the real DIVDRA runtime composition.

The first nonstationary interval was not committed. The executable stopped at:

`FTB10_TEST_FAIL first interval committed`

That is negative evidence. It does not establish that production physics is wrong, and it does not by itself establish which internal rejection category was decisive.

## Why F-TB10 must stop instead of tuning the run

The F-TB10 template does not activate temporal-history continuation state. Its numerical route is therefore the standard external full-versus-two-half transaction estimator. The fixture uses `temporal_tolerance = 0`, which demands exact temporal identity.

For a genuine nonstationary workload, F-TB10 is not allowed to make that criterion easier merely to obtain a green run.

### Existing external full-half policy

F-VQ28 explicitly failed closed for a generic production numeric profile. It selected neither a production temporal metric nor a production temporal tolerance and did not admit a universal absolute tolerance. Its handoff requires a separate owner/runtime-policy workunit rather than local tuning.

F-VQ19 does not fill this gap: its zero-tolerance result is restricted to an exact-identity fixture and is not a universal nonstationary Richards policy.

### Normalized Richards certificate

F-VQ34, preserved by F-CI21, qualifies the mechanism

`C_h = B_inf / H_budget`.

That route requires explicit, finite, positive application/runtime accuracy-budget provenance. It deliberately has no universal/default numeric `H_budget`, and hard mass rejection always has precedence.

F-CI44 and F-CI46 provide the typed application-accuracy contract and external adapter, but both only carry already qualified `H_app` and `A_temporal`. They explicitly select no numeric application policy.

### Why F-GC22 does not solve this

F-GC22 subsequently qualified a branch capability named `Application and Temporal Accuracy Binding for Direct Groundwater Coupling`.

It is not a TB10 authority because:

- its scope is the groundwater-head QoI for restricted direct groundwater coupling;
- it is not canonically admitted at this assessment;
- it is not production-coupling admitted;
- it chooses no universal or project numeric `H_app`, temporal allocation or interface allocation;
- its binding module consumes already externally qualified application accuracy rather than creating it.

Using F-GC22 as a standalone integrated-column numeric policy would therefore cross its qualified scope and still would not supply the missing numeric application requirement.

## Water balance remains a hard gate

The intended F-TB09 oracle remains `TB09-DRAIN-BOTTOM-SIGNED-LEDGER`. A future accepted execution must still prove complete interval ledgers, hard mass closure and full-window closure. The `1e-12` arithmetic closure gate is not a water-loss budget.

The blocker does not weaken this requirement. No temporal certificate, tolerance, fallback or performance policy may override missing water.

## Required owner work

`integration/f-tb/F-TB10_OWNER_HANDOFF.json` defines the separate owner task. Before TB09-003 can return to F-TB10 execution, that work must qualify an application-appropriate temporal acceptance policy/provenance for genuine nonstationary standalone/integrated reference-Richards intervals.

Acceptable design directions may reuse the existing full-half or normalized certificate infrastructure, but must explicitly govern the metric/budget, provenance, scope, retry behavior and diagnostics. Hidden defaults are forbidden.

The owner must also maintain separation between physical options and numerical policy, preserve reference mode, keep hard mass precedence, and audit all 30 SWAP architecture invariants.

## Explicit nonclaims

F-TB10 does not qualify:

- TB09-003 itself;
- direct SWAP-MODFLOW coupling;
- `H_SWAP = H_MF` convergence;
- drainage exchange-law science beyond F-CI36;
- a generic temporal tolerance;
- an application `H_budget`;
- fully implicit or trial-state drainage response;
- negative or multilevel drainage;
- surface-water-controlled drainage;
- parallel active-DIVDRA throughput;
- any other F-TB09 catalog case.

The observed noncommit is also not promoted to a production-defect finding.

## Closeout

The F-TB10 branch closes only as a **blocked assessment**, after exact-head CI validates the blocker evidence, owner handoff, unchanged production/reference scope, architecture audit and hard nonclaims.

Scientific qualification of `SWAP5-TB09-DRAIN-BOTTOM-003-v1` remains open for a future execution after the temporal-policy owner gap has been qualified and, where required, canonically admitted.
