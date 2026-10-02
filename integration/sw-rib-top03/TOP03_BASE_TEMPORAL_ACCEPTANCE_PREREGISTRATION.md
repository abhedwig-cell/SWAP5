# TOP03 BASE temporal acceptance probe preregistration

Date: 2026-10-02
Status: PREREGISTERED_RESEARCH_ONLY
Branch: `work/sw-rib-top03-transactional-top-exchange`
Starting head: `7144b5fe3982cd064a5fcdb8c2ff776a9d5ae84c`
Canonical inspected: `641a8ba7fad5b67f0ebff7c78dd065270ed46329`

## Question

The real FAPP09 external-inundation fixture converges and closes its mass gates, but the shared BASE full/half temporal gate returns `huge()` whenever the transient end states are not exactly identical. This probe asks whether the unchanged physical fixture supplies a complete and contracting full/half refinement sequence from which a bounded temporal acceptance contract can be justified.

This is not a production acceptance change. No solver law, boundary condition, transaction policy, receipt rule or committed-state layout is changed by this work.

## Fixed physical profile

The probe must preserve the physical profile used by `verify_external_top_observation` in `tests/fapp/test_fapp09_ribasim_external_surface_water_profile.f90`:

- the same `MOD_grid` geometry and B1.10 MVG parameterization;
- uniform initial pressure head -123 cm;
- initial ponding 0 cm and groundwater level -2.25 cm;
- bottom mode 7 with the same initial conductivity-derived bottom flux;
- no root extraction, drainage response, macropore, snow, hysteresis, elasticity, frost, thermal, or evaporation process;
- imposed external surface-water head 0.02 cm and sill 0.01 cm;
- zero precipitation, irrigation, runon, evaporation and runoff supply terms;
- Reference Richards with max 80 nonlinear iterations and 16 backtracking attempts;
- no positive accepted qtop.

Changing the lower boundary, initial state or external-head forcing invalidates this probe for TOP03.

## Refinement design

For requested windows 0.25, 0.125, 0.0625 and 0.03125 day, independently restart from the same accepted origin and integrate the identical interval with 1, 2, 4 and 8 equal substeps. Each path is independent. A failed path is recorded as incomplete and is never used as an accuracy reference.

The 0.25, 0.125 and 0.0625 day windows include the exact attempt widths reached by the currently configured BASE retry ladder.

## Recorded observables

For every complete path record:

- integrated signed top transfer after the post-solve surface materializer;
- integrated bottom transfer;
- storage change;
- whole-path control-volume ledger residual;
- maximum absolute accepted soil mass residual.

For every adjacent complete refinement pair record:

- pressure-head infinity difference;
- water-storage L1 difference, `sum(abs(theta_a-theta_b)*dz)`;
- maximum single-cell water-storage difference, `max(abs((theta_a-theta_b)*dz))`;
- ponding-depth difference;
- groundwater-level difference;
- integrated top-transfer difference;
- integrated bottom-transfer difference.

The top-transfer observable remains post-solve. It must not be evaluated or published from Newton/provider evaluations.

## Hard validity gates

A path is usable only when all its substeps converge, every accepted soil mass residual is <= 1e-10 cm, every surface materializer closure residual is <= 1e-12 cm, qtop remains within the admitted inundation sign, and the whole-path control-volume ledger residual is <= 1e-10 cm.

O0 and O2 outputs must be numerically identical. Any optimizer-dependent numerical record falsifies the probe as qualification evidence.

## Decision rule

No tolerance is selected in advance.

A production temporal route may be proposed only for a window whose refinement sequence supplies at least two successive complete adjacent pairs and whose state, top-transfer and relevant bottom-transfer discrepancies contract under refinement without a sign or ownership change. The proposed production criterion must include separate state and throughput budgets. A small state discrepancy cannot mask a materially different integrated top or bottom transfer.

If the exact FAPP09 profile does not supply such a complete contracting sequence within this bounded probe, TOP03 remains blocked at temporal acceptance. The physical fixture must not be weakened to obtain a green result.

Even a successful probe does not qualify production. It only authorizes a separately reviewed implementation of the bounded acceptance criterion, followed by real receipt/replay/commit qualification and current-canonical reconciliation.
