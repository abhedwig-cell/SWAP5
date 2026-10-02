# PPA-WU05-A27-PERF02 result — exact-preserving RFM preparation zero-waste

Date: 2026-10-02
Status: QUALIFIED_BRANCH_ONLY
Canonical admission: NO

Final current-canonical owner run: `36999473010`
Postimage: `0861767270fda7d2c59b8d4284794853742b0edf`
Evidence artifact: `11223770178`
Digest: `sha256:f8ca0b6ea924f7f911531d80113dd6b2302d31ef5ae76d0de212a76820ff6e21`

## Change

Production RFM live preparation now avoids two computations whose values do not enter the accepted A26 production candidate:

1. MB wall conductivity/sorptivity for the leading MB fast-through route.
2. Surface conductivity/sorptivity when net surface supply is exactly zero.

Positive-supply activation, endpoint wall hydraulics, endpoint release, 64-panel sorptivity definition, source ownership and transaction policy are unchanged.

## Component evidence

PROFILE01:
- FULL_WET_CACHED: 130 -> 65 constitutive-demand calls;
- FULL_DRY_CACHED: 130 -> 0 demand calls.

Wet cached preparation median is about 0.179 s per 2000 calls on the final runner. The remaining cost is almost entirely one 64-panel surface-sorptivity integral.

## Hydrologic preservation

Final owner run:
- A26 live trial preservation PASS;
- A27 current-canonical backend compile/preservation PASS;
- A8 standard macropore preservation PASS;
- full ABC screen PASS;
- RFM C non-timing identity versus qualified pre-MIGMAC baseline: 32/32 rows exact;
- current-canonical B/C envelope: B 29/32, C 30/32, joint 29, E1 29.

Thus PERF02 changes timing only for the RFM production route in this screen.

## Timing

Final five-repeat medians:

| Case | B ms | C ms | B/C |
| --- | ---: | ---: | ---: |
| R2/G1/B01 | 3.361 | 3.189 | 1.054 |
| R4/G2/B01 | 3.429 | 10.188 | 0.337 |
| R5/G1/O05 | 3.387 | 4.182 | 0.810 |
| R6/G2/O05 | 3.174 | 6.255 | 0.508 |

Compared with the pre-PERF02 qualified C timings, the RFM route itself improved by roughly 1.6x to 4.2x depending on forcing history. CI timings are machine-specific.

PERF02 therefore succeeds as an exact-preserving performance repair, but does not establish that RFM is generally faster than standard macropore.

## Next

The remaining wet cached preparation performs exactly one 64-panel surface-sorptivity integral, 65 constitutive-demand evaluations. Before lowering panel count, determine whether that identical accepted-state quantity is recomputed across full/half/retry trials and can be reused exactly.
