# GC-RZM06E03 result

**Status:** qualified research evidence, NO_MATCH  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration:** `e6543e57bed84ec22615ea68f14f66ec400362cd`  
**Executed head:** `63000df12a460ad0eecbbe21d42241fa1c1e3d62`  
**Workflow:** run 35743604739, job 106799372329

## Result

The E03 qualification gate passed technically and the complete O0/O2 observable output was byte-identical. The experiment itself closed **NO_MATCH** under the frozen state criteria.

The response-blind generator produced 29 accepted states: one BASE_EQ state, 27 DRY_RECOVER states, and one WET_RECOVER state. DRY_RECOVER remained strict through recovery step 17 and then failed closed at global step 28 by solver rejection. WET_RECOVER failed closed at its second perturbation interval. Both failures preserved the latest committed origin.

Seventeen recovery comparisons were eligible. Exactly one pair met both storage controls:

- `|ΔW_profile| = 0 cm`;
- `|ΔW_root30| = 5.0470449348694046e-05 cm`;
- `|ΔM1| = 0.001103765210785923 cm`.

That pair is BASE_EQ step 1 versus DRY_RECOVER step 20. Its M1 separation is only about 11.0% of the unchanged `0.01 cm` requirement, so it is not an admissible E04 origin pair.

The largest M1 separation in the eligible set was `0.07154475561600293 cm`, but that state still differed from BASE_EQ by `0.028245704446707265 cm` in upper-30-cm water and therefore failed the root-storage control.

## Interpretation

E03 does not establish state sufficiency. It establishes a narrower negative result: the frozen zero-divergence reversal route does not isolate a large deeper-profile difference after the upper 30 cm has returned to the required storage tolerance.

Within this construction, recovery of upper-profile storage is accompanied by near-erasure of the large M1 separation. This makes a direct E04 response probe inappropriate because no pair passed the full preregistered state gate.

The result also does not falsify deeper-profile memory. A different prospectively defined state-space construction may still produce equal total water and equal upper-30-cm water with materially different deeper distribution.

## Decision

Close GC-RZM06E03 as:

`QUALIFIED_ROOTMATCHED_DEEP_MEMORY_NO_MATCH__NO_RESPONSE_PROBE`.

Do not relax the water, root30 or M1 thresholds. The next experiment, if pursued, must be separately preregistered and should target faster upper-profile recovery relative to deeper-profile recovery rather than reinterpret E03.
