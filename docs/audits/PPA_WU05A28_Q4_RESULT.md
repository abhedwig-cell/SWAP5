# PPA-WU05-A28-Q4 result — long-history approximate RFM

Date: 2026-10-02
Status: PARTIAL_QUALIFICATION_H3_FIXTURE_FALSIFIED

## Executed evidence

Qualification run: 37026218284
Qualification postimage: a5a0d34971199400768e5d73013ac622c013e401
Artifact: 11235688563
Artifact digest: sha256:9a44b07773f853719214b7d878fb9d6427ab313a27b6d79a5e3bea2218dab5b4

The Q4 executable compiled and completed. The analyzer gate completed successfully after distinguishing shared exact/approx fixture failure from approximate-only regression.

## Long-history result

Ten of twelve exact/approximate C pairs complete the full 24-day, 20-cycle history. Across those ten:
- max final total-storage difference = 1.5987211555e-13 cm;
- max bottom-outflow difference = 8.3219831026e-10 cm;
- max sampled theta difference = 4.6906922790e-15;
- max approximate mass residual = 2.1038863152e-9 cm.

Across 200 jointly available exact/approx cycle-boundary pairs:
- max total-storage difference = 5.6259352732e-10 cm;
- max sampled theta difference = 6.3619942647e-12;
- max endpoint-water difference = 0 cm.

The mid-history trusted committed-state reconstruction/replay and candidate-discard immutability gates are embedded in every completing C trajectory; a mismatch terminates the fixture. All ten completing pairs pass those gates.

## Retained failure

H3 fails at step 1 for B01 in both geometry variants, in both exact and approximate arms, with the same status 2. This is not an A28_V1 regression. It means the preregistered H3 fixture does not provide an executable threshold-cycling test for B01.

An initial H3 forcing adjustment was made after the first execution. The adjusted H3 still fails. No further tuning is allowed under this Q4 preregistration.

Therefore Q4 is not labeled fully qualified. H1/H2 long-history behavior plus reconstruction/replay are qualified for the executed fixture; the intended policy-threshold cycling question remains open.

## Decision

Do not use the H3 failure to reject A28_V1, and do not erase it by further tuning. Open a separately preregistered threshold-crossing experiment whose initial state/forcing is demonstrated to be executable under exact RFM before approximate comparison. MultiSWAP-MODFLOW production eligibility remains open until that missing regime is resolved.
