# TOP03 BASE temporal acceptance decision

Date: 2026-10-02  
Status: FALSIFIED_BOUNDED_FULL_HALF_ACCEPTANCE_ROUTE__NO_PRODUCTION_ADMISSION  
Evidence run: GitHub Actions 36975133856  
Source postimage: `2d1b5be49d08b02c866e77e6ed865b2122e6b40e`  
Canonical inspected: `641a8ba7fad5b67f0ebff7c78dd065270ed46329`

## Question

Can the real, unchanged FAPP09 BASE inundation fixture justify replacing the exact-state temporal identity gate with a bounded full/half acceptance criterion?

The preregistered probe preserved the existing initial state, mode-7 lower boundary, imposed external surface-water head, Reference Richards solve and post-solve top materializer. No production source was changed.

## Evidence quality

The dedicated runner compiled a 23-file dependency closure and executed the probe at O0 and O2. Numerical output was exactly identical between optimization levels.

Every complete path passed the hard soil-mass, surface-closure and whole-control-volume ledger gates. The observed ledger residuals remained at roundoff scale. Therefore the result below is not explained by a mass-accounting failure.

## Result

The 0.25-day and 0.125-day windows each provide only one complete adjacent refinement pair. The four-step refinements fail nonlinearly, so neither window can supply the two successive complete pairs required by the preregistered decision rule.

At 0.0625 day, 1, 2 and 4 substeps complete. From the 1-vs-2 comparison to the 2-vs-4 comparison:

- pressure-head infinity difference decreases from 45.1554 to 36.3769 cm;
- water-storage L1 difference decreases from 0.110516 to 0.0533705 cm;
- top-transfer difference decreases from 0.119550 to 0.103527 cm;
- bottom-transfer difference increases from 0.00905196 to 0.0501561 cm.

Thus the relevant boundary throughput does not contract even where the state and top-transfer measures improve. Ignoring the bottom term would violate the preregistered acceptance contract.

At 0.03125 day, 1, 2 and 4 substeps also complete, but refinement is worse rather than better:

- pressure-head infinity difference increases from 46.4039 to 53.9159 cm;
- water-storage L1 difference increases from 0.0915097 to 0.0972692 cm;
- top-transfer difference increases from 0.0923053 to 0.106810 cm;
- bottom-transfer difference increases from 0.00100290 to 0.00956409 cm.

The eight-substep path fails nonlinearly.

## Decision

The proposed bounded BASE full/half acceptance route is falsified for the actual TOP03 fixture.

There is no evidence-backed tolerance that can responsibly replace the exact-state gate in this profile. Solver convergence plus closed mass balance remains insufficient: complete paths can still disagree materially in state and integrated boundary transfers.

Do not:

- replace `huge()` with an arbitrary finite norm;
- ignore the bottom-transfer discrepancy;
- weaken the lower boundary or initial state;
- treat the existing Reference temporal certificate as applicable to dynamic top;
- extend the current production retry ladder and call the result qualified without a new preregistered numerical contract.

The transaction/materializer/receipt architecture remains valid within its previously qualified scope. The blocker is now narrower and stronger: **the unchanged BASE inundation problem does not supply a contracting independent refinement sequence from which the requested state + top + bottom acceptance budgets can be qualified.**

PR #956 remains draft and TOP03 remains unadmitted.

Machine-readable evidence is in `integration/sw-rib-top03/TOP03_BASE_TEMPORAL_ACCEPTANCE_RESULT.json`.
