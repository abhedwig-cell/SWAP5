# GC-RZM06D02R1 and D03 results

## D02R1: representation-safe common-time reseed

Workflow `35739047845`, job `106783673618`, passed.

The original D02 audit was confounded because `(7 + 0.0008) - 7` did not have the same binary64 value as `0.0008`. D02R1 replaced only that representational detail with an exactly reproducible dyadic duration of approximately `0.000800000037997961 d`.

With the same D01/1 physical profile at committed times 0 and 7 d:

- accepted duration bits are identical;
- all 16 pressure heads are bit-identical;
- all 16 water contents are bit-identical;
- ponding and diagnostic groundwater level are bit-identical;
- whole-window bottom exchange is bit-identical;
- terminal bottom flux is bit-identical;
- mass residual is zero;
- O0/O2 output is byte-identical.

Decision: `QUALIFIED_COMMON_TIME_RESEED_FOR_C01_PURE_HYDRAULICS`.

This is limited to the C01 BASE pure-hydraulics carrier. It is not a claim for process-active SWAP configurations.

## D03: cross-library-time response-blind search

Workflow `35739393743`, job `106784863436`, passed.

Using the exact ROM1AR2 artifact, only DISCOVERY records whose producing interval has `FALLBACK=F` were eligible. HELD_OUT node observables and response/exchange fields were not parsed.

The same physical H2 gates were retained:

- `|ΔW_profile| <= 1e-4 cm`;
- `|ΔM1| >= 1e-2 cm`.

Across 475 eligible records:

- 98,693 different-history pairs were enumerated;
- 808 met the profile-water gate;
- 0 met both gates.

The closest water-matched pair is D02 step 64 versus D08 step 44. It has `|ΔW| = 6.0945513e-5 cm` and `|ΔM1| = 0.0078369124 cm`, about 78.4% of the required vertical-distribution separation.

Decision: `QUALIFIED_CROSS_TIME_DISCOVERY_NO_MATCH__H2_NOT_PROBED`.

The appropriate next step is not to relax H2. It is to use this pair as immutable, response-blind seed origins for a bounded strict accepted-continuation map and test whether nearby reachable states cross the existing state gate before any coupling-response probe is opened.
