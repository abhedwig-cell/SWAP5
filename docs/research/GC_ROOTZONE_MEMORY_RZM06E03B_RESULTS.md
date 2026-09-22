# GC-RZM06E03B result

**Status:** qualified research evidence, NO_MATCH  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration:** `511b6f9fcf40702786ecb84bc5b253998db214aa`  
**Workflow:** run 35744543880, job 106802617511

E03B qualified technically with byte-identical O0/O2 output, but the frozen split-boundary construction produced no pair satisfying the full state gate.

Only two split families completed: TB_N08 and TB_N09. Both preserve total profile water to roundoff and produce large vertical-distribution shifts relative to BASE_EQ, with `ΔM1=-0.14154 cm` and `-0.14920 cm` respectively. Their upper-30-cm storage, however, remains lower than BASE_EQ by about `0.05638 cm` and `0.05948 cm`.

The numerical pattern is also informative. Every BOTTOM_THEN_TOP family failed during its initial bottom-only phase at phase step 7. TB_N10 completed all ten top-only intervals but failed at bottom phase step 3. TB_N11 and TB_N12 failed at top phase step 11 before reaching the bottom phase. All failures were fail-closed and transaction-safe.

The closest pair after the total-water gate is TB_N08 versus TB_N09. It still differs by `0.003106 cm` in upper-30-cm water, more than thirty times the frozen `1e-4 cm` tolerance, while its M1 separation is `0.007664 cm`, below the unchanged `0.01 cm` requirement.

This closes E03B as `QUALIFIED_SPLIT_BOUNDARY_STATE_CONSTRUCTION_NO_MATCH`. The evidence does not support relaxing any state threshold. It does support a narrower next experiment: retain the same integrated top and bottom transfer, but spread the lower-boundary extraction over a smaller flux and more strict intervals. That directly tests whether the E03B bottleneck is extraction rate rather than the total lower-boundary transfer.
