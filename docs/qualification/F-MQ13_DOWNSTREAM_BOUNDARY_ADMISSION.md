# F-MQ13 — F-SI01 and F-VQ08 downstream boundary admission

F-MQ13 is qualification-only. It starts from the qualified F-MQ12 head `e7248ef1813acf942fcae0f8d66c1b4409af4914` and changes no production source, solver physics, numerical policy or production MultiSWAP runtime.

## Exact downstream evidence

F-SI01 is pinned at `ae6da038ee7e98dfe1758f5f86b4be0fb48b4743`. Its qualification status is `QUALIFIED_BOUNDARY_BASELINE_ONLY`. F-MQ admits the persisted solver ownership/interface boundary, the O0/O2/OpenMP 8-worker context-isolation gate and the rule that solver workspace belongs to a worker or active solve job rather than to persistent logical-column state.

F-SI01 does **not** qualify reference Richards reentrancy or production MultiSWAP parallelism. Its solver identity/order/worker-count/scratch-poison/clone/leakage/O0-O2/mass/route tests T03–T11 remain explicitly blocked until the common solver interface has a production implementation.

F-VQ08 is pinned at `0be60f6da7e575eaf992eb049ce600a4a4b35b58`. Its decision is `QUALIFIED_TEMPORAL_CHARACTERIZATION_READINESS_ONLY`. F-MQ admits the readiness/fail-closed boundary only. Real B1.10 temporal characterization, a production temporal profile, production `execute_reference_interval`, and complete optional-process temporal scope remain unqualified.

Hard mass conservation remains an absolute independent gate and may not be normalized into temporal acceptance.

## F-KT observation

The current F-KT head is `cbcbfa26d413a661956a2079dc4a1e26c9e3b55c`. Its tree is `265029cdf0c17be2c23ce2ff4fa8775cd0cd4e61`, identical to the qualified F-KT01 final tree. The intervening F-KT02 marker was therefore a temporary no-net-content change and produces no F-MQ capability promotion.

## F-MQ ownership effect

F-SI ownership becomes sharper for P03, P06, P18, P19, D01 and D02: the interface/workspace boundary is now admitted, but executable reference-solver isolation remains downstream work.

F-VQ ownership becomes sharper for P10, P11, P14, P16 and S01: readiness and missing-evidence boundaries are now independently qualified, but no real event-local fixture or reference execution is admitted.

There is still no F-MR branch, so no production scheduler, batching, result-addressing, tile aggregation, coupling or performance-runtime claim can advance.

## Coverage decision

F-MQ13 deliberately leaves the coverage totals unchanged:

- synthetic executable: 27/35;
- real physics executable: 0/35;
- production runtime qualified: 0/35.

This is a qualification improvement through exact ownership and fail-closed evidence, not through test-class promotion.

## Gate

The F-MQ13 CI gate checks the local overlay and then fetches the exact F-SI01 and F-VQ08 commits. It verifies that the positive boundary claims remain true and that every still-missing solver/reference capability remains blocked. Later branch drift cannot silently upgrade this work unit.
