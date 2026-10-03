# Recession route-gate counterfactual preregistration

Date: 2026-10-03
Status: PREREGISTERED_DIAGNOSTIC_ONLY

## Question

Does ending the imposed external-head route whenever `external_head < previous_ponding` cause the observed direct-source recession failure, or does the failure persist when the imposed head remains active down to the existing flooding sill?

## Counterfactual

In a temporary local source copy, change only the `external_active` predicate in `src/solver/mod_b110_dynamic_top_boundary_provider.f90`: retain the supplied external head whenever `external_head > flooding_sill`, without requiring `external_head >= previous_ponding`. Do not persist the source change. This is not proposed production physics: it deliberately isolates the route gate and does not implement a bidirectional finite-conductance surface control volume.

## Fixed case

Use the existing production-provider/HeadCalc driver at width 2 cm, `SWBOTB=7`, `SWKIMPL=0`, the same initial profile, no rainfall/evaporation/runoff, external stage rising to 0.02 cm, held to day 0.125, then linearly receding to zero, 0.25-day horizon, and refinements 1 through 4096. Run O0 and O2 with unchanged tolerances and mass checks.

## Outcomes

Record completion/refinement, first failure, stage and ponding at route exit, Newton iterations/residual/update, regime changes, accepted-prefix soil/combined balance, and O0/O2 identity. A pass would show this predicate is causal in this fixture but would not qualify a physical exchange law or transaction/Ribasim coupling. A failure would show that removing this gate alone is insufficient. No tolerance, forcing, or parameter changes are allowed.
